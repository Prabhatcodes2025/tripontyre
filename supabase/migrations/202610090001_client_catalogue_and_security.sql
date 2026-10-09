-- Additive client catalogue and security corrections. Safe to rerun; no records are deleted.

alter table public.destinations add column if not exists primary_category public.package_category;
alter table public.tour_packages add column if not exists is_upcoming boolean not null default false;

-- Correct policies omitted by the earlier production upgrade.
drop policy if exists admin_manage on public.awards;
create policy admin_manage on public.awards for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists admin_manage on public.travel_articles;
create policy admin_manage on public.travel_articles for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists admin_booking_travellers on public.booking_travellers;
create policy admin_booking_travellers on public.booking_travellers for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- Customers may see only issued private artefacts; admins retain full access.
-- Payment state belongs to bookings.payment_status/payments.status, never to document_status.
drop policy if exists customer_owned on public.documents;
create policy customer_owned on public.documents for select to authenticated
using(public.is_admin() or (customer_id=auth.uid() and status='issued'::public.document_status));
drop policy if exists customer_owned on public.invoices;
create policy customer_owned on public.invoices for select to authenticated
using(public.is_admin() or (customer_id=auth.uid() and status='issued'::public.document_status));
drop policy if exists customer_owned on public.vouchers;
create policy customer_owned on public.vouchers for select to authenticated
using(public.is_admin() or (customer_id=auth.uid() and status='issued'::public.document_status));

-- Keep enum history, but expose the three requested primary categories.
with catalogue(slug,name,category,is_upcoming) as (values
 ('delhi-agra-jaipur-amritsar-wagah-border','Delhi - Agra - Jaipur - Amritsar - Wagah Border','domestic'::public.package_category,true),
 ('kashmir','Kashmir','domestic'::public.package_category,false),
 ('kashmir-kargil','Kashmir - Kargil','domestic'::public.package_category,false),
 ('ladakh','Ladakh','domestic'::public.package_category,false),
 ('rajasthan','Rajasthan','domestic'::public.package_category,true),
 ('sikkim-darjeeling','Sikkim - Darjeeling','domestic'::public.package_category,false),
 ('meghalaya','Meghalaya','domestic'::public.package_category,false),
 ('kolkata','Kolkata','domestic'::public.package_category,false),
 ('gujarat','Gujarat','domestic'::public.package_category,false),
 ('hyderabad','Hyderabad','domestic'::public.package_category,false),
 ('mumbai','Mumbai','domestic'::public.package_category,false),
 ('ajanta-ellora','Ajanta - Ellora','domestic'::public.package_category,false),
 ('odisha','Odisha','domestic'::public.package_category,false),
 ('lakshadweep','Lakshadweep','domestic'::public.package_category,false),
 ('andaman','Andaman','domestic'::public.package_category,false),
 ('goa','Goa','domestic'::public.package_category,false),
 ('kullu-manali-kasol','Kullu - Manali - Kasol','domestic'::public.package_category,false),
 ('kerala-full','Kerala - Full','domestic'::public.package_category,false),
 ('munnar-thekkady-vagamon-kochi-athirappalli','Munnar - Thekkady - Vagamon - Kochi - Athirappalli','domestic'::public.package_category,false),
 ('munnar-thekkady-kochi-alappuzha-kumarakom-varkala-kovalam','Munnar - Thekkady - Kochi - Alappuzha - Kumarakom - Varkala - Kovalam','domestic'::public.package_category,false),
 ('bijapur-hampi-badami-aihole-pattadakkal-chitradurga','Bijapur - Hampi - Badami - Aihole - Pattadakkal - Chitradurga','domestic'::public.package_category,false),
 ('ayodhya-kashi-prayagraj-gaya-bodh-gaya','Ayodhya - Kashi - Prayagraj - Gaya - Bodh Gaya','domestic'::public.package_category,false),
 ('rameswaram-dhanushkodi-madurai-kodaikanal','Rameswaram - Dhanushkodi - Madurai - Kodaikanal','domestic'::public.package_category,false),
 ('valparai-athirappalli','Valparai - Athirappalli','domestic'::public.package_category,false),
 ('bangalore-mysore-kodagu','Bangalore - Mysore - Kodagu','domestic'::public.package_category,false),
 ('ooty-mysore','Ooty - Mysore','domestic'::public.package_category,false),
 ('dubai','Dubai','international'::public.package_category,false),
 ('thailand','Thailand','international'::public.package_category,true),
 ('indonesia','Indonesia','international'::public.package_category,false),
 ('bali-nusa-penida','Bali - Nusa Penida','international'::public.package_category,false),
 ('malaysia-singapore','Malaysia - Singapore','international'::public.package_category,false),
 ('sri-lanka','Sri Lanka','international'::public.package_category,false),
 ('maldives','Maldives','international'::public.package_category,false),
 ('nepal','Nepal','international'::public.package_category,false),
 ('bhutan','Bhutan','international'::public.package_category,false),
 ('azerbaijan','Azerbaijan','international'::public.package_category,false),
 ('matheran','Matheran','strangers_meetup'::public.package_category,false),
 ('vagamon','Vagamon','strangers_meetup'::public.package_category,false),
 ('hampi','Hampi','strangers_meetup'::public.package_category,false),
 ('gokarna','Gokarna','strangers_meetup'::public.package_category,false),
 ('agumbe','Agumbe','strangers_meetup'::public.package_category,false),
 ('jog-falls','Jog Falls','strangers_meetup'::public.package_category,false),
 ('wayanad','Wayanad','strangers_meetup'::public.package_category,false),
 ('kasol','Kasol','strangers_meetup'::public.package_category,false),
 ('chikmagalur','Chikmagalur','strangers_meetup'::public.package_category,false)
), inserted as (
 insert into public.destinations(slug,name,region,summary,hero_image,primary_category,published)
 select slug,name,
   case category when 'domestic' then 'India' when 'international' then 'International' else 'Strangers Meetup' end,
   'Details coming soon. Contact My Tripon Travel to register your interest.',
   case when slug='dubai' then '/travel/desert-convoy.webp'
        when slug in ('bali-nusa-penida','indonesia') then '/travel/nusa-penida.webp'
        when slug in ('goa','gokarna','lakshadweep','andaman','maldives') then '/travel/beach-reflections.webp'
        when slug in ('kashmir','kashmir-kargil','ladakh','kullu-manali-kasol','kasol') then '/travel/mountain-river-bridge.webp'
        else '/travel/tulip-garden.webp' end,
   category,true from catalogue
 on conflict(slug) do update set primary_category=excluded.primary_category
 returning id,slug,hero_image
)
insert into public.tour_packages(slug,title,destination_id,category,summary,hero_image,is_upcoming,published)
select c.slug,c.name,d.id,c.category,
 'Details coming soon. Contact My Tripon Travel to register your interest.',d.hero_image,c.is_upcoming,true
from catalogue c join inserted d on d.slug=c.slug
on conflict(slug) do update set category=excluded.category,is_upcoming=excluded.is_upcoming;

-- Europe remains in history but is no longer a current public offer.
update public.destinations set published=false where slug='europe';
update public.tour_packages p set published=false
from public.destinations d where p.destination_id=d.id and d.slug='europe';

-- Explicit least-privilege grants for objects introduced by the upgrade.
grant select on public.destinations,public.tour_packages,public.tour_itinerary_days,public.gallery_items,
 public.testimonials,public.awards,public.travel_services,public.blogs,public.events,public.faqs,
 public.hero_slides,public.site_sections,public.navigation_items,public.seo_entries to anon,authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
revoke all on public.profiles,public.bookings,public.booking_travellers,public.payments,public.leads,
 public.quotations,public.quotation_items,public.invoices,public.vouchers,public.documents,public.audit_logs from anon;

-- Return an existing idempotent booking before rechecking sold-out availability.
create or replace function public.create_booking_secure(
  p_package_slug text,p_travel_date date,p_travellers jsonb,p_payment_mode text,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_user uuid:=auth.uid();v_package public.tour_packages%rowtype;v_availability public.package_availability%rowtype;
 v_booking public.bookings%rowtype;v_adults integer;v_children integer;v_infants integer;v_people integer;
 v_subtotal integer;v_tax integer;v_total integer;v_advance integer;v_adult_price integer;
begin
 if v_user is null then raise exception 'authentication_required' using errcode='28000';end if;
 if p_idempotency_key is null then raise exception 'idempotency_key_required';end if;
 select * into v_booking from public.bookings where customer_id=v_user and idempotency_key=p_idempotency_key;
 if found then return to_jsonb(v_booking);end if;
 if p_travel_date<=current_date then raise exception 'invalid_travel_date';end if;
 if p_payment_mode not in ('advance','full') then raise exception 'invalid_payment_mode';end if;
 if jsonb_typeof(p_travellers)<>'array' or jsonb_array_length(p_travellers)<1 or jsonb_array_length(p_travellers)>12 then raise exception 'invalid_traveller_count';end if;
 if exists(select 1 from jsonb_array_elements(p_travellers) t where t->>'type' not in ('adult','child','infant') or length(trim(t->>'firstName')) not between 1 and 100 or length(trim(t->>'lastName')) not between 1 and 100) then raise exception 'invalid_traveller';end if;
 select * into v_package from public.tour_packages where slug=p_package_slug and published=true for share;
 if not found or v_package.base_price is null then raise exception 'package_unavailable';end if;
 select * into v_availability from public.package_availability where package_id=v_package.id and travel_date=p_travel_date for update;
 if not found or v_availability.status<>'open' then raise exception 'date_unavailable';end if;
 select count(*) filter(where value->>'type'='adult'),count(*) filter(where value->>'type'='child'),count(*) filter(where value->>'type'='infant') into v_adults,v_children,v_infants from jsonb_array_elements(p_travellers);
 if v_adults<1 then raise exception 'adult_required';end if;
 v_people:=v_adults+v_children+v_infants;
 if v_availability.reserved+v_people>v_availability.capacity then raise exception 'insufficient_capacity';end if;
 v_adult_price:=coalesce(v_availability.price_override,v_package.base_price);
 v_subtotal:=v_adults*v_adult_price+v_children*coalesce(v_package.child_price,v_adult_price)+v_infants*coalesce(v_package.infant_price,0);
 v_tax:=round(v_subtotal*v_package.tax_rate/100.0);v_total:=v_subtotal+v_tax;
 v_advance:=case when p_payment_mode='full' then v_total when v_package.advance_type='fixed' then least(v_package.advance_value,v_total) else least(round(v_total*v_package.advance_value/100.0),v_total) end;
 insert into public.bookings(reference,customer_id,package_id,travel_date,adult_count,child_count,infant_count,currency,subtotal_amount,tax_amount,total_amount,advance_amount,balance_amount,price_snapshot,idempotency_key)
 values('MYT-'||to_char(clock_timestamp(),'YYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),v_user,v_package.id,p_travel_date,v_adults,v_children,v_infants,v_package.currency,v_subtotal,v_tax,v_total,v_advance,v_total,jsonb_build_object('package_id',v_package.id,'title',v_package.title,'adult_price',v_adult_price,'child_price',coalesce(v_package.child_price,v_adult_price),'infant_price',coalesce(v_package.infant_price,0),'tax_rate',v_package.tax_rate,'calculated_at',now()),p_idempotency_key)
 on conflict(customer_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning * into v_booking;
 if not exists(select 1 from public.booking_travellers where booking_id=v_booking.id) then
  insert into public.booking_travellers(booking_id,traveller_type,first_name,last_name,date_of_birth)
  select v_booking.id,t->>'type',trim(t->>'firstName'),trim(t->>'lastName'),nullif(t->>'dateOfBirth','')::date from jsonb_array_elements(p_travellers) t;
  update public.package_availability set reserved=reserved+v_people,status=case when reserved+v_people>=capacity then 'sold_out' else status end where id=v_availability.id;
 end if;
 return to_jsonb(v_booking);
end $$;
revoke all on function public.create_booking_secure(text,date,jsonb,text,uuid) from public;
grant execute on function public.create_booking_secure(text,date,jsonb,text,uuid) to authenticated;

-- Apply provider events under row locks so retries cannot double-credit a booking
-- and a later failure cannot downgrade a successful payment.
create or replace function public.apply_payment_webhook_event(
 p_event_id uuid,p_order_id text,p_payment_id text,p_amount integer,p_currency text,
 p_state text,p_failure_code text,p_payload jsonb
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_payment public.payments%rowtype;v_booking public.bookings%rowtype;v_paid integer;
begin
 select * into v_payment from public.payments where provider='razorpay' and provider_order_id=p_order_id for update;
 if not found or v_payment.amount<>p_amount or v_payment.currency<>p_currency then raise exception 'payment_verification_failed';end if;
 if v_payment.status='success' then update public.payment_webhook_events set processed_at=now() where id=p_event_id;return;end if;
 if p_state='success' then
  update public.payments set status='success',provider_payment_id=p_payment_id,verified_at=now(),failure_code=null,provider_payload=p_payload where id=v_payment.id;
  select * into v_booking from public.bookings where id=v_payment.booking_id for update;
  v_paid:=least(coalesce(v_booking.paid_amount,0)+v_payment.amount,v_booking.total_amount);
  update public.bookings set paid_amount=v_paid,balance_amount=greatest(0,total_amount-v_paid),payment_status='success',booking_status='confirmed' where id=v_booking.id;
 elsif p_state='failed' then
  update public.payments set status='failed',provider_payment_id=p_payment_id,failure_code=p_failure_code,provider_payload=p_payload where id=v_payment.id and status='pending';
 end if;
 update public.payment_webhook_events set processed_at=now() where id=p_event_id;
end $$;
revoke all on function public.apply_payment_webhook_event(uuid,text,text,integer,text,text,text,jsonb) from public;
grant execute on function public.apply_payment_webhook_event(uuid,text,text,integer,text,text,text,jsonb) to service_role;
