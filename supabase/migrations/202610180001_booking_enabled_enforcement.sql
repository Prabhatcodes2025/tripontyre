-- Enforce the CMS booking safety switch in the server-authoritative path.
-- Prerequisite: 202610150001_client_changes_1_6.sql adds booking_enabled.

begin;

-- Reassert the hold for the five client packages even when this migration is
-- applied to an environment where an operator changed a flag prematurely.
update public.tour_packages
set booking_enabled=false,
    published=false,
    published_at=null,
    updated_at=now()
where slug in (
  'kashmir-kargil',
  'delhi-agra-jaipur-golden-triangle-tour',
  'delhi-agra-mathura-jaipur-tour',
  'delhi-agra-tour',
  'delhi-agra-jaipur-amritsar-wagah-border'
);

create or replace function public.create_booking_secure(
  p_package_slug text, p_travel_date date, p_travellers jsonb,
  p_payment_mode text, p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_user uuid:=auth.uid(); v_package public.tour_packages%rowtype;
  v_availability public.package_availability%rowtype; v_booking public.bookings%rowtype;
  v_adults integer; v_children integer; v_infants integer; v_people integer;
  v_subtotal integer; v_tax integer; v_total integer; v_advance integer; v_adult_price integer;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='28000'; end if;
  if p_idempotency_key is null then raise exception 'idempotency_key_required'; end if;

  -- A retried request returns its original booking without reserving capacity
  -- twice, including when the package was subsequently placed on hold.
  select * into v_booking from public.bookings
  where customer_id=v_user and idempotency_key=p_idempotency_key;
  if found then return to_jsonb(v_booking); end if;

  if p_travel_date<=current_date then raise exception 'invalid_travel_date'; end if;
  if p_payment_mode not in ('advance','full') then raise exception 'invalid_payment_mode'; end if;
  if jsonb_typeof(p_travellers)<>'array' or jsonb_array_length(p_travellers)<1 or jsonb_array_length(p_travellers)>12 then
    raise exception 'invalid_traveller_count';
  end if;
  if exists(select 1 from jsonb_array_elements(p_travellers) t
    where t->>'type' not in ('adult','child','infant')
      or length(trim(t->>'firstName')) not between 1 and 100
      or length(trim(t->>'lastName')) not between 1 and 100) then
    raise exception 'invalid_traveller';
  end if;

  select * into v_package from public.tour_packages
  where slug=p_package_slug and published=true and booking_enabled=true for share;
  if not found or v_package.base_price is null then raise exception 'package_unavailable'; end if;

  select * into v_availability from public.package_availability
  where package_id=v_package.id and travel_date=p_travel_date for update;
  if not found or v_availability.status<>'open' then raise exception 'date_unavailable'; end if;

  select count(*) filter(where value->>'type'='adult'),
         count(*) filter(where value->>'type'='child'),
         count(*) filter(where value->>'type'='infant')
  into v_adults,v_children,v_infants from jsonb_array_elements(p_travellers);
  if v_adults<1 then raise exception 'adult_required'; end if;
  v_people:=v_adults+v_children+v_infants;
  if v_availability.reserved+v_people>v_availability.capacity then raise exception 'insufficient_capacity'; end if;

  v_adult_price:=coalesce(v_availability.price_override,v_package.base_price);
  v_subtotal:=v_adults*v_adult_price
    +v_children*coalesce(v_package.child_price,v_adult_price)
    +v_infants*coalesce(v_package.infant_price,0);
  v_tax:=round(v_subtotal*v_package.tax_rate/100.0);
  v_total:=v_subtotal+v_tax;
  v_advance:=case
    when p_payment_mode='full' then v_total
    when v_package.advance_type='fixed' then least(v_package.advance_value,v_total)
    else least(round(v_total*v_package.advance_value/100.0),v_total) end;

  insert into public.bookings(
    reference,customer_id,package_id,travel_date,adult_count,child_count,infant_count,currency,
    subtotal_amount,tax_amount,total_amount,advance_amount,balance_amount,price_snapshot,idempotency_key
  ) values(
    'MYT-'||to_char(clock_timestamp(),'YYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
    v_user,v_package.id,p_travel_date,v_adults,v_children,v_infants,v_package.currency,
    v_subtotal,v_tax,v_total,v_advance,v_total,
    jsonb_build_object('package_id',v_package.id,'title',v_package.title,'adult_price',v_adult_price,
      'child_price',coalesce(v_package.child_price,v_adult_price),'infant_price',coalesce(v_package.infant_price,0),
      'tax_rate',v_package.tax_rate,'calculated_at',now()),p_idempotency_key
  ) on conflict(customer_id,idempotency_key) do update
    set idempotency_key=excluded.idempotency_key returning * into v_booking;

  if not exists(select 1 from public.booking_travellers where booking_id=v_booking.id) then
    insert into public.booking_travellers(booking_id,traveller_type,first_name,last_name,date_of_birth)
    select v_booking.id,t->>'type',trim(t->>'firstName'),trim(t->>'lastName'),nullif(t->>'dateOfBirth','')::date
    from jsonb_array_elements(p_travellers) t;
    update public.package_availability
    set reserved=reserved+v_people,
        status=case when reserved+v_people>=capacity then 'sold_out' else status end
    where id=v_availability.id;
  end if;
  return to_jsonb(v_booking);
end $$;

revoke all on function public.create_booking_secure(text,date,jsonb,text,uuid) from public;
grant execute on function public.create_booking_secure(text,date,jsonb,text,uuid) to authenticated;

commit;
