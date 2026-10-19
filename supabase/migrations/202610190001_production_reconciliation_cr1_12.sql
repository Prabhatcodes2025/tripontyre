-- ONE-TIME production reconciliation for CR1-CR12.
-- Built from the verified 2026-10-19 production diagnostic and repository
-- migrations 202610150001 through 202610180003.
-- Diagnostic source SHA-256:
-- 8B011F2FAC97CBE48A2078516694F446CD6321F8274D3D7E38C25A19AB1DAEE0
--
-- Forward-only and transactional. It preserves existing primary keys, foreign
-- keys, bookings, payments, media rows, policies, grants and storage objects.
-- Any drift from the audited pre-state or any later Admin edit to managed rows
-- causes the whole transaction to abort.
-- Execute this complete file as one Supabase SQL Editor run. Client source rows
-- are statement-local VALUES records; no temporary/session table is required.

begin;

select pg_advisory_xact_lock(hashtextextended('my-tripon-cr1-12-production-reconciliation-v1',0));

do $preflight$
declare
  v_marker timestamptz;
  v_conflicts text;
  v_missing text;
  v_package_count bigint;
  v_booking_function_hash text;
  v_policy_drift text;
  v_diagnostic_at constant timestamptz:='2026-10-18T18:33:14.985711+00:00';
begin
  -- The diagnostic showed 49 packages before reconciliation. A clean rerun has
  -- 55 after the six missing stable slugs are inserted.
  select count(*) into v_package_count from public.tour_packages;

  select nullif(value->>'applied_at','')::timestamptz
  into v_marker
  from public.site_settings
  where key='_migration_reconciliation_cr1_12_20261019';

  if v_marker is null and v_package_count<>49 then
    raise exception 'Production drift: expected 49 packages before first reconciliation, found %',v_package_count;
  end if;
  if v_marker is not null and v_package_count<>55 then
    raise exception 'Production drift: expected 55 packages on reconciliation rerun, found %',v_package_count;
  end if;

  if to_regclass('public.tour_packages') is null
     or to_regclass('public.tour_itinerary_days') is null
     or to_regclass('public.destinations') is null
     or to_regclass('public.gallery_items') is null
     or to_regclass('public.site_settings') is null
     or to_regclass('public.bookings') is null
     or to_regclass('public.booking_travellers') is null
     or to_regclass('public.payments') is null
     or to_regclass('public.package_availability') is null then
    raise exception 'Required production tables are missing; no changes applied';
  end if;

  select string_agg(required.column_name,', ' order by required.column_name)
  into v_missing
  from (values
    ('tour_packages','id'),('tour_packages','slug'),('tour_packages','title'),
    ('tour_packages','destination_id'),('tour_packages','category'),
    ('tour_packages','duration_days'),('tour_packages','duration_nights'),
    ('tour_packages','summary'),('tour_packages','overview'),('tour_packages','description'),
    ('tour_packages','hero_image'),('tour_packages','trip_style'),
    ('tour_packages','highlights'),('tour_packages','inclusions'),('tour_packages','exclusions'),
    ('tour_packages','important_information'),('tour_packages','base_price'),
    ('tour_packages','child_price'),('tour_packages','infant_price'),
    ('tour_packages','tax_rate'),('tour_packages','advance_type'),
    ('tour_packages','advance_value'),('tour_packages','currency'),
    ('tour_packages','is_upcoming'),('tour_packages','published'),
    ('tour_packages','published_at'),('tour_packages','seo_title'),
    ('tour_packages','seo_description'),('tour_packages','updated_at'),
    ('tour_itinerary_days','id'),('tour_itinerary_days','package_id'),
    ('tour_itinerary_days','day_number'),('tour_itinerary_days','title'),
    ('tour_itinerary_days','description'),('tour_itinerary_days','location'),
    ('tour_itinerary_days','updated_at')
  ) required(table_name,column_name)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema='public' and c.table_name=required.table_name
      and c.column_name=required.column_name
  );

  if v_missing is not null then
    raise exception 'Required production columns are missing: %',v_missing;
  end if;

  if not exists (
    select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace
    where n.nspname='public' and t.typname='package_category'
  ) or exists (
    select 1 from (values('domestic'),('international'),('strangers_meetup'),('custom')) required(label)
    where not exists (
      select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid
      join pg_namespace n on n.oid=t.typnamespace
      where n.nspname='public' and t.typname='package_category' and e.enumlabel=required.label
    )
  ) then
    raise exception 'Required package_category enum values are missing; no changes applied';
  end if;

  if not exists (
    select 1 from pg_index i
    where i.indrelid='public.tour_packages'::regclass and i.indisunique
      and (select array_agg(a.attname order by k.ordinality)
           from unnest(i.indkey::smallint[]) with ordinality k(attnum,ordinality)
           join pg_attribute a on a.attrelid=i.indrelid and a.attnum=k.attnum)
          =array['slug']::name[]
  ) then
    raise exception 'tour_packages.slug unique constraint is missing';
  end if;

  if not exists (
    select 1 from pg_index i
    where i.indrelid='public.tour_itinerary_days'::regclass and i.indisunique
      and i.indpred is null and i.indexprs is null
      and (select array_agg(a.attname order by k.ordinality)
           from unnest(i.indkey::smallint[]) with ordinality k(attnum,ordinality)
           join pg_attribute a on a.attrelid=i.indrelid and a.attnum=k.attnum)
          =array['package_id','day_number']::name[]
  ) then
    raise exception 'tour_itinerary_days(package_id,day_number) unique constraint is missing';
  end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_booking_secure'
      and pg_get_function_identity_arguments(p.oid)=
        'p_package_slug text, p_travel_date date, p_travellers jsonb, p_payment_mode text, p_idempotency_key uuid'
      and p.prosecdef
      and p.proconfig @> array['search_path=public, pg_temp']
  ) then
    raise exception 'Audited SECURITY DEFINER create_booking_secure signature/configuration changed';
  end if;

  select md5(regexp_replace(lower(p.prosrc),'\s+','','g'))
  into v_booking_function_hash
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_booking_secure'
    and pg_get_function_identity_arguments(p.oid)=
      'p_package_slug text, p_travel_date date, p_travellers jsonb, p_payment_mode text, p_idempotency_key uuid';

  if v_marker is null and v_booking_function_hash<>'7362c9a33778656c6d2a572cf3760e82' then
    raise exception 'Audited create_booking_secure body changed after the production diagnostic; no function was replaced';
  end if;
  if v_marker is not null and v_booking_function_hash<>'b5a8d95dab62ae238149a45cbf7545d1' then
    raise exception 'Reconciled create_booking_secure body has later edits; rerun stopped';
  end if;

  if exists (
    select 1 from (values
      ('tour_packages'),('tour_itinerary_days'),('destinations'),('gallery_items'),
      ('site_settings'),('bookings'),('booking_travellers'),('payments'),('package_availability')
    ) required(table_name)
    join pg_class c on c.oid=to_regclass('public.'||required.table_name)
    where not c.relrowsecurity
  ) then
    raise exception 'RLS is no longer enabled on one or more audited public tables';
  end if;

  with expected(schema_name,table_name,policy_name,permissive,roles,command,using_expression,check_expression) as (
    values
      ('public','booking_travellers','admin_booking_travellers','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','booking_travellers','travellers_admin_manage','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','booking_travellers','travellers_read','PERMISSIVE',array['authenticated']::name[],'SELECT',$policy$(EXISTS (SELECT 1 FROM bookings b WHERE ((b.id = booking_travellers.booking_id) AND ((b.customer_id = auth.uid()) OR is_admin()))))$policy$,null),
      ('public','bookings','bookings_admin_update','PERMISSIVE',array['authenticated']::name[],'UPDATE',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','bookings','bookings_read','PERMISSIVE',array['authenticated']::name[],'SELECT',$policy$((customer_id = auth.uid()) OR is_admin())$policy$,null),
      ('public','destinations','admin_manage','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','destinations','public_read_published','PERMISSIVE',array['anon','authenticated']::name[],'SELECT',$policy$((published = true) OR is_admin())$policy$,null),
      ('public','gallery_items','admin_manage','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','gallery_items','public_read_published','PERMISSIVE',array['anon','authenticated']::name[],'SELECT',$policy$((published = true) OR is_admin())$policy$,null),
      ('public','package_availability','admin_availability','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','package_availability','public_availability','PERMISSIVE',array['anon','authenticated']::name[],'SELECT',$policy$((status = 'open'::text) AND (EXISTS (SELECT 1 FROM tour_packages p WHERE ((p.id = package_availability.package_id) AND p.published))))$policy$,null),
      ('public','payments','payments_read','PERMISSIVE',array['authenticated']::name[],'SELECT',$policy$(EXISTS (SELECT 1 FROM bookings b WHERE ((b.id = payments.booking_id) AND ((b.customer_id = auth.uid()) OR is_admin()))))$policy$,null),
      ('public','site_settings','admin_site_settings','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','site_settings','public_site_settings','PERMISSIVE',array['anon','authenticated']::name[],'SELECT',$policy$((COALESCE((value ->> 'public'::text), 'false'::text) = 'true'::text) OR is_admin())$policy$,null),
      ('public','tour_itinerary_days','admin_itinerary_days','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','tour_itinerary_days','public_itinerary_days','PERMISSIVE',array['anon','authenticated']::name[],'SELECT',$policy$(EXISTS (SELECT 1 FROM tour_packages p WHERE ((p.id = tour_itinerary_days.package_id) AND (p.published OR is_admin()))))$policy$,null),
      ('public','tour_packages','admin_manage','PERMISSIVE',array['authenticated']::name[],'ALL',$policy$is_admin()$policy$,$policy$is_admin()$policy$),
      ('public','tour_packages','public_read_published','PERMISSIVE',array['anon','authenticated']::name[],'SELECT',$policy$((published = true) OR is_admin())$policy$,null),
      ('storage','objects','site_media_admin_delete','PERMISSIVE',array['authenticated']::name[],'DELETE',$policy$((bucket_id = 'site-media'::text) AND is_admin())$policy$,null),
      ('storage','objects','site_media_admin_insert','PERMISSIVE',array['authenticated']::name[],'INSERT',null,$policy$((bucket_id = 'site-media'::text) AND is_admin())$policy$),
      ('storage','objects','site_media_admin_update','PERMISSIVE',array['authenticated']::name[],'UPDATE',$policy$((bucket_id = 'site-media'::text) AND is_admin())$policy$,$policy$((bucket_id = 'site-media'::text) AND is_admin())$policy$),
      ('storage','objects','site_media_public_read','PERMISSIVE',array['public']::name[],'SELECT',$policy$(bucket_id = 'site-media'::text)$policy$,null)
  ), drift as (
    select e.schema_name||'.'||e.table_name||'.'||e.policy_name as item
    from expected e
    left join pg_policies p on p.schemaname=e.schema_name and p.tablename=e.table_name and p.policyname=e.policy_name
    where p.policyname is null or p.permissive<>e.permissive or p.roles<>e.roles or p.cmd<>e.command
      or regexp_replace(coalesce(p.qual,'<null>'),'\s+','','g')<>
         regexp_replace(coalesce(e.using_expression,'<null>'),'\s+','','g')
      or regexp_replace(coalesce(p.with_check,'<null>'),'\s+','','g')<>
         regexp_replace(coalesce(e.check_expression,'<null>'),'\s+','','g')
    union all
    select p.schemaname||'.'||p.tablename||'.'||p.policyname
    from pg_policies p
    where ((p.schemaname='public' and p.tablename in (
      'tour_packages','tour_itinerary_days','destinations','gallery_items','site_settings',
      'bookings','booking_travellers','payments','package_availability'
    )) or (p.schemaname='storage' and p.tablename='objects'))
      and not exists(select 1 from expected e where e.schema_name=p.schemaname and e.table_name=p.tablename and e.policy_name=p.policyname)
  )
  select string_agg(item,', ' order by item) into v_policy_drift from drift;

  if v_policy_drift is not null then
    raise exception 'Audited RLS/storage policy definition drift detected; no changes applied: %',v_policy_drift;
  end if;

  if v_marker is null then
    -- The diagnostic is the first-run baseline. A later Admin edit to any row
    -- this reconciliation manages must be reviewed rather than overwritten.
    select string_agg(changed.item,', ' order by changed.item)
    into v_conflicts
    from (
      select 'package '||p.slug as item from public.tour_packages p
      where p.slug in (
        'kashmir-kargil','delhi-agra-jaipur-amritsar-wagah-border','rajasthan','kullu-manali-kasol',
        'rajasthan-heritage','bali','bali-nusa-penida','bali-island-escape',
        'agumbe','ajanta-ellora','andaman'
      ) and p.updated_at>v_diagnostic_at
      union all
      select 'destination '||d.slug from public.destinations d
      where d.slug in ('bali','bali-nusa-penida','agumbe','ajanta-ellora','andaman')
        and d.updated_at>v_diagnostic_at
      union all
      select 'gallery '||coalesce(g.slug,g.id::text) from public.gallery_items g
      where g.media_type='image' and g.media_url ilike '%tulip%' and g.updated_at>v_diagnostic_at
      union all
      select 'site setting company_contact' from public.site_settings s
      where s.key='company_contact' and s.updated_at>v_diagnostic_at
    ) changed;

    if v_conflicts is not null then
      raise exception 'Managed content changed after the production diagnostic; first run stopped: %',v_conflicts;
    end if;

    -- These four audited rows are untouched catalogue placeholders. Other
    -- CR package slugs are absent and are inserted below.
    select string_agg(p.slug,', ' order by p.slug)
    into v_conflicts
    from public.tour_packages p
    where p.slug in (
      'kashmir-kargil','delhi-agra-jaipur-amritsar-wagah-border',
      'rajasthan','kullu-manali-kasol'
    )
      and not (
        p.summary='Details coming soon. Contact My Tripon Travel to register your interest.'
        and p.base_price is null and p.description is null
        and p.highlights='[]'::jsonb and p.inclusions='[]'::jsonb and p.exclusions='[]'::jsonb
        and not exists(select 1 from public.tour_itinerary_days d where d.package_id=p.id)
      );

    if v_conflicts is not null then
      raise exception 'Audited placeholder packages now contain Admin content: %',v_conflicts;
    end if;

    select string_agg(required.slug,', ' order by required.slug)
    into v_missing
    from (values
      ('kashmir-kargil'),('delhi-agra-jaipur-amritsar-wagah-border'),
      ('rajasthan'),('kullu-manali-kasol')
    ) required(slug)
    where not exists(select 1 from public.tour_packages p where p.slug=required.slug);

    if v_missing is not null then
      raise exception 'Audited placeholder packages are missing: %',v_missing;
    end if;

    select string_agg(p.slug,', ' order by p.slug)
    into v_conflicts
    from public.tour_packages p
    where p.slug in (
      'delhi-agra-jaipur-golden-triangle-tour',
      'delhi-agra-mathura-jaipur-tour','delhi-agra-tour',
      'delhi-agra-amritsar-tour','kashmir-kargil-dhooth-pathri-tour',
      'delhi-kullu-manali-tour'
    );

    if v_conflicts is not null then
      raise exception 'Expected-new CR package slugs appeared after the diagnostic: %',v_conflicts;
    end if;
  else
    -- set_updated_at triggers were present in the diagnostic. Any later Admin
    -- edit to managed package/itinerary rows stops a rerun before writes.
    select string_agg(changed.item,', ' order by changed.item)
    into v_conflicts
    from (
      select 'package '||p.slug as item
      from public.tour_packages p
      where p.slug in (
        'kashmir-kargil','delhi-agra-jaipur-golden-triangle-tour',
        'delhi-agra-mathura-jaipur-tour','delhi-agra-tour',
        'delhi-agra-jaipur-amritsar-wagah-border','delhi-agra-amritsar-tour',
        'rajasthan','kashmir-kargil-dhooth-pathri-tour',
        'delhi-kullu-manali-tour','kullu-manali-kasol','rajasthan-heritage',
        'bali','bali-nusa-penida','bali-island-escape',
        'agumbe','ajanta-ellora','andaman'
      ) and p.updated_at>v_marker
      union all
      select 'itinerary '||p.slug||' day '||d.day_number
      from public.tour_itinerary_days d
      join public.tour_packages p on p.id=d.package_id
      where p.slug in (
        'kashmir-kargil','delhi-agra-jaipur-golden-triangle-tour',
        'delhi-agra-mathura-jaipur-tour','delhi-agra-tour',
        'delhi-agra-jaipur-amritsar-wagah-border','delhi-agra-amritsar-tour',
        'rajasthan','kashmir-kargil-dhooth-pathri-tour',
        'delhi-kullu-manali-tour','kullu-manali-kasol'
      ) and d.updated_at>v_marker
      union all
      select 'destination '||d.slug
      from public.destinations d
      where d.slug in ('bali','bali-nusa-penida','agumbe','ajanta-ellora','andaman')
        and d.updated_at>v_marker
      union all
      select 'gallery '||coalesce(g.slug,g.id::text)
      from public.gallery_items g
      where g.media_type='image' and g.media_url ilike '%tulip%'
        and g.updated_at>v_marker
      union all
      select 'site setting company_contact'
      from public.site_settings s
      where s.key='company_contact' and s.updated_at>v_marker
    ) changed;

    if v_conflicts is not null then
      raise exception 'Managed content has later Admin edits; reconciliation rerun stopped: %',v_conflicts;
    end if;
  end if;
end
$preflight$;



-- Client change requests 1-6: non-destructive catalogue/contact preparation.
-- The five packages remain unpublished and non-bookable until the original
-- itinerary/inclusion/exclusion copy is supplied and reviewed.
-- Prerequisite: 202610150000_package_category_values.sql commits enum additions
-- before this migration runs.


alter table public.tour_packages
  add column if not exists age_pricing jsonb not null default '[]'::jsonb,
  add column if not exists booking_enabled boolean not null default false;

insert into public.tour_packages (
  slug,title,category,duration_days,duration_nights,summary,base_price,
  infant_price,age_pricing,advance_type,advance_value,important_information,
  booking_enabled,published
)
values
  ('kashmir-kargil','Kashmir–Kargil Tour','domestic',5,4,
   'Srinagar, Gulmarg, Pahalgam, Sonmarg, Drass, Zero Point, Kargil War Memorial and Kargil LOC.',2100000,0,
   '[{"label":"Below 2 years","min_age":0,"max_age":1,"price":0},{"label":"Age 2–6","min_age":2,"max_age":6,"price":800000},{"label":"Age 7–12","min_age":7,"max_age":12,"price":1400000}]'::jsonb,
   'fixed',1000000,'Optional return train ticket inclusion requires client confirmation.',false,false),
  ('delhi-agra-jaipur-golden-triangle-tour','Delhi–Agra–Jaipur Golden Triangle Tour','domestic',4,3,
   'Delhi, Agra, Fatehpur Sikri and Jaipur.',2200000,0,
   '[{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":900000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1700000},{"label":"Above 14","min_age":15,"price":2200000}]'::jsonb,
   'percentage',0,'Published duration says 4 Days / 3 Nights while the supplied outline contains Day 1–5. Client confirmation required. Age 3 is not priced.',false,false),
  ('delhi-agra-mathura-jaipur-tour','Delhi–Agra–Mathura–Jaipur Tour','domestic',5,4,
   'Delhi, Agra, Fatehpur Sikri, Mathura and Jaipur.',2600000,0,
   '[{"label":"Below 3 years – free, no bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without separate bed","min_age":4,"max_age":6,"price":1100000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1600000},{"label":"Above 14","min_age":15,"price":2600000}]'::jsonb,
   'percentage',0,'Published duration says 5 Days / 4 Nights while the supplied outline contains Day 1–6. Client confirmation required. Age 3 is not priced.',false,false),
  ('delhi-agra-tour','Delhi–Agra Tour','domestic',3,2,
   'Delhi and Agra.',1200000,0,
   '[{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":600000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":900000},{"label":"Above 14","min_age":15,"price":1200000}]'::jsonb,
   'percentage',0,'Complete original timings, descriptions, inclusions and exclusions are awaiting the authoritative client copy. Age 3 is not priced.',false,false),
  ('delhi-agra-jaipur-amritsar-wagah-border','Delhi–Agra–Mathura–Jaipur–Amritsar–Wagah Border Tour','domestic',7,6,
   'Delhi, Agra, Jaipur, Fatehpur Sikri, Mathura, Amritsar and Attari–Wagah Border.',3400000,0,
   '[{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":2100000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":2900000},{"label":"Above 14","min_age":15,"price":3400000}]'::jsonb,
   'percentage',0,'Published duration says 7 Days / 6 Nights while the supplied outline contains Day 1–8. Client confirmation required. Age 3 is not priced.',false,false)
on conflict (slug) do update set
  title=excluded.title,
  category=excluded.category,
  duration_days=excluded.duration_days,
  duration_nights=excluded.duration_nights,
  summary=excluded.summary,
  base_price=excluded.base_price,
  infant_price=excluded.infant_price,
  age_pricing=excluded.age_pricing,
  advance_type=excluded.advance_type,
  advance_value=excluded.advance_value,
  important_information=coalesce(nullif(public.tour_packages.important_information,''),excluded.important_information),
  booking_enabled=false,
  published=false,
  published_at=null,
  updated_at=now();

insert into public.site_settings(key,value)
values ('company_contact',jsonb_build_object(
  'public',true,
  'legalName','My Tripon Travel Pvt Ltd',
  'corporateOffice',jsonb_build_object('address','Mahipalpur, Delhi - 110037','phone','7582999111'),
  'kozhikodeOffice',jsonb_build_object('address','7th Floor, Sky Towers, Mavoor Road Junction, Kozhikode.','phone','7592883311'),
  'email','mytripontravel@gmail.com',
  'website','www.mytripontravel.com'
))
on conflict(key) do update set value=excluded.value,updated_at=now();

update public.gallery_items
set title='Tulip Garden',
    alt_text='Rows of colourful tulips at Tulip Garden in Kashmir',
    updated_at=now()
where media_type='image'
  and media_url ilike '%tulip%'
  and (title ilike '%agumbe%' or alt_text ilike '%agumbe%');



-- My Tripon Travel Pvt Ltd — full organized client tour content (CR2–CR6)
-- Prerequisite: 202610150001_client_changes_1_6.sql.
-- Forward-only, idempotent and non-destructive. This migration intentionally
-- leaves every package unpublished and booking-disabled pending client review.


do $$
declare
  missing_slugs text;
  unexpected_days text;
  duplicate_days text;
begin
  select string_agg(required.slug, ', ' order by required.slug)
  into missing_slugs
  from (values
    ('kashmir-kargil'),
    ('delhi-agra-jaipur-golden-triangle-tour'),
    ('delhi-agra-mathura-jaipur-tour'),
    ('delhi-agra-tour'),
    ('delhi-agra-jaipur-amritsar-wagah-border')
  ) required(slug)
  where not exists (select 1 from public.tour_packages p where p.slug=required.slug);

  if missing_slugs is not null then
    raise exception 'Prerequisite package records are missing: %. Run 202610150001_client_changes_1_6.sql first.', missing_slugs;
  end if;

  select string_agg(p.slug || ': day ' || d.day_number::text, ', ' order by p.slug,d.day_number)
  into unexpected_days
  from public.tour_itinerary_days d
  join public.tour_packages p on p.id=d.package_id
  join (values
    ('kashmir-kargil',5),
    ('delhi-agra-jaipur-golden-triangle-tour',5),
    ('delhi-agra-mathura-jaipur-tour',6),
    ('delhi-agra-tour',3),
    ('delhi-agra-jaipur-amritsar-wagah-border',8)
  ) expected(slug,max_day) on expected.slug=p.slug
  where d.day_number<1 or d.day_number>expected.max_day;

  if unexpected_days is not null then
    raise exception 'Unexpected existing itinerary rows require manual review; no rows were deleted: %', unexpected_days;
  end if;

  select string_agg(p.slug || ': day ' || duplicates.day_number::text || ' (' || duplicates.row_count::text || ' rows)', ', ' order by p.slug,duplicates.day_number)
  into duplicate_days
  from (
    select package_id,day_number,count(*) as row_count
    from public.tour_itinerary_days
    group by package_id,day_number
    having count(*)>1
  ) duplicates
  join public.tour_packages p on p.id=duplicates.package_id;

  if duplicate_days is not null then
    raise exception 'Duplicate itinerary rows must be reviewed before adding the package/day uniqueness guard: %', duplicate_days;
  end if;
end $$;

-- ON CONFLICT(package_id,day_number) requires a compatible unique index. The
-- canonical schema already has one; this drift-safe guard adds it only when no
-- equivalent unique index exists, after the duplicate preflight above.
do $$
begin
  if not exists (
    select 1
    from pg_index i
    where i.indrelid='public.tour_itinerary_days'::regclass
      and i.indisunique
      and i.indpred is null
      and i.indexprs is null
      and (
        select array_agg(a.attname order by key_column.ordinality)
        from unnest(i.indkey::smallint[]) with ordinality key_column(attnum,ordinality)
        join pg_attribute a on a.attrelid=i.indrelid and a.attnum=key_column.attnum
      )=array['package_id','day_number']::name[]
  ) then
    execute 'create unique index tour_itinerary_days_package_day_uidx on public.tour_itinerary_days(package_id,day_number)';
  end if;
end $$;

-- Package metadata, prices, safety notes and exact client-supplied lists.
update public.tour_packages p
set
  title=source.title,
  category='domestic'::public.package_category,
  duration_days=source.duration_days,
  duration_nights=source.duration_nights,
  summary=source.summary,
  description=source.description,
  -- Preserve every existing package image. Missing images remain for Admin to
  -- supply rather than assigning the same generic Taj Mahal image to tours.
  trip_style='Guided domestic group tour',
  highlights=source.highlights,
  inclusions=source.inclusions,
  exclusions=source.exclusions,
  important_information=source.important_information,
  base_price=source.base_price,
  child_price=null,
  infant_price=0,
  age_pricing=source.age_pricing,
  advance_type=source.advance_type,
  advance_value=source.advance_value,
  booking_enabled=false,
  published=false,
  published_at=null,
  seo_title=source.title || ' | My Tripon Travel Pvt Ltd',
  seo_description=source.summary,
  updated_at=now()
from (values
  (
    'kashmir-kargil',
    'Kashmir–Kargil Tour',5,4,
    'A proposed 5-day/4-night route through Srinagar, Sonmarg, Kargil, Pahalgam and Gulmarg, subject to access, weather and final operational confirmation.',
    'Client-supplied proposed itinerary covering Srinagar, Sonmarg, Drass, Kargil LOC and War Memorial, Pahalgam and Gulmarg. Access-controlled places, train arrangements, ticket prices and operating conditions require confirmation before publication.',
    '["Srinagar","Gulmarg","Pahalgam","Sonmarg","Drass","Zero Point","Kargil War Memorial","Kargil LOC"]'::jsonb,
    '["Three-star-category hotels for four nights (client wording: ‘4 days’): one night Kargil and three nights Srinagar; one bedroom/family or twin sharing; breakfast and dinner at hotel.","AC Urbania/bus sightseeing.","Entry tickets including Gondola Phase 1 (client-stated indicative amount approximately ₹1,000/person; current rate not verified).","Breakfast vegetarian, lunch vegetarian, dinner vegetarian and non-vegetarian.","Two mineral-water bottles per day per person.","Local union taxi charges at Pahalgam, Sonmarg and Kargil.","Srinagar airport pickup and drop.","Taxes, tolls and parking.","Malayali tour guide and manager."]'::jsonb,
    '["Flight and train tickets.","Additional expenses not included above.","Gondola Phase 2.","Expenses arising from natural calamities, strikes or bandhs.","Expenses arising from flight cancellation or delay.","Food at airports or on flights.","Transport to or from Delhi airport."]'::jsonb,
    $note$Booking was described by the client as available through the website, online or in person, subject to final confirmation. Schedule and access are subject to operational confirmation. Zojila Pass is subject to tourist access, weather and landslide conditions; if closed, the itinerary returns from Sonmarg for a Srinagar stay. Kargil LOC access is permission-controlled and requires locally permitted Kargil vehicles. Pahalgam, Sonmarg and Kargil local union taxis are included as supplied. Gondola Phase 1 is included; Phase 2 is excluded. Client-supplied geographic superlatives and indicative Gondola prices have not been independently verified. The optional return sequence supplied—2:00 PM Vande Bharat toward Jammu, 4:00 PM Chenab Bridge crossing, 5:30 PM Jammu arrival and 9:00 PM Rajdhani Express toward Delhi with 3AC sleeper tickets—conflicts with the general exclusion of flight/train tickets and requires written clarification. Ages above 12 are not explicitly priced. No automatic checkout.$note$,
    2100000,
    '[{"label":"Adult","min_age":null,"max_age":null,"price":2100000},{"label":"Below 2 years","min_age":0,"max_age":1,"price":0},{"label":"Age 2–6","min_age":2,"max_age":6,"price":800000},{"label":"Age 7–12","min_age":7,"max_age":12,"price":1400000}]'::jsonb,
    'fixed',1000000
  ),
  (
    'delhi-agra-jaipur-golden-triangle-tour',
    'Delhi–Agra–Jaipur Golden Triangle Tour',4,3,
    'A proposed Delhi, Jaipur, Fatehpur Sikri and Agra itinerary supplied as 4 days/3 nights but containing five numbered days.',
    'Client-supplied proposed Golden Triangle schedule. The 4-day/3-night heading conflicts with the complete Day 1–5 itinerary and must be confirmed before publication or booking.',
    '["Delhi","Agra","Fatehpur Sikri","Jaipur"]'::jsonb,
    '["Two mineral-water bottles per day per person.","Taxes, tolls and parking.","Airport or railway pickup and drop."]'::jsonb,
    '["Flights or trains required to reach Delhi.","Anything outside the supplied inclusions.","Unexpected costs arising from strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses."]'::jsonb,
    $note$Schedule subject to confirmation: the source heading says 4 Days / 3 Nights, while the supplied itinerary contains Day 1–5. The original inclusion list appears incomplete; only the supplied tail of three items is stored and nothing additional has been invented. Age exactly 3 is undefined. Optional elephant rides, room availability, attraction access and operating times are not guaranteed. No automatic checkout.$note$,
    2200000,
    '[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2200000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":900000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1700000}]'::jsonb,
    'percentage',0
  ),
  (
    'delhi-agra-mathura-jaipur-tour',
    'Delhi–Agra–Mathura–Jaipur Tour',5,4,
    'A proposed Delhi, Jaipur, Fatehpur Sikri, Agra and Mathura itinerary supplied as 5 days/4 nights but containing six numbered days.',
    'Client-supplied proposed schedule covering Jaipur, Fatehpur Sikri, Taj Mahal, Agra Fort, Mathura, Akshardham and Delhi. Duration requires confirmation.',
    '["Delhi","Agra","Fatehpur Sikri","Mathura","Jaipur"]'::jsonb,
    '["Three-star hotel (client wording: ‘4 days’), twin sharing.","AC pushback Urbania/bus.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","Taxes, tolls and parking.","Airport or railway pickup and drop."]'::jsonb,
    '["Flights or trains required to reach Delhi.","Anything outside the supplied inclusions.","Costs arising from strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses."]'::jsonb,
    $note$Schedule subject to confirmation: the source heading says 5 Days / 4 Nights, while the supplied itinerary contains Day 1–6. Age exactly 3 is undefined. Akshardham show schedule/admission, hotel room availability, optional elephant rides and attraction access are subject to actual operating conditions. No automatic checkout.$note$,
    2600000,
    '[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2600000},{"label":"Below 3 years – free, no bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without separate bed","min_age":4,"max_age":6,"price":1100000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1600000}]'::jsonb,
    'percentage',0
  ),
  (
    'delhi-agra-tour',
    'Delhi–Agra Tour',3,2,
    'A proposed 3-day/2-night Delhi and Agra tour covering Akshardham, Agra Fort, Taj Mahal and major Delhi landmarks.',
    'Client-supplied proposed three-day schedule for Delhi and Agra. Age-band and operational details require confirmation before booking.',
    '["Delhi","Agra"]'::jsonb,
    '["Three-star hotel (client wording: ‘2 days’), twin sharing.","AC pushback Urbania/bus.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","Taxes, tolls and parking.","Airport or railway pickup and drop."]'::jsonb,
    '["Flights or trains required to reach Delhi.","Anything not included above.","Unexpected costs arising from strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses."]'::jsonb,
    $note$The source supplies a complete 3 Days / 2 Nights itinerary. Age exactly 3 is undefined, so automatic checkout remains disabled. Attraction access, opening times, transport and hotel availability require operational confirmation.$note$,
    1200000,
    '[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":1200000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":600000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":900000}]'::jsonb,
    'percentage',0
  ),
  (
    'delhi-agra-jaipur-amritsar-wagah-border',
    'Delhi–Agra–Mathura–Jaipur–Amritsar–Wagah Border Tour',7,6,
    'A proposed Delhi, Jaipur, Agra, Mathura and Amritsar itinerary supplied as 7 days/6 nights but containing eight numbered days.',
    'Client-supplied proposed schedule covering Jaipur, Fatehpur Sikri, Taj Mahal, Mathura, Delhi, Amritsar and the Attari–Wagah Border. Duration and transport schedules require confirmation.',
    '["Delhi","Agra","Jaipur","Fatehpur Sikri","Mathura","Amritsar","Attari–Wagah Border"]'::jsonb,
    '["Three-star hotel (client wording: ‘5 days’), twin sharing.","AC pushback Urbania/bus sightseeing.","Delhi–Amritsar train tickets.","Amritsar–Delhi AC Volvo semi-sleeper tickets.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","Taxes, tolls and parking.","Airport or railway pickup and drop."]'::jsonb,
    '["Flights or trains required to reach Delhi.","Anything outside the supplied inclusions.","Costs arising from strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses."]'::jsonb,
    $note$Schedule subject to confirmation: the source heading says 7 Days / 6 Nights, while the supplied itinerary contains Day 1–8 and an overnight bus journey. Age exactly 3 is undefined. The client-supplied 3:15 PM Vande Bharat schedule, Volvo service, room availability, attraction access and Attari–Wagah ceremony time are not verified inventory or guarantees. No automatic checkout.$note$,
    3400000,
    '[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":3400000},{"label":"Below 3 years – free, no bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":2100000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":2900000}]'::jsonb,
    'percentage',0
  )
) source(
  slug,title,duration_days,duration_nights,summary,description,
  highlights,inclusions,exclusions,important_information,base_price,age_pricing,
  advance_type,advance_value
)
where p.slug=source.slug;

-- Exact organized day-wise schedules. Descriptions retain every supplied time,
-- stop, conditional arrangement and operational caution without adding inventory.
-- Statement-local source rows: no temporary/session object is created.
do $client_tour_itinerary$
declare
  source record;
  existing_row record;
begin
  for source in
    select * from (values
('kashmir-kargil',1,'Srinagar → Sonmarg → Kargil',$day$10:00 AM — Pickup from Srinagar Airport.
10:30 AM — Depart for Sonmarg.
12:00 noon — River Sindhu.
1:00 PM — Lunch.
2:00 PM — Sonmarg Tunnel; approximately one hour at Sonmarg.
Proceed via Zojila Pass, subject to tourist access and weather/landslide conditions. If closed, return from Sonmarg and stay in Srinagar instead. The client’s “third-highest motorable pass” description is not presented as a verified claim.
4:00 PM — Captain MOD Point.
5:00 PM — Zero Point; approximately 30 minutes. The client’s geographic superlative is not presented as a verified claim.
6:00 PM — Drass.
8:00 PM — Arrive Kargil.
9:00 PM — Dinner; overnight Kargil.$day$,'Srinagar · Sonmarg · Drass · Kargil'),
  ('kashmir-kargil',2,'Kargil LOC → Srinagar',$day$7:30 AM — Breakfast.
8:00 AM — Depart for the Kargil India–Pakistan border/LOC. The private tour vehicle is not permitted; hire locally permitted Kargil cars.
9:00 AM — Shivaji Temple.
10:00 AM — Kargil LOC / last Indian military picket viewpoint, subject to access permissions; approximately one hour. Client notes views toward a Pakistan-side village and pickets.
11:30 AM — Hunterman Village, described by the client as the last Indian border village.
12:30 PM — Hotel return and lunch.
1:00 PM — Hotel checkout; depart for Srinagar.
2:00 PM — Kargil War Memorial; approximately 30 minutes for the museum/documentary and to pay respects.
6:00 PM — Shikara ride on Dal Lake; approximately one hour with houseboat, floating-market and village views.
7:30 PM — Shopping at Dal Lake.
8:30 PM — Campfire.
9:00 PM — Hotel check-in.
9:30 PM — Dinner; overnight Srinagar hotel.$day$,'Kargil LOC · Kargil War Memorial · Srinagar'),
  ('kashmir-kargil',3,'Pahalgam',$day$7:30 AM — Breakfast.
8:00 AM — Depart toward Pahalgam.
9:00 AM — Saffron paddy at Pampore.
9:30 AM — Pulwama terrorist attack point.
10:00 AM — Cricket bat factory.
11:30 AM — Apple farms at Pahalgam; photographs and optional apple purchase/picking subject to farm permission and season.
1:00 PM — Lunch.
2:30 PM — Proceed toward Chandanwadi and Betaab Valley; local taxis are required and included. Client describes a two-hour excursion with approximately 30 minutes at each place.
3:30 PM — Chandanwadi.
4:30 PM — Betaab Valley.
5:30 PM — Mini Switzerland / Baisaran Valley (client supplied “BYSON VALLEY”); precise destination and access require confirmation.
7:00 PM — Return toward Srinagar.
9:30 PM — Arrive hotel.
10:00 PM — Dinner; overnight Srinagar.$day$,'Pampore · Pahalgam · Chandanwadi · Betaab Valley · Baisaran Valley'),
  ('kashmir-kargil',4,'Gulmarg',$day$7:30 AM — Breakfast.
8:00 AM — Depart for Gulmarg.
9:00 AM — Nishat Gardens; approximately 30 minutes, with optional traditional Kashmiri-dress photography.
11:30 AM — Tangmarg and lunch.
2:00 PM — Gulmarg Gondola; approximately 2–3 hours exploring. Phase 1 Gulmarg–Kongdori ticket (client-stated indicative amount approximately ₹1,000) is included. Phase 2 Kongdori–Apharwat (client-stated indicative amount approximately ₹1,200/person) is additional and excluded. Current ticket rates are not verified.
5:30 PM — Return to Srinagar.
7:00 PM — Hazratbal Mosque; client notes modest dress/head covering for women and its religious significance.
7:30 PM — Shopping at Lal Chowk.
10:00 PM — Dinner; overnight hotel.$day$,'Nishat Gardens · Tangmarg · Gulmarg · Srinagar'),
  ('kashmir-kargil',5,'Srinagar departure',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout.
9:00 AM — Shalimar Gardens; approximately 30 minutes, a Mughal garden associated with Emperor Jahangir.
10:00 AM — Shankaracharya Hill and Temple; approximately one hour with panoramic views of Dal Lake and Srinagar.
1:00 PM — Drop at Srinagar Airport/Railway Station.

Optional client-supplied train-return sequence, not confirmed as included: 2:00 PM Vande Bharat toward Jammu; 4:00 PM cross Chenab Bridge; 5:30 PM reach Jammu Railway Station; 9:00 PM Rajdhani Express toward Delhi; client says 3AC sleeper tickets are provided. This conflicts with the general train-ticket exclusion and all timings/routes require verification.$day$,'Srinagar'),

  ('delhi-agra-jaipur-golden-triangle-tour',1,'Flight arrival planning',$day$Depart from any airport and reach Delhi Airport on or before 2:00 AM the next day; choose the flight accordingly.$day$,'Delhi arrival planning'),
  ('delhi-agra-jaipur-golden-triangle-tour',2,'Jaipur',$day$1:00 AM — Welcome at Delhi Airport Terminals 1/2/3 by representatives and tour manager.
2:00 AM — Leave Delhi Airport for Jaipur in a luxury AC pushback bus.
8:00 AM — Reach Jaipur; hotel check-in subject to room availability.
9:30 AM — Breakfast.
10:00 AM — Depart for Jaipur sightseeing.
11:00 AM — Amber Palace/Amber Fort; UNESCO-associated heritage architecture and views, with local jeep from parking; approximately one hour. Optional elephant ride if interested; availability, ethics and price are not specified.
1:00 PM — Jal Mahal/Water Palace photo stop at Man Sagar Lake.
2:00 PM — Lunch.
3:00 PM — Jantar Mantar, historical astronomical observatory with stone sundial.
4:00 PM — City Palace, Rajput/Mughal architecture and royal museum.
5:30 PM — Hawa Mahal/Palace of Winds, pink sandstone and lattice windows; Pink City.
7:00 PM — Shopping in Jaipur.
9:00 PM — Dinner; hotel overnight.$day$,'Delhi · Jaipur'),
  ('delhi-agra-jaipur-golden-triangle-tour',3,'Fatehpur Sikri and Agra',$day$7:30 AM — Breakfast.
8:00 AM — Hotel checkout and depart toward Agra.
12:00 noon — Fatehpur Sikri, Akbar-era red sandstone Mughal capital and UNESCO site; client notes approximately four hours from Jaipur.
1:30 PM — Lunch.
3:00 PM — Taj Mahal, white-marble mausoleum built by Shah Jahan in memory of Mumtaz Mahal and UNESCO site; stay until sunset.
7:00 PM — Depart toward Delhi.
9:00 PM — Dinner en route.
11:30 PM — Delhi hotel check-in; overnight.$day$,'Jaipur · Fatehpur Sikri · Agra · Delhi'),
  ('delhi-agra-jaipur-golden-triangle-tour',4,'Delhi sightseeing',$day$7:30 AM — Breakfast.
8:00 AM — Depart hotel.
9:00 AM — Qutub Minar, UNESCO-listed historic minaret.
10:30 AM — Lotus Temple.
12:00 noon — Teen Murti Bhavan, historic residence of Jawaharlal Nehru; no claim that it is the current Prime Minister’s home.
1:00 PM — Lunch.
2:00 PM — Birla House/Gandhi Smriti, associated with Mahatma Gandhi’s last days and assassination.
3:00 PM — Indira Gandhi Museum.
4:00 PM — Raj Ghat and memorial area, including memorials to Indian leaders.
5:30 PM — Old/New Parliament House and Rashtrapati Bhavan, outside view only.
6:00 PM — India Gate, memorial and parade-road area; evening visit.
8:30 PM — Return hotel.
9:00 PM — Dinner; overnight.$day$,'Delhi'),
  ('delhi-agra-jaipur-golden-triangle-tour',5,'South Delhi and departure',$day$7:30 AM — Breakfast.
8:00 AM — Hotel checkout.
9:00 AM — Humayun’s Tomb, UNESCO heritage site.
11:00 AM — Red Fort, Mughal-era Delhi fort and Independence Day flag-raising site.
1:00 PM — Lunch.
2:00 PM — Sarojini Market shopping.
6:00 PM — Delhi Airport drop, terminal dependent on flight.$day$,'Delhi'),

  ('delhi-agra-mathura-jaipur-tour',1,'Flight planning',$day$Leave from any airport and arrive at Delhi Airport on or before 2:00 AM the next day.$day$,'Delhi arrival planning'),
  ('delhi-agra-mathura-jaipur-tour',2,'Jaipur',$day$1:00 AM — Welcome at Delhi Airport Terminals 1/2/3.
2:00 AM — AC luxury pushback bus from Delhi to Jaipur.
8:00 AM — Reach Jaipur; hotel check-in subject to room availability.
9:30 AM — Breakfast.
10:00 AM — Depart hotel.
11:00 AM — Amber Palace, UNESCO-associated heritage architecture, jeep transfer from parking, approximately one hour; optional elephant ride.
1:00 PM — Jal Mahal/Water Palace, Man Sagar Lake photo stop.
2:00 PM — Lunch.
3:00 PM — Jantar Mantar astronomical observatory.
4:00 PM — City Palace and museum.
5:30 PM — Hawa Mahal and Pink City.
7:00 PM — Shopping.
9:00 PM — Dinner; Jaipur hotel overnight.$day$,'Delhi · Jaipur'),
  ('delhi-agra-mathura-jaipur-tour',3,'Fatehpur Sikri and Taj Mahal',$day$7:30 AM — Breakfast.
8:00 AM — Checkout and depart Jaipur toward Agra.
12:00 noon — Fatehpur Sikri, Akbar-era red sandstone Mughal heritage site.
1:30 PM — Lunch.
3:00 PM — Taj Mahal, UNESCO white-marble mausoleum; stay until sunset.
7:00 PM — Shopping near Taj Mahal.
8:30 PM — Agra hotel check-in.
9:00 PM — Dinner; Agra overnight.$day$,'Jaipur · Fatehpur Sikri · Agra'),
  ('delhi-agra-mathura-jaipur-tour',4,'Agra, Mathura and Akshardham',$day$7:00 AM — Breakfast.
7:30 AM — Checkout.
8:00 AM — Agra Fort, historic Mughal fort; approximately one hour.
9:30 AM — Leave for Mathura; approximately two hours.
11:30 AM — Mathura Temple, associated with Krishna’s birthplace; approximately one hour.
1:00 PM — Lunch and travel toward Delhi.
4:30 PM — Swaminarayan Akshardham, architecture and evening water/sound/light show; client schedules the visit until 8:30 PM. Show schedule and admission are subject to availability.
10:00 PM — Delhi hotel check-in.
10:30 PM — Dinner; Delhi overnight.$day$,'Agra · Mathura · Delhi'),
  ('delhi-agra-mathura-jaipur-tour',5,'Delhi sightseeing',$day$7:30 AM — Breakfast.
8:00 AM — Depart.
9:00 AM — Qutub Minar.
10:30 AM — Lotus Temple.
12:00 noon — Teen Murti Bhavan, Nehru-associated museum/residence; no claim that it is the current Prime Minister’s residence.
1:00 PM — Lunch.
2:00 PM — Birla House/Gandhi Smriti.
3:00 PM — Indira Gandhi Museum.
4:00 PM — Raj Ghat and memorial area.
5:30 PM — Old/New Parliament and Rashtrapati Bhavan, exterior views only.
6:00 PM — India Gate and ceremonial road area.
8:30 PM — Hotel return.
9:00 PM — Dinner; Delhi overnight.$day$,'Delhi'),
  ('delhi-agra-mathura-jaipur-tour',6,'South Delhi and airport',$day$7:30 AM — Breakfast.
8:00 AM — Checkout.
9:00 AM — Humayun’s Tomb.
11:00 AM — Red Fort.
1:00 PM — Lunch.
2:00 PM — Sarojini Market, approximately three hours.
6:00 PM — Delhi Airport drop, terminal according to flight.$day$,'Delhi'),

  ('delhi-agra-tour',1,'Agra',$day$6:00 AM — Start from Delhi.
8:00 AM — Swaminarayan Akshardham Temple; approximately one hour.
12:30 PM — Lunch in Agra.
1:30 PM — Agra Fort, Mughal-era fort; approximately one hour.
3:30 PM — Taj Mahal, UNESCO white-marble mausoleum and monument to Mumtaz Mahal; visit until sunset.
7:00 PM — Depart toward Delhi.
9:00 PM — Dinner en route.
11:30 PM — Delhi hotel check-in; overnight.$day$,'Delhi · Agra · Delhi'),
  ('delhi-agra-tour',2,'Delhi sightseeing',$day$7:30 AM — Breakfast.
8:00 AM — Leave hotel.
9:00 AM — Qutub Minar.
10:30 AM — Lotus Temple.
12:00 noon — Teen Murti Bhavan, historic Nehru residence/museum; not presented as the current Prime Minister’s residence.
1:00 PM — Lunch.
2:00 PM — Birla House/Gandhi Smriti.
3:00 PM — Indira Gandhi Museum.
4:00 PM — Raj Ghat and memorial area.
5:30 PM — Old/New Parliament House and Rashtrapati Bhavan, exterior only.
6:00 PM — India Gate and ceremonial road area.
8:30 PM — Return to hotel.
9:00 PM — Dinner; overnight.$day$,'Delhi'),
  ('delhi-agra-tour',3,'South Delhi and departure',$day$7:30 AM — Breakfast.
8:00 AM — Checkout.
9:00 AM — Humayun’s Tomb.
11:00 AM — Red Fort.
1:00 PM — Lunch.
2:00 PM — Sarojini Market shopping.
6:00 PM — Delhi Airport drop at T1/T2/T3 depending on flight.$day$,'Delhi'),

  ('delhi-agra-jaipur-amritsar-wagah-border',1,'Flight planning',$day$Depart from any airport and arrive at Delhi Airport on or before 2:00 AM the next day.$day$,'Delhi arrival planning'),
  ('delhi-agra-jaipur-amritsar-wagah-border',2,'Jaipur',$day$1:00 AM — Welcome at Delhi Airport T1/T2/T3 by representatives and tour manager.
2:00 AM — Luxury AC pushback bus to Jaipur.
8:00 AM — Arrive Jaipur; check-in subject to room availability.
9:30 AM — Breakfast.
10:00 AM — Depart for sightseeing.
11:00 AM — Amber Palace, UNESCO-associated architecture, jeep transfer from parking, approximately one hour; optional elephant ride.
1:00 PM — Jal Mahal photo stop at Man Sagar Lake.
2:00 PM — Lunch.
3:00 PM — Jantar Mantar astronomical observatory.
4:00 PM — City Palace and royal museum.
5:30 PM — Hawa Mahal and Pink City.
7:00 PM — Shopping.
9:00 PM — Dinner; hotel overnight.$day$,'Delhi · Jaipur'),
  ('delhi-agra-jaipur-amritsar-wagah-border',3,'Fatehpur Sikri and Taj Mahal',$day$7:30 AM — Breakfast.
8:00 AM — Checkout; depart Jaipur for Agra.
12:00 noon — Fatehpur Sikri, Akbar-era red sandstone Mughal heritage site.
1:30 PM — Lunch.
3:00 PM — Taj Mahal, UNESCO white-marble mausoleum; visit until sunset.
7:00 PM — Shopping near Taj Mahal.
8:30 PM — Hotel check-in.
9:00 PM — Dinner; overnight.$day$,'Jaipur · Fatehpur Sikri · Agra'),
  ('delhi-agra-jaipur-amritsar-wagah-border',4,'Agra, Mathura and Akshardham',$day$7:00 AM — Breakfast.
7:30 AM — Checkout.
8:00 AM — Agra Fort; approximately one hour.
9:30 AM — Leave toward Mathura; approximately two hours.
11:30 AM — Mathura Temple, associated with Krishna’s birthplace; approximately one hour.
1:00 PM — Lunch; depart for Delhi.
4:30 PM — Akshardham Temple; evening light/water/sound show subject to schedule; client schedules the visit until 8:30 PM.
10:00 PM — Delhi hotel check-in.
10:30 PM — Dinner; overnight.$day$,'Agra · Mathura · Delhi'),
  ('delhi-agra-jaipur-amritsar-wagah-border',5,'Delhi sightseeing',$day$7:30 AM — Breakfast.
8:00 AM — Depart hotel.
9:00 AM — Qutub Minar.
10:30 AM — Lotus Temple.
12:00 noon — Teen Murti Bhavan, Nehru-associated historic museum/residence; not presented as the current Prime Minister’s residence.
1:00 PM — Lunch.
2:00 PM — Birla House/Gandhi Smriti.
3:00 PM — Indira Gandhi Museum.
4:00 PM — Raj Ghat and memorial area.
5:30 PM — Old/New Parliament House and Rashtrapati Bhavan, outside only.
6:00 PM — India Gate and ceremonial road.
8:30 PM — Return hotel.
9:00 PM — Dinner; overnight.$day$,'Delhi'),
  ('delhi-agra-jaipur-amritsar-wagah-border',6,'South Delhi and train to Amritsar',$day$7:30 AM — Breakfast.
8:00 AM — Checkout.
9:00 AM — Humayun’s Tomb.
11:00 AM — Red Fort.
1:00 PM — Lunch.
3:00 PM — Head toward Amritsar.
3:15 PM — Vande Bharat train to Amritsar; client-supplied time, actual train schedule requires verification.
8:30 PM — Arrive Amritsar.
9:00 PM — Hotel check-in.
9:30 PM — Dinner; overnight.$day$,'Delhi · Amritsar'),
  ('delhi-agra-jaipur-amritsar-wagah-border',7,'Amritsar and Wagah',$day$7:30 AM — Breakfast.
8:00 AM — Golden Temple; approximately 2–4 hours depending on queue.
11:00 AM — Jallianwala Bagh memorial; approximately one hour. Historical casualty numbers are not presented without verification.
1:00 PM — Lunch.
2:00 PM — Depart toward Attari–Wagah Border.
4:00 PM — Border venue.
5:30 PM — Flag-lowering / Beating Retreat ceremony; approximately one hour, with timing and access subject to authorities and season.
7:00 PM — Return toward Amritsar.
8:30 PM — Dinner and shopping.
10:30 PM — Overnight AC Volvo semi-sleeper bus to Delhi.$day$,'Amritsar · Attari–Wagah Border'),
  ('delhi-agra-jaipur-amritsar-wagah-border',8,'Delhi departure',$day$6:00 AM — Arrive Delhi.
7:30 AM — Hotel check-in for freshening up.
9:00 AM — Breakfast.
9:30 AM — Checkout with luggage.
10:30 AM — Sarojini Market shopping; approximately three hours.
1:30 PM — Lunch.
2:00 PM — Delhi Airport drop, terminal according to flight.$day$,'Delhi')
    ) v(slug,day_number,title,description,location)
  loop
    select d.title,d.description,d.location
    into existing_row
    from public.tour_itinerary_days d
    join public.tour_packages p on p.id=d.package_id
    where p.slug=source.slug and d.day_number=source.day_number;

    if found and (existing_row.title is distinct from source.title
      or existing_row.description is distinct from source.description
      or existing_row.location is distinct from source.location) then
      raise exception 'Existing itinerary content differs from the reviewed client source. Export/review before replacement: % day %', source.slug,source.day_number;
    end if;

    insert into public.tour_itinerary_days(package_id,day_number,title,description,location)
    select p.id,source.day_number,source.title,source.description,source.location
    from public.tour_packages p where p.slug=source.slug
    on conflict(package_id,day_number) do nothing;
  end loop;
end
$client_tour_itinerary$;


-- Enforce the CMS booking safety switch in the server-authoritative path.
-- Prerequisite: 202610150001_client_changes_1_6.sql adds booking_enabled.


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



-- CR7 catalogue/category/media corrections.
-- Forward-only, idempotent and update-only: no package, booking, payment,
-- enquiry or itinerary rows are inserted, removed or replaced.
--
-- Verified image sources (free under the Unsplash License):
-- Agumbe, Karnataka: https://unsplash.com/photos/yOj9j2Ho-kE
-- Ajanta Caves, Maharashtra: https://unsplash.com/photos/ZP039_CRf3M
-- Andaman and Nicobar Islands: https://unsplash.com/photos/YZh8je9IYfc


update public.destinations
set primary_category='international',updated_at=now()
where slug in ('bali','bali-nusa-penida')
  and primary_category is distinct from 'international';

update public.tour_packages p
set category='international',updated_at=now()
where (p.slug in ('bali','bali-nusa-penida','bali-island-escape')
    or p.destination_id in (
      select d.id from public.destinations d where d.slug in ('bali','bali-nusa-penida')
    ))
  and p.category is distinct from 'international';

-- Each affected destination receives its own verified photograph. Existing
-- records are updated in place; absent records are deliberately not invented.
update public.destinations
set hero_image=case slug
  when 'agumbe' then 'https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85'
  when 'ajanta-ellora' then 'https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85'
  when 'andaman' then 'https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85'
end,
updated_at=now()
where slug in ('agumbe','ajanta-ellora','andaman');

update public.tour_packages
set hero_image=case slug
  when 'agumbe' then 'https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85'
  when 'ajanta-ellora' then 'https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85'
  when 'andaman' then 'https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85'
end,
updated_at=now()
where slug in ('agumbe','ajanta-ellora','andaman');

update public.tour_packages p
set hero_image=case d.slug
  when 'agumbe' then 'https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85'
  when 'ajanta-ellora' then 'https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85'
  when 'andaman' then 'https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85'
end,
updated_at=now()
from public.destinations d
where p.destination_id=d.id
  and d.slug in ('agumbe','ajanta-ellora','andaman');

-- The supplied flower photograph is Tulip Garden, Kashmir. Correct only rows
-- that still combine an Agumbe label with a tulip media URL; genuine Agumbe
-- rows remain separately named Agumbe and use the image set above.
update public.gallery_items
set title='Tulip Garden',
    alt_text='Rows of colourful tulips at Tulip Garden in Kashmir',
    updated_at=now()
where media_type='image'
  and media_url ilike '%tulip%'
  and (title ilike '%agumbe%' or alt_text ilike '%agumbe%');



-- Client change requests 8-12: five complete, distinct tour records.
-- Prerequisites: all migrations through 202610180002_cr7_catalogue_corrections.sql.
-- Forward-only, idempotent and non-destructive. Existing bookings, payments,
-- leads, media and unrelated CMS content are not deleted or reassigned.


-- Each package source row is local to this single statement. Existing IDs are
-- retained, reviewed placeholders may be filled, and later Admin content aborts.
do $client_cr8_12_packages$
declare
  source record;
  existing_row public.tour_packages%rowtype;
  destination_id_value uuid;
  destination_image text;
  is_placeholder boolean;
begin
  for source in
    select * from (values
(
  'delhi-agra-amritsar-tour',
  'Delhi–Agra–Amritsar Tour',null,null,5,4,
  'A 5-day/4-night Delhi, Agra and Amritsar tour with Vande Bharat travel to Amritsar and an overnight AC Volvo return to Delhi.',
  'Client-supplied Delhi, Agra and Amritsar itinerary covering Akshardham, Agra Fort, Taj Mahal, Delhi monuments, Golden Temple, Jallianwala Bagh, Attari–Wagah Border and Sarojini Market.',
  $json$["Delhi","Agra","Amritsar"]$json$::jsonb,
  $json$["3 days accommodation at three-star-category hotels; one bedroom for one family / two sharing.","5 breakfasts, 5 lunches and 4 dinners (vegetarian and non-vegetarian).","AC pushback-seat 27-seater bus for sightseeing.","Vande Bharat train tickets to Amritsar.","AC Volvo semi-sleeper tickets from Amritsar to Delhi.","All entry tickets worth around ₹2,000 per person (client-stated amount).","Malayali tour manager and tour guide.","All taxes, tolls and parking charges.","Two mineral-water bottles per day per person.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets from Kerala to Delhi and return.","Meals other than those mentioned in the inclusions.","Camera tickets or other additional charges.","Loss caused by flight or train cancellation or delay.","Loss caused by natural calamities, hartals, strikes or bandhs.","Medical expenses, if any."]$json$::jsonb,
  $note$Age exactly 3 is not priced in the source. The source states 3 days of hotel accommodation within a 5-day/4-night tour and uses a hotel for freshening up on Day 5; the precise room/night allocation requires confirmation. The client-supplied 3:15 PM Vande Bharat timing, attraction access, ticket values and transport schedules require operational verification. No package image was supplied. Keep unpublished and booking-disabled until reviewed.$note$,
  2450000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2450000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":1100000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1800000}]$json$::jsonb,
  'percentage',50
),
(
  'rajasthan',
  'Rajasthan Tour','rajasthan','Rajasthan',7,6,
  'A 7-day/6-night Udaipur-to-Jaipur land package through Jodhpur, Jaisalmer, Pushkar and Ajmer.',
  'Client-supplied Rajasthan land itinerary with Udaipur pickup and Jaipur drop, including a Sam Sand Dunes desert-tent stay.',
  $json$["Udaipur","Jodhpur","Jaisalmer","Ajmer","Pushkar","Jaipur"]$json$::jsonb,
  $json$["Three-star hotel stay for 6 days, two-sharing basis.","AC pushback-seat Urbania / bus for sightseeing.","All meals.","All entry tickets worth around ₹5,000+ (client-stated amount).","Tour manager and guide.","Two mineral-water bottles per day per person.","All taxes, tolls and parking charges.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets to reach Rajasthan and return.","Anything not included in the package inclusions.","Unexpected expenses caused by strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses, etc."]$json$::jsonb,
  $note$Package price, age-wise prices and booking advance were not supplied; show Enquire for Price and do not enable checkout. The source calls this a 7-day/6-night tour but describes the hotel inclusion as “6 days”; confirm the exact hotel-night allocation. Early Udaipur check-in is subject to room availability. The source does not specify individual sightseeing times for several grouped stops. No package image was supplied; retain existing CMS media.$note$,
  null,$json$[]$json$::jsonb,'percentage',0
),
(
  'kashmir-kargil-dhooth-pathri-tour',
  'Kashmir–Kargil–Dhooth Pathri Tour','kashmir-kargil',null,6,5,
  'A June–November Kashmir, Kargil and Dhooth Pathri tour supplied as 6 days/5 nights but containing Day 1–7 with Day 4 missing.',
  'Client-supplied seasonal itinerary covering Srinagar, Sonmarg, Drass, Kargil LOC, Pahalgam, Gulmarg and Dhooth Pathri, subject to route, weather and access conditions.',
  $json$["Srinagar","Gulmarg","Pahalgam","Sonmarg","Drass","Zero Point","Kargil War Memorial","Kargil LOC","Dhooth Pathri"]$json$::jsonb,
  $json$["Delhi–Srinagar return economy-class flight tickets.","Three-star-category hotel accommodation for 4 days: one day at Kargil and three days at Srinagar; one bedroom for one family / two sharing; breakfast and dinner at hotel.","AC bus for sightseeing.","All entry tickets, including Gondola Cable Car Phase 1 worth around ₹1,000 per person (client-stated amount).","All meals: vegetarian breakfast, vegetarian lunch, and vegetarian and non-vegetarian dinner.","Two mineral-water bottles per day per person.","Local union taxi charges at Pahalgam, Sonmarg and Kargil.","Srinagar Airport pickup and drop.","All taxes, tolls and parking fees.","Malayali tour guide and manager."]$json$::jsonb,
  $json$["Additional expenses not included in the package inclusions.","Gondola Cable Car Phase 2 ticket charges.","Expenses caused by natural calamities, strikes or bandhs.","Expenses caused by flight cancellation or delay.","Food on the flight or at airports.","Transportation to Delhi Airport and from the airport."]$json$::jsonb,
  $note$Schedule subject to confirmation: the heading says 6 Days / 5 Nights, the source contains Day 1, 2, 3, 5, 6 and 7, and Day 4 is absent. Do not invent Day 4. Age exactly 3 and the booking advance are not supplied. The source states June–November only and says the Kargil route is closed from the last week of November to May; all route and access claims require operational verification. Hotel inclusion says 4 days and requires reconciliation with the advertised duration. The source document footer names another agency; content rights and attribution must be confirmed before publication. No package image was supplied. Keep unpublished and booking-disabled.$note$,
  2600000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2600000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":600000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1600000}]$json$::jsonb,
  'percentage',0
),
(
  'delhi-kullu-manali-tour',
  'Delhi–Kulu–Manali Tour','kullu-manali-kasol',null,4,3,
  'A 4-day/3-night Delhi, Kulu and Manali tour with Atal Tunnel, Rohtang Pass when permitted, Solang Valley and overnight bus travel.',
  'Client-supplied Delhi, Kulu and Manali itinerary covering Delhi sightseeing, Manali local sightseeing, Solang Valley and Kulu.',
  $json$["Delhi","Kulu","Manali","Atal Tunnel","Rohtang Pass"]$json$::jsonb,
  $json$["Three-star hotel stay for 2 days, two-sharing basis.","AC pushback-seat Urbania / bus for sightseeing.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","All taxes, tolls and parking charges.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets to reach Delhi.","Anything not included in the package inclusions.","Unexpected expenses caused by strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses, etc."]$json$::jsonb,
  $note$Age exactly 3 and the booking advance are not supplied. The source advertises 4 Days / 3 Nights, includes overnight bus travel after Day 4 and expects Delhi arrival around 5:00 AM on the following day; confirm how this is presented commercially. The hotel inclusion says 2 days and requires confirmation. Rohtang Pass is conditional on permission/opening. The source lists optional adventure activities but does not state whether their charges are included. No package image was supplied. Keep unpublished and booking-disabled.$note$,
  2200000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2200000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":600000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1700000}]$json$::jsonb,
  'percentage',0
),
(
  'kullu-manali-kasol',
  'Delhi–Kulu–Manali & Kasol Tour','kullu-manali-kasol','Kullu - Manali - Kasol',5,4,
  'A 5-day/4-night Delhi, Kulu, Manali and Kasol tour with Atal Tunnel, Rohtang Pass when permitted, Solang Valley and overnight bus travel.',
  'Client-supplied Delhi, Kulu, Manali and Kasol itinerary covering Delhi sightseeing, Manali, Solang Valley, Kasol, Manikaran and Kulu.',
  $json$["Delhi","Kulu","Manali","Atal Tunnel","Rohtang Pass","Kasol"]$json$::jsonb,
  $json$["Three-star hotel stay for 3 days, two-sharing basis.","AC pushback-seat Urbania / bus for sightseeing.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","All taxes, tolls and parking charges.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets to reach Delhi.","Anything not included in the package inclusions.","Unexpected expenses caused by strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses, etc."]$json$::jsonb,
  $note$Age exactly 3 and the booking advance are not supplied. The age 4–6 condition says “seat in bus. Without bus”; preserve this wording and obtain client clarification before any automated charge. The source advertises 5 Days / 4 Nights, includes overnight bus travel after Day 5 and expects Delhi arrival around 5:00 AM on the following day; confirm the commercial duration. The hotel inclusion says 3 days and requires confirmation. Rohtang Pass is conditional on permission/opening. The source lists optional adventure activities but does not state whether their charges are included. No new package image was supplied; retain existing CMS media. Keep unpublished and booking-disabled.$note$,
  2900000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2900000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – ‘seat in bus. Without bus’ (client wording; clarification required)","min_age":4,"max_age":6,"price":700000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":2100000}]$json$::jsonb,
  'percentage',0
)
    ) v(slug,title,destination_slug,placeholder_title,duration_days,duration_nights,summary,description,highlights,inclusions,exclusions,important_information,base_price,age_pricing,advance_type,advance_value)
  loop
    select * into existing_row from public.tour_packages where slug=source.slug;
    if found then
      is_placeholder := source.placeholder_title is not null
        and existing_row.title=source.placeholder_title
        and existing_row.summary='Details coming soon. Contact My Tripon Travel to register your interest.'
        and existing_row.base_price is null
        and existing_row.age_pricing='[]'::jsonb
        and not exists(select 1 from public.tour_itinerary_days d where d.package_id=existing_row.id);

      if not is_placeholder and not (
        existing_row.title=source.title
        and existing_row.duration_days=source.duration_days
        and existing_row.duration_nights=source.duration_nights
        and existing_row.summary=source.summary
        and existing_row.description=source.description
        and existing_row.highlights=source.highlights
        and existing_row.inclusions=source.inclusions
        and existing_row.exclusions=source.exclusions
        and existing_row.important_information=source.important_information
        and existing_row.base_price is not distinct from source.base_price
        and existing_row.age_pricing=source.age_pricing
        and existing_row.advance_type=source.advance_type
        and existing_row.advance_value=source.advance_value
        and existing_row.booking_enabled=false
        and existing_row.published=false
      ) then
        raise exception 'CR8-CR12 package row contains non-placeholder/Admin content. Export and review before replacement: %',source.slug;
      end if;
    end if;

    select d.id,d.hero_image into destination_id_value,destination_image
    from public.destinations d where d.slug=source.destination_slug;

    insert into public.tour_packages(
      slug,title,destination_id,category,duration_days,duration_nights,summary,overview,description,
      hero_image,trip_style,highlights,inclusions,exclusions,important_information,base_price,
      child_price,infant_price,age_pricing,advance_type,advance_value,currency,is_upcoming,
      booking_enabled,published,published_at
    ) values (
      source.slug,source.title,destination_id_value,'domestic'::public.package_category,
      source.duration_days,source.duration_nights,source.summary,source.description,source.description,
      destination_image,'Guided domestic group tour',source.highlights,source.inclusions,source.exclusions,
      source.important_information,source.base_price,null,null,source.age_pricing,source.advance_type,
      source.advance_value,'INR',false,false,false,null
    )
    on conflict(slug) do update set
      title=excluded.title,
      destination_id=coalesce(excluded.destination_id,public.tour_packages.destination_id),
      category=excluded.category,
      duration_days=excluded.duration_days,
      duration_nights=excluded.duration_nights,
      summary=excluded.summary,overview=excluded.overview,description=excluded.description,
      hero_image=coalesce(public.tour_packages.hero_image,excluded.hero_image),
      trip_style=excluded.trip_style,highlights=excluded.highlights,inclusions=excluded.inclusions,
      exclusions=excluded.exclusions,important_information=excluded.important_information,
      base_price=excluded.base_price,child_price=null,infant_price=null,age_pricing=excluded.age_pricing,
      advance_type=excluded.advance_type,advance_value=excluded.advance_value,currency='INR',
      is_upcoming=false,booking_enabled=false,published=false,published_at=null,updated_at=now();
  end loop;
end
$client_cr8_12_packages$;

-- Prevent the earlier generic Rajasthan seed from appearing as a second offer.
-- Its content remains recoverable and is not deleted.
update public.tour_packages
set booking_enabled=false,published=false,published_at=null,updated_at=now()
where slug='rajasthan-heritage';

-- The full CR8-CR12 itinerary is consumed inside one statement. No source
-- relation survives or is required beyond this statement boundary.
do $client_cr8_12_itinerary$
declare
  source record;
  existing_row record;
  extras text;
begin
  select string_agg(p.slug || ': day ' || d.day_number::text, ', ' order by p.slug,d.day_number)
  into extras
  from public.tour_itinerary_days d
  join public.tour_packages p on p.id=d.package_id
  where (p.slug='delhi-agra-amritsar-tour' and d.day_number<>all(array[1,2,3,4,5]))
     or (p.slug='rajasthan' and d.day_number<>all(array[1,2,3,4,5,6,7]))
     or (p.slug='kashmir-kargil-dhooth-pathri-tour' and d.day_number<>all(array[1,2,3,5,6,7]))
     or (p.slug='delhi-kullu-manali-tour' and d.day_number<>all(array[1,2,3,4]))
     or (p.slug='kullu-manali-kasol' and d.day_number<>all(array[1,2,3,4,5]));

  if extras is not null then
    raise exception 'Unexpected CR8-CR12 itinerary rows require manual review; no rows were deleted: %',extras;
  end if;

  for source in
    select * from (values
('delhi-agra-amritsar-tour',1,'Delhi, Akshardham and Agra',$day$6:00 AM — Start from Delhi.
8:00 AM — Akshardham Temple. Swaminarayan Akshardham in Delhi is a newly constructed divine centre famous for its stunning architectural wonder. Spend one hour here.
12:30 PM — Lunch in Agra.
1:30 PM — Agra Fort. It was built by Mughal emperors, and the present construction of the fort was renovated in Akbar’s period. It is similar to the Red Fort in Delhi, so it is also called “Agra’s Red Fort”. Spend one hour at Agra Fort.
3:30 PM — Taj Mahal. The Taj Mahal is one of the Seven Wonders of the World and one of India’s UNESCO World Heritage properties. “The Taj” is described as a legend of an emperor’s eternal love for his favourite queen. Mughal emperor Shah Jahan built it for his favourite wife, Mumtaz Mahal. It was constructed from 1631 to 1653 and is an ivory-white marble mausoleum on the bank of the Yamuna River. The tombs of Shah Jahan and Mumtaz Mahal are at the Taj Mahal. The best time to visit is early morning or evening. Stay until sunset.
7:00 PM — Depart toward Delhi.
9:00 PM — Dinner on the way.
11:30 PM — Check in at the Delhi hotel; overnight stay.$day$,'Delhi · Agra'),
('delhi-agra-amritsar-tour',2,'Delhi sightseeing',$day$7:30 AM — Breakfast.
8:00 AM — Leave the hotel for sightseeing.
9:00 AM — Qutub Minar. Qutub Minar was built from 1199 to 1220 as a victory tower. Qutb-ud-din Aibak started its construction in 1199 after the victory against Prithviraj Chauhan, and his successor Iltutmish completed it. It is one of India’s UNESCO World Heritage properties and a pride of Delhi.
10:30 AM — Lotus Temple.
12:00 noon — Teen Murti Bhavan. The source says it is now known as the Prime Minister’s Home and was the Nehru family’s house. Visitors can see rooms used by Jawaharlal Nehru from childhood onward. It was a place where many national leaders and British rulers held meetings.
1:00 PM — Lunch.
2:00 PM — Birla House. It is the place where Mahatma Gandhi was shot. Visit Gandhi’s ashram, where he spent his last days.
3:00 PM — Indira Gandhi Museum. It is a museum at the house in front of which Indira Gandhi was shot.
4:00 PM — Raj Ghat / Samadhi Sthal. Raj Ghat is Mahatma Gandhi’s memorial. Visit the memorials of Jawaharlal Nehru, Indira Gandhi, Rajiv Gandhi, Lal Bahadur Shastri and Atal Bihari Vajpayee, among others.
5:30 PM — Outside view of the new and old Parliament buildings and Rashtrapati Bhavan.
6:00 PM — India Gate. Formerly known as the All India War Memorial, it is a 42-metre-high war memorial in New Delhi designed by Sir Edwin Lutyens. It honours more than 70,000 Indian and British soldiers who died in the World War. Spend the evening at India Gate and travel along the roads where the Independence Day and Republic Day parades are held.
8:30 PM — Reach the hotel.
9:00 PM — Dinner; overnight stay.$day$,'Delhi'),
('delhi-agra-amritsar-tour',3,'South Delhi and train to Amritsar',$day$7:30 AM — Breakfast.
8:00 AM — Check out from the hotel.
9:00 AM — Humayun’s Tomb. It is listed among India’s UNESCO World Heritage properties. It is a mausoleum commissioned in 1558 by Empress Bega Begum.
11:00 AM — Red Fort. It is a historic Mughal fort in Old Delhi and was the main residence of Mughal emperors. Shah Jahan commissioned it in 1639. On 15 August 1947, India’s first Prime Minister, Jawaharlal Nehru, hoisted the Indian flag at the main entrance. Since then, every Prime Minister of India has ceremonially raised the national flag at the main gate on Independence Day.
1:00 PM — Lunch.
3:00 PM — Head toward Amritsar.
3:15 PM — Vande Bharat train to Amritsar (client-supplied time; verify the operating schedule).
8:30 PM — Reach Amritsar.
9:00 PM — Hotel check-in.
9:30 PM — Dinner; overnight stay.$day$,'Delhi · Amritsar'),
('delhi-agra-amritsar-tour',4,'Amritsar and Attari–Wagah Border',$day$7:30 AM — Breakfast.
8:00 AM — Golden Temple. It is a famous gurudwara in Amritsar and spiritually the most significant shrine in Sikhism. Spend at least two hours here; it may take up to four hours depending on the queue to enter.
11:00 AM — Jallianwala Bagh. Also associated with the “Amritsar Massacre”, it took place on 13 April 1919. People gathered there to protest against the Rowlatt Act, after which General Dyer surrounded them and fired. Jallianwala Bagh had only one exit, with buildings surrounding all other sides. The source states that more than 1,500 Indian freedom fighters were killed and more than 1,200 were seriously injured; these figures require editorial verification. It was a shocking incident in the history of India’s freedom struggle. Spend one hour at Jallianwala Bagh.
1:00 PM — Lunch.
2:00 PM — Depart toward Attari–Wagah Border.
4:00 PM — Attari–Wagah Border. The source describes Attari as the only official road crossing between India and Pakistan and as world-famous for its daily Beating Retreat flag-lowering ceremony.
5:30 PM — Flag-lowering ceremony at Wagah Border. Witness a one-hour display of military precision, patriotism and rivalry jointly performed by the Indian Border Security Force (BSF) and the Pakistan Rangers. The border gate then remains closed for the day.
7:00 PM — Return to Amritsar.
8:30 PM — Dinner and shopping time.
10:30 PM — AC Volvo semi-sleeper bus to Delhi; overnight on the bus.$day$,'Amritsar · Attari–Wagah Border'),
('delhi-agra-amritsar-tour',5,'Delhi departure',$day$6:00 AM — Reach Delhi.
7:30 AM — Hotel check-in for freshening up.
9:00 AM — Breakfast.
9:30 AM — Check out with all luggage.
10:30 AM — Shopping at Sarojini Market; allow three hours.
1:30 PM — Lunch.
2:00 PM — Drop at Delhi Airport Terminal 1, 2 or 3 depending on the flight.$day$,'Delhi'),

('rajasthan',1,'Udaipur arrival and sightseeing',$day$Arrive in Udaipur by flight, train or bus; select a service reaching on or before 10:00 AM.
Pickup from the airport, railway station or bus stand.
Hotel check-in and freshening up; early check-in is subject to room availability.
Udaipur sightseeing: City Palace, Lake Pichola, Jagmandir Palace, Saheliyon Ki Bari, Fateh Sagar Lake, Shilpagram and Maharana Pratap Smarak.
7:00 PM — Shopping at the local market.
9:00 PM — Dinner; overnight at the hotel.$day$,'Udaipur'),
('rajasthan',2,'Udaipur to Jodhpur',$day$7:00 AM — Breakfast.
7:30 AM — Hotel checkout and depart toward Jodhpur.
The client estimates four to five hours for the journey.
12:30 PM — Expected arrival in Jodhpur and hotel check-in.
1:00 PM — Lunch.
2:00 PM — Jodhpur local sightseeing: Umaid Bhawan Palace and Museum, Mehrangarh Fort, Jaswant Thada and Sardar Market.
8:30 PM — Dinner; overnight at the Jodhpur hotel.$day$,'Udaipur · Jodhpur'),
('rajasthan',3,'Jodhpur to Jaisalmer and Sam Sand Dunes',$day$7:00 AM — Breakfast.
7:30 AM — Hotel checkout and depart toward Jaisalmer.
The client estimates five to six hours for the journey.
Visit Jaisalmer War Museum, located 10 km before Jaisalmer on the Jodhpur–Jaisalmer National Highway, and Gadisar Lake.
2:00 PM — Lunch.
3:00 PM — Jaisalmer / Thar Desert. Camel ride on Sam Sand Dunes and sunset view in the Thar Desert.
Check in at a desert tent at Sam Sand Dunes.
8:00 PM — Dinner; overnight in the tent.$day$,'Jodhpur · Jaisalmer · Sam Sand Dunes'),
('rajasthan',4,'Jaisalmer sightseeing and Pushkar transfer',$day$8:00 AM — Breakfast.
8:30 AM — Check out from the tent stay.
Jaisalmer sightseeing: Jaisalmer Fort, Patwon Ki Haveli and Sonar Kella.
1:00 PM — Lunch.
Visit Nathmal Ki Haveli and Salim Singh Ki Haveli.
Evening departure toward Pushkar; the client estimates five to six hours.
11:00 PM — Hotel check-in; overnight stay.$day$,'Jaisalmer · Pushkar'),
('rajasthan',5,'Pushkar, Ajmer and Jaipur',$day$8:00 AM — Breakfast.
Pushkar sightseeing: Brahma Temple and Brahma Sarovar Lake.
1:00 PM — Lunch.
Afternoon — Ajmer Dargah.
Evening — Depart toward Jaipur and shop in Jaipur.
8:00 PM — Dinner; overnight in Jaipur.$day$,'Pushkar · Ajmer · Jaipur'),
('rajasthan',6,'Jaipur sightseeing',$day$7:30 AM — Breakfast.
Jaipur sightseeing: Jantar Mantar, Hawa Mahal, Albert Hall and Museum, Birla Mandir and city tour.
Shopping at Johari Bazaar.
9:00 PM — Dinner; overnight at the Jaipur hotel.$day$,'Jaipur'),
('rajasthan',7,'Jaipur sightseeing and departure',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout.
Jaipur local sightseeing: Amber Fort (Amar Fort), Panna Meena Kund and Water Palace (Jal Mahal).
2:00 PM — Lunch.
Visit City Palace.
4:30 PM — Drop at Jaipur Airport, railway station or bus stand.$day$,'Jaipur'),

('kashmir-kargil-dhooth-pathri-tour',1,'Srinagar, Sonmarg, Drass and Kargil',$day$9:00 AM — Meet and greet at Srinagar Airport; the tour manager joins the group. Freshening up and breakfast.
11:45 AM — Depart directly for Sonmarg.
1:00 PM — River Sindhu.
2:00 PM — Lunch.
3:00 PM — Sonmarg Tunnel; spend one hour at Sonmarg.
Then take the thrilling journey through Zojila Pass, described in the source as the world’s third-highest motorable pass. Zojila Pass, Drass, Zero Point and Kargil can be visited only if Zojila Pass is open to tourists. The source says it is currently open but may close because of heavy snowfall, landslides or natural calamities. In that case, return from Sonmarg and stay in Srinagar.
5:00 PM — Captain Mod Point.
6:00 PM — Zero Point. The source describes it as the world’s second-coldest place after Siberia; verify this claim before publication. Spend 30 minutes at Zero Point.
7:00 PM — Drass.
8:30 PM — Reach Kargil.
9:00 PM — Dinner; overnight in Kargil.$day$,'Srinagar · Sonmarg · Zojila Pass · Zero Point · Drass · Kargil'),
('kashmir-kargil-dhooth-pathri-tour',2,'Kargil LOC, Hunterman and Srinagar',$day$7:30 AM — Breakfast.
8:00 AM — Depart toward the Kargil India–Pakistan border / LOC. The tour vehicle is not permitted; use locally hired permitted cars from Kargil.
9:00 AM — Shivaji Temple.
10:00 AM — Kargil LOC. Visit the last picket point of the Indian military. The source says visitors can see a village and picket point on the Pakistan side. Spend one hour at the LOC.
11:30 AM — Hunterman Village, described in the source as the last Indian village on the border.
12:30 PM — Reach the hotel, then lunch.
1:00 PM — Hotel checkout and depart toward Srinagar.
2:00 PM — Kargil War Memorial. Spend 30 minutes at the memorial and visit the museum and documentary relating to the Kargil War. After honouring the soldiers, return.
6:00 PM — Shikara ride on Dal Lake. Srinagar city is surrounded by Dal Lake. Enjoy a one-hour ride through the lake, exploring the houseboats, floating market and village.
7:30 PM — Shopping at Dal Lake.
9:00 PM — Hotel check-in.
9:30 PM — Dinner; overnight stay.$day$,'Kargil · Hunterman · Kargil War Memorial · Srinagar'),
('kashmir-kargil-dhooth-pathri-tour',3,'Pahalgam, Chandanwadi and Betaab Valley',$day$7:30 AM — Breakfast.
8:00 AM — Depart toward Pahalgam.
9:00 AM — Saffron paddy at Pampore.
9:30 AM — Pulwama terrorist-attack point.
10:00 AM — Cricket-bat factory.
11:30 AM — Apple farms at Pahalgam. Take photographs and pluck fresh apples from the trees to purchase. The source describes apples from Pahalgam, Kashmir as very tasty and good quality.
1:00 PM — Lunch.
2:30 PM — Depart toward Chandanwadi and Betaab Valley. The tour vehicles are not permitted at these places, so hire local cars from the taxi stand. Taxi charges are included in the package. The source describes this as a two-hour journey, with 30 minutes at each place.
3:30 PM — Chandanwadi.
4:30 PM — Betaab Valley.
5:30 PM — Mini Switzerland / Baisaran Valley (source wording: “Byson Valley”).
7:00 PM — Return to Srinagar.
9:30 PM — Reach the hotel.
10:00 PM — Dinner; overnight stay.$day$,'Pampore · Pahalgam · Chandanwadi · Betaab Valley · Baisaran Valley · Srinagar'),
('kashmir-kargil-dhooth-pathri-tour',5,'Gulmarg and Hazratbal',$day$7:30 AM — Breakfast.
8:00 AM — Depart toward Gulmarg.
9:00 AM — Nishat Gardens. Spend 30 minutes here. Travellers can take photographs in traditional Kashmiri dress.
11:30 AM — Tangmarg and lunch.
2:00 PM — Gondola Cable Car at Gulmarg. The source describes the Gondola as a great experience and Asia’s highest cable-car service. It has two phases. Phase 1, Gulmarg to Kongdori, has an entry ticket stated as worth around ₹1,000 and is included in the package. A Phase 2 ticket from Kongdori to Apharwat is stated as available for ₹1,200 per person extra. Verify current prices, route names and operation. Explore Gulmarg for two to three hours.
5:30 PM — Return to Srinagar.
7:00 PM — Hazratbal Mosque. The source describes it as a very old mosque where a hair of Prophet Muhammad is kept. It says women should cover their heads when entering the mosque. Verify this wording before publication.
8:00 PM — Campfire.
9:00 PM — Dinner; overnight stay.$day$,'Srinagar · Nishat Gardens · Tangmarg · Gulmarg · Hazratbal'),
('kashmir-kargil-dhooth-pathri-tour',6,'Shankaracharya Temple and Dhooth Pathri',$day$8:00 AM — Breakfast.
9:00 AM — Sree Shankaracharya Hills and Temple. The source describes it as one of the four maths created by Shankaracharya. It describes the panoramic view from the hilltop as amazing, with the entire view of Dal Lake and Srinagar. Spend one hour here.
1:00 PM — Lunch.
2:00 PM — Dhooth Pathri. The source describes it as one of the main tourist places near Srinagar, with mind-blowing green mountains and landscapes. Visit the huts of local people and stay until evening.
6:00 PM — Return to Srinagar.
7:00 PM — Shopping at Lal Chowk.
10:00 PM — Dinner; overnight stay.$day$,'Srinagar · Shankaracharya Temple · Dhooth Pathri · Lal Chowk'),
('kashmir-kargil-dhooth-pathri-tour',7,'Shalimar Gardens and departure',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout.
9:00 AM — Shalimar Gardens. It is described as one of Kashmir’s famous gardens built by the Mughal Empire and by the Mughal emperor Jahangir. The source says Kashmir was the Mughal Empire’s summer capital. Spend 30 minutes at Shalimar Gardens.
11:30 AM — Depart toward Srinagar Airport.
12:30 PM — Reach and check in at Srinagar Airport.
2:40 PM — Flight to Delhi (client-supplied time; verify schedule).
4:20 PM — Reach Delhi Airport (client-supplied time; verify schedule).$day$,'Srinagar · Delhi'),

('delhi-kullu-manali-tour',1,'Delhi sightseeing and overnight bus to Manali',$day$8:00 AM — India Gate. Formerly known as the All India War Memorial, it is a 42-metre-high war memorial in New Delhi designed by Sir Edwin Lutyens. It honours more than 70,000 Indian and British soldiers who died in the World War. Spend the evening at India Gate and travel along the roads where the Independence Day and Republic Day parades are held.
9:00 AM — Outside view of Parliament House and Rashtrapati Bhavan.
10:00 AM — Indira Gandhi Museum. It is a museum at the house in front of which Indira Gandhi was shot.
11:30 AM — Qutub Minar. Qutub Minar was built from 1199 to 1220 as a victory tower. Qutb-ud-din Aibak started its construction in 1199 after the victory against Prithviraj Chauhan, and his successor Iltutmish completed it. It is one of India’s UNESCO World Heritage properties and a pride of Delhi.
1:00 PM — Lotus Temple.
2:00 PM — Lunch at Raj Ghat.
2:30 PM — Raj Ghat / Samadhi Sthal. Raj Ghat is Mahatma Gandhi’s memorial. Visit the memorials of Jawaharlal Nehru, Indira Gandhi, Rajiv Gandhi, Lal Bahadur Shastri and Atal Bihari Vajpayee, among others.
4:00 PM — Red Fort. It is a historic Mughal fort in Old Delhi and was the main residence of Mughal emperors. Shah Jahan commissioned it in 1639. On 15 August 1947, India’s first Prime Minister, Jawaharlal Nehru, hoisted the Indian flag at the main entrance. Since then, every Prime Minister of India has ceremonially raised the national flag at the main gate on Independence Day.
5:30 PM — Bus toward Manali.
9:00 PM — Dinner on the way at Chandigarh; overnight on the bus.$day$,'Delhi · Chandigarh · Manali'),
('delhi-kullu-manali-tour',2,'Manali local sightseeing',$day$10:00 AM — Expected arrival in Manali and hotel check-in.
10:30 AM — Breakfast and rest at the hotel.
1:00 PM — Lunch.
1:30 PM — Leave for Manali local sightseeing.
2:00 PM — Hadimba Temple. It was built in 1553 with a well-crafted, four-tiered pagoda roof and is famous for its exquisitely carved doorways. Spend 30 minutes here. Travellers can take photographs in Himachal traditional dress.
3:30 PM — Tibetan Monastery.
4:30 PM — Van Vihar and Manu Temple.
6:00 PM — Mall Road. It is an old market in Manali; time for shopping.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali'),
('delhi-kullu-manali-tour',3,'Solang Valley, Atal Tunnel and Rohtang Pass',$day$8:00 AM — Breakfast.
8:30 AM — Leave the hotel for sightseeing.
10:30 AM onward — Atal Tunnel, Nehru Kund, Kothi Village and Rohtang Pass if permitted/open to travellers.
1:30 PM — Lunch.
3:00 PM — Solang Valley. It is a beautiful valley where adventure activities such as paragliding, cable-car ropeway, snow scooter, snow skiing and horse riding may be available. The source does not specify whether these activity charges are included.
5:00 PM — Return to Manali.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali · Atal Tunnel · Nehru Kund · Kothi Village · Rohtang Pass · Solang Valley'),
('delhi-kullu-manali-tour',4,'Kulu sightseeing and overnight bus to Delhi',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout and depart for Kulu sightseeing.
11:00 AM — Kulu. Kulu is famous for river rafting. River rafting, paragliding and other activities may be available; the source does not specify whether their charges are included.
2:00 PM — Lunch.
3:00 PM — Shawl factory visit.
4:00 PM — Return toward Delhi.
9:00 PM — Dinner on the way; overnight on the bus.
Expected arrival in Delhi at 5:00 AM on the following day.$day$,'Manali · Kulu · Delhi'),

('kullu-manali-kasol',1,'Delhi sightseeing and overnight bus to Manali',$day$8:00 AM — India Gate. Formerly known as the All India War Memorial, it is a 42-metre-high war memorial in New Delhi designed by Sir Edwin Lutyens. It honours more than 70,000 Indian and British soldiers who died in the World War. Spend the evening at India Gate and travel along the roads where the Independence Day and Republic Day parades are held.
9:00 AM — Outside view of Parliament House and Rashtrapati Bhavan.
10:00 AM — Indira Gandhi Museum. It is a museum at the house in front of which Indira Gandhi was shot.
11:30 AM — Qutub Minar. Qutub Minar was built from 1199 to 1220 as a victory tower. Qutb-ud-din Aibak started its construction in 1199 after the victory against Prithviraj Chauhan, and his successor Iltutmish completed it. It is one of India’s UNESCO World Heritage properties and a pride of Delhi.
1:00 PM — Lotus Temple.
2:00 PM — Lunch at Raj Ghat.
2:30 PM — Raj Ghat / Samadhi Sthal. Raj Ghat is Mahatma Gandhi’s memorial. Visit the memorials of Jawaharlal Nehru, Indira Gandhi, Rajiv Gandhi, Lal Bahadur Shastri and Atal Bihari Vajpayee, among others.
4:00 PM — Red Fort. It is a historic Mughal fort in Old Delhi and was the main residence of Mughal emperors. Shah Jahan commissioned it in 1639. On 15 August 1947, India’s first Prime Minister, Jawaharlal Nehru, hoisted the Indian flag at the main entrance. Since then, every Prime Minister of India has ceremonially raised the national flag at the main gate on Independence Day.
5:30 PM — Bus toward Manali.
9:00 PM — Dinner on the way at Chandigarh; overnight on the bus.$day$,'Delhi · Chandigarh · Manali'),
('kullu-manali-kasol',2,'Manali local sightseeing',$day$10:00 AM — Expected arrival in Manali and hotel check-in.
10:30 AM — Breakfast and rest at the hotel.
1:00 PM — Lunch.
1:30 PM — Leave for Manali local sightseeing.
2:00 PM — Hadimba Temple. It was built in 1553 with a well-crafted, four-tiered pagoda roof and is famous for its exquisitely carved doorways. Spend 30 minutes here. Travellers can take photographs in Himachal traditional dress.
3:30 PM — Tibetan Monastery.
4:30 PM — Van Vihar and Manu Temple.
6:00 PM — Mall Road. It is an old market in Manali; time for shopping.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali'),
('kullu-manali-kasol',3,'Solang Valley, Atal Tunnel and Rohtang Pass',$day$8:00 AM — Breakfast.
8:30 AM — Leave the hotel for sightseeing.
10:30 AM onward — Atal Tunnel, Nehru Kund, Kothi Village and Rohtang Pass if permitted/open to travellers.
1:30 PM — Lunch.
3:00 PM — Solang Valley. It is a beautiful valley where adventure activities such as paragliding, cable-car ropeway, snow scooter, snow skiing and horse riding may be available. The source does not specify whether these activity charges are included.
5:00 PM — Return to Manali.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali · Atal Tunnel · Nehru Kund · Kothi Village · Rohtang Pass · Solang Valley'),
('kullu-manali-kasol',4,'Kasol and Manikaran sightseeing',$day$8:00 AM — Breakfast.
8:30 AM — Leave the hotel for full-day Kasol sightseeing.
Visit Kasol, Manikaran Sahib Gurudwara, Shiv Temple and Kasol Market.
2:00 PM — Lunch.
Return to the Manali hotel.
6:00 PM — Shopping at Mall Road, Manali.
9:00 PM — Dinner; overnight at the hotel.$day$,'Manali · Kasol · Manikaran · Manali'),
('kullu-manali-kasol',5,'Kulu sightseeing and overnight bus to Delhi',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout and depart for Kulu sightseeing.
11:00 AM — Kulu. Kulu is famous for river rafting. River rafting, paragliding and other activities may be available; the source does not specify whether their charges are included.
2:00 PM — Lunch.
3:00 PM — Shawl factory visit.
4:00 PM — Return toward Delhi.
9:00 PM — Dinner on the way; overnight on the bus.
Expected arrival in Delhi at 5:00 AM on the following day.$day$,'Manali · Kulu · Delhi')
    ) v(slug,day_number,title,description,location)
  loop
    select d.title,d.description,d.location
    into existing_row
    from public.tour_itinerary_days d
    join public.tour_packages p on p.id=d.package_id
    where p.slug=source.slug and d.day_number=source.day_number;

    if found and (existing_row.title is distinct from source.title
      or existing_row.description is distinct from source.description
      or existing_row.location is distinct from source.location) then
      raise exception 'CR8-CR12 itinerary row differs from the reviewed client source. Export and review: % day %',source.slug,source.day_number;
    end if;

    insert into public.tour_itinerary_days(package_id,day_number,title,description,location)
    select p.id,source.day_number,source.title,source.description,source.location
    from public.tour_packages p where p.slug=source.slug
    on conflict(package_id,day_number) do nothing;
  end loop;
end
$client_cr8_12_itinerary$;


-- Remove the explicit anonymous EXECUTE grant found by the diagnostic. The
-- function already rejects null auth.uid(), and authenticated/service-role
-- access remains intact.
revoke all on function public.create_booking_secure(text,date,jsonb,text,uuid) from anon;
revoke all on function public.create_booking_secure(text,date,jsonb,text,uuid) from public;
grant execute on function public.create_booking_secure(text,date,jsonb,text,uuid) to authenticated;

insert into public.site_settings(key,value)
values (
  '_migration_reconciliation_cr1_12_20261019',
  jsonb_build_object(
    'public',false,
    'migration','202610190001_production_reconciliation_cr1_12.sql',
    'applied_at',now(),
    'source_package_count',49,
    'expected_package_count',55
  )
)
on conflict(key) do update set value=excluded.value,updated_at=now();

commit;

