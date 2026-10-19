-- Read-only verification for 202610190001_production_reconciliation_cr1_12.sql.
-- Expected result: every object in "checks" has "passed": true.
-- The detail sections are evidence for manual review. No data is modified.

with
original_packages(slug,id) as (
  values
('agumbe','23e82dda-d0a6-41c1-b740-1bbd20a6f08d'::uuid),
    ('ajanta-ellora','852760db-d43a-472d-b991-dc0562a19a05'::uuid),
    ('andaman','9c5dc72f-d131-4759-8ea0-ff2e36689945'::uuid),
    ('ayodhya-kashi-prayagraj-gaya-bodh-gaya','bb85c9df-7298-4c0d-bf50-84365ab13969'::uuid),
    ('azerbaijan','ec942220-bfe5-416e-aff4-7fd633fc5118'::uuid),
    ('bali-island-escape','db4c0ff0-e9c1-4689-b34b-fea29416e34d'::uuid),
    ('bali-nusa-penida','c8fd2a4d-5486-4fb5-947d-d1836387b16d'::uuid),
    ('bangalore-mysore-kodagu','eeced853-8ba6-45aa-9b06-f5a18276da6b'::uuid),
    ('bhutan','77a5dd2f-b4fc-43b1-b6d7-f9b3ad8c5ff7'::uuid),
    ('bijapur-hampi-badami-aihole-pattadakkal-chitradurga','60d26fe2-084a-43c7-80f7-e7c54f1f48d4'::uuid),
    ('chikmagalur','210f3fb8-d39e-4e71-b7a2-3559ee167b39'::uuid),
    ('delhi-agra-jaipur-amritsar-wagah-border','3780c481-ebb9-4736-bc9f-a767db3d8d4c'::uuid),
    ('dubai','72904639-0ab4-4bde-9ab9-243eb5abdafa'::uuid),
    ('goa','b8e76b51-2c13-447e-a2cd-a5571925de6d'::uuid),
    ('gokarna','82a90fa6-074f-4ac7-903d-ed73f1986436'::uuid),
    ('gujarat','a233bf7e-e4d3-4335-989f-7e13256ce393'::uuid),
    ('hampi','40be0082-b381-4712-a8b2-58f17c30ddc9'::uuid),
    ('hyderabad','367c9ef5-0cd5-452d-a71f-3047352bd2c4'::uuid),
    ('indonesia','daaeddbd-bcda-4891-a8bc-9557f89f90ce'::uuid),
    ('jog-falls','b98def49-53df-48bf-b2bb-0da83858e2df'::uuid),
    ('kashmir','ddce302b-b4fc-45c3-82c4-855670ebdaaa'::uuid),
    ('kashmir-at-your-pace','8c2c6ee0-86ab-4502-9ea7-a9a1c4de033d'::uuid),
    ('kashmir-kargil','a61f8f0b-3faf-4926-b17b-48c3be79e793'::uuid),
    ('kasol','f4ff3998-5a2f-4e13-a6e2-787ec3a61f66'::uuid),
    ('kerala-backwaters','c934cc70-c0cd-4134-afd8-66392bd813d0'::uuid),
    ('kerala-full','f2623abf-6056-4d06-90f7-ee2c2e9d7e64'::uuid),
    ('kolkata','21b0a5f0-01c9-471b-b572-a9aecf3c6e13'::uuid),
    ('kullu-manali-kasol','08ccb15e-ff97-4d19-bb25-5f8cff52584a'::uuid),
    ('ladakh','15e52b68-c17c-43d8-a266-463ba7ffb037'::uuid),
    ('lakshadweep','bab6ac6a-2dda-4006-860b-625bf729f3de'::uuid),
    ('malaysia-singapore','ca07c5fb-f172-46b8-81d0-9d0c6b02d0d7'::uuid),
    ('maldives','878c2fcd-2db1-4fe6-85c1-6b357963eaa9'::uuid),
    ('matheran','c09699ab-6b61-48cf-97af-fd28e2c3052b'::uuid),
    ('meghalaya','39033453-9386-4494-b1e1-1ae9eb8ade2b'::uuid),
    ('mumbai','b8ebba0b-f381-4341-9c19-f1c3618241e3'::uuid),
    ('munnar-thekkady-kochi-alappuzha-kumarakom-varkala-kovalam','72234775-0d0e-4ea8-b243-f4371c588f0d'::uuid),
    ('munnar-thekkady-vagamon-kochi-athirappalli','332de1bd-758d-4561-be0c-b6a25e2bf61d'::uuid),
    ('nepal','e1721ba4-ea33-4fea-8acd-1c484b3a15d4'::uuid),
    ('odisha','cdf55d8b-e0df-424a-9717-92d7ba20cad0'::uuid),
    ('ooty-mysore','352779ca-d273-4594-bc50-cdba6f9c893d'::uuid),
    ('rajasthan','217edde4-bfcb-49c7-85b7-67ef7a8bc302'::uuid),
    ('rajasthan-heritage','fe459c48-22f4-4394-950d-49810c5ff1e3'::uuid),
    ('rameswaram-dhanushkodi-madurai-kodaikanal','4d25649c-de1c-4411-ba23-7d76bde777db'::uuid),
    ('sikkim-darjeeling','a97fc57a-f824-4226-b7e0-569b6f6ab0db'::uuid),
    ('sri-lanka','aa1a9282-5102-4115-a3b5-3390fb34af8a'::uuid),
    ('thailand','818c1e70-b3bf-4baf-bd93-34bf4255a64c'::uuid),
    ('vagamon','fbd91344-c43a-48f6-8831-b68c8897d5de'::uuid),
    ('valparai-athirappalli','d99146bc-aeef-4e95-b878-4450a157ccf5'::uuid),
    ('wayanad','f872923c-557e-4a38-a637-c3d45f757486'::uuid)
),
new_packages(slug) as (
  values
    ('delhi-agra-jaipur-golden-triangle-tour'),
    ('delhi-agra-mathura-jaipur-tour'),
    ('delhi-agra-tour'),
    ('delhi-agra-amritsar-tour'),
    ('kashmir-kargil-dhooth-pathri-tour'),
    ('delhi-kullu-manali-tour')
),
expected_policies(schema_name,table_name,policy_name,permissive,roles,command,using_expression,check_expression) as (
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
),
expected_tours(
  slug,days,day_labels,highlights,inclusions,exclusions,price_bands,base_price
) as (
  values
    ('kashmir-kargil',5,array[1,2,3,4,5],8,9,7,4,2100000),
    ('delhi-agra-jaipur-golden-triangle-tour',5,array[1,2,3,4,5],4,3,5,4,2200000),
    ('delhi-agra-mathura-jaipur-tour',6,array[1,2,3,4,5,6],5,8,5,4,2600000),
    ('delhi-agra-tour',3,array[1,2,3],2,8,5,4,1200000),
    ('delhi-agra-jaipur-amritsar-wagah-border',8,array[1,2,3,4,5,6,7,8],7,10,5,4,3400000),
    ('delhi-agra-amritsar-tour',5,array[1,2,3,4,5],3,10,6,4,2450000),
    ('rajasthan',7,array[1,2,3,4,5,6,7],6,8,5,0,null),
    ('kashmir-kargil-dhooth-pathri-tour',6,array[1,2,3,5,6,7],9,10,6,4,2600000),
    ('delhi-kullu-manali-tour',4,array[1,2,3,4],5,8,5,4,2200000),
    ('kullu-manali-kasol',5,array[1,2,3,4,5],6,8,5,4,2900000)
),
tour_actual as (
  select p.slug,p.published,p.booking_enabled,p.base_price,
    jsonb_array_length(p.highlights) as highlights,
    jsonb_array_length(p.inclusions) as inclusions,
    jsonb_array_length(p.exclusions) as exclusions,
    jsonb_array_length(p.age_pricing) as price_bands,
    count(d.id)::integer as days,
    coalesce(array_agg(d.day_number order by d.day_number)
      filter(where d.day_number is not null),array[]::integer[]) as day_labels
  from public.tour_packages p
  left join public.tour_itinerary_days d on d.package_id=p.id
  where p.slug in (select slug from expected_tours)
  group by p.id
),
checks as (
  select 'package_count_55' as check_name,
    (select count(*) from public.tour_packages)=55 as passed,
    (select count(*)::text from public.tour_packages) as actual,'55' as expected
  union all
  select 'all_49_original_package_ids_preserved',
    (select count(*) from original_packages o join public.tour_packages p on p.slug=o.slug and p.id=o.id)=49,
    (select count(*)::text from original_packages o join public.tour_packages p on p.slug=o.slug and p.id=o.id),'49'
  union all
  select 'six_new_package_slugs_present',
    (select count(*) from new_packages n join public.tour_packages p using(slug))=6,
    (select count(*)::text from new_packages n join public.tour_packages p using(slug)),'6'
  union all
  select 'booking_enabled_column',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='tour_packages' and column_name='booking_enabled' and is_nullable='NO' and column_default ilike '%false%'),
    coalesce((select is_nullable||' / '||column_default from information_schema.columns where table_schema='public' and table_name='tour_packages' and column_name='booking_enabled'),'missing'),
    'NO / false'
  union all
  select 'age_pricing_column',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='tour_packages' and column_name='age_pricing' and is_nullable='NO' and column_default ilike '%[]%'),
    coalesce((select is_nullable||' / '||column_default from information_schema.columns where table_schema='public' and table_name='tour_packages' and column_name='age_pricing'),'missing'),
    'NO / []'
  union all
  select 'ten_staged_tours_present',
    (select count(*) from tour_actual)=10,
    (select count(*)::text from tour_actual),'10'
  union all
  select 'ten_staged_tours_held',
    not exists(select 1 from tour_actual where published or booking_enabled),
    (select count(*)::text from tour_actual where published or booking_enabled),'0 public/bookable'
  union all
  select 'tour_content_counts_match',
    not exists(
      select 1 from expected_tours e left join tour_actual a using(slug)
      where a.slug is null or a.days<>e.days or a.day_labels<>e.day_labels
        or a.highlights<>e.highlights or a.inclusions<>e.inclusions
        or a.exclusions<>e.exclusions or a.price_bands<>e.price_bands
        or a.base_price is distinct from e.base_price
    ),
    (select count(*)::text from expected_tours e join tour_actual a using(slug)
      where a.days=e.days and a.day_labels=e.day_labels and a.highlights=e.highlights
        and a.inclusions=e.inclusions and a.exclusions=e.exclusions
        and a.price_bands=e.price_bands and a.base_price is not distinct from e.base_price),
    '10'
  union all
  select 'booking_function_requires_both_flags',
    exists(
      select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='create_booking_secure'
        and pg_get_function_identity_arguments(p.oid)=
          'p_package_slug text, p_travel_date date, p_travellers jsonb, p_payment_mode text, p_idempotency_key uuid'
        and position('published=trueandbooking_enabled=true' in
          regexp_replace(lower(pg_get_functiondef(p.oid)),'\s+','','g'))>0
        and p.prosecdef and p.proconfig @> array['search_path=public, pg_temp']
    ),
    coalesce((
      select case when position('published=trueandbooking_enabled=true' in
        regexp_replace(lower(pg_get_functiondef(p.oid)),'\s+','','g'))>0
        then 'published + booking_enabled' else 'missing safety predicate' end
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='create_booking_secure'
      limit 1
    ),'function missing'),
    'published + booking_enabled'
  union all
  select 'booking_function_preserves_audited_semantics',
    exists(
      select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='create_booking_secure'
        and md5(regexp_replace(lower(p.prosrc),'\s+','','g'))='b5a8d95dab62ae238149a45cbf7545d1'
    ),
    coalesce((select md5(regexp_replace(lower(p.prosrc),'\s+','','g')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_booking_secure' limit 1),'missing'),
    'b5a8d95dab62ae238149a45cbf7545d1'
  union all
  select 'booking_function_acl',
    not has_function_privilege('anon','public.create_booking_secure(text,date,jsonb,text,uuid)','EXECUTE')
      and has_function_privilege('authenticated','public.create_booking_secure(text,date,jsonb,text,uuid)','EXECUTE'),
    'anon='||has_function_privilege('anon','public.create_booking_secure(text,date,jsonb,text,uuid)','EXECUTE')::text
      ||', authenticated='||has_function_privilege('authenticated','public.create_booking_secure(text,date,jsonb,text,uuid)','EXECUTE')::text,
    'anon=false, authenticated=true'
  union all
  select 'cr7_images_destinations',
    (select count(*) from public.destinations d
      where (d.slug='agumbe' and d.hero_image like '%photo-1578378377576-2ed7065bdb87%')
         or (d.slug='ajanta-ellora' and d.hero_image like '%photo-1620558601903-9f2441730121%')
         or (d.slug='andaman' and d.hero_image like '%photo-1767782843278-1cfc4acff2ff%'))=3,
    (select count(*)::text from public.destinations d
      where (d.slug='agumbe' and d.hero_image like '%photo-1578378377576-2ed7065bdb87%')
         or (d.slug='ajanta-ellora' and d.hero_image like '%photo-1620558601903-9f2441730121%')
         or (d.slug='andaman' and d.hero_image like '%photo-1767782843278-1cfc4acff2ff%')),'3'
  union all
  select 'cr7_images_packages',
    (select count(*) from public.tour_packages p
      where (p.slug='agumbe' and p.hero_image like '%photo-1578378377576-2ed7065bdb87%')
         or (p.slug='ajanta-ellora' and p.hero_image like '%photo-1620558601903-9f2441730121%')
         or (p.slug='andaman' and p.hero_image like '%photo-1767782843278-1cfc4acff2ff%'))=3,
    (select count(*)::text from public.tour_packages p
      where (p.slug='agumbe' and p.hero_image like '%photo-1578378377576-2ed7065bdb87%')
         or (p.slug='ajanta-ellora' and p.hero_image like '%photo-1620558601903-9f2441730121%')
         or (p.slug='andaman' and p.hero_image like '%photo-1767782843278-1cfc4acff2ff%')),'3'
  union all
  select 'cr7_bali_international',
    not exists(
      select 1 from public.tour_packages p
      left join public.destinations d on d.id=p.destination_id
      where (p.slug in ('bali','bali-nusa-penida','bali-island-escape')
        or d.slug in ('bali','bali-nusa-penida'))
        and p.category<>'international'::public.package_category
    ) and not exists(
      select 1 from public.destinations
      where slug in ('bali','bali-nusa-penida')
        and primary_category is distinct from 'international'::public.package_category
    ),
    'mismatches='||(
      (select count(*) from public.tour_packages p left join public.destinations d on d.id=p.destination_id
       where (p.slug in ('bali','bali-nusa-penida','bali-island-escape') or d.slug in ('bali','bali-nusa-penida'))
         and p.category<>'international'::public.package_category)
      +(select count(*) from public.destinations where slug in ('bali','bali-nusa-penida')
         and primary_category is distinct from 'international'::public.package_category)
    )::text,'mismatches=0'
  union all
  select 'legacy_rajasthan_offer_held',
    exists(select 1 from public.tour_packages where slug='rajasthan-heritage' and not published and not booking_enabled),
    coalesce((select 'published='||published::text||', booking='||booking_enabled::text from public.tour_packages where slug='rajasthan-heritage'),'missing'),
    'published=false, booking=false'
  union all
  select 'official_contact',
    exists(
      select 1 from public.site_settings
      where key='company_contact'
        and value->>'legalName'='My Tripon Travel Pvt Ltd'
        and value->'corporateOffice'->>'phone'='7582999111'
        and value->'kozhikodeOffice'->>'phone'='7592883311'
        and value->>'email'='mytripontravel@gmail.com'
    ),
    coalesce((select value::text from public.site_settings where key='company_contact'),'missing'),
    'approved CR1 contact JSON'
  union all
  select 'tulip_not_labelled_agumbe',
    not exists(
      select 1 from public.gallery_items
      where media_type='image' and media_url ilike '%tulip%'
        and (title ilike '%agumbe%' or alt_text ilike '%agumbe%')
    ),
    (select count(*)::text from public.gallery_items
      where media_type='image' and media_url ilike '%tulip%'
        and (title ilike '%agumbe%' or alt_text ilike '%agumbe%')),
    '0'
  union all
  select 'rls_preserved',
    not exists(
      select 1 from (values
        ('tour_packages'),('tour_itinerary_days'),('destinations'),('gallery_items'),
        ('site_settings'),('bookings'),('booking_travellers'),('payments'),('package_availability')
      ) required(table_name)
      join pg_class c on c.oid=to_regclass('public.'||required.table_name)
      where not c.relrowsecurity
    ),
    (select count(*)::text from (values
      ('tour_packages'),('tour_itinerary_days'),('destinations'),('gallery_items'),
      ('site_settings'),('bookings'),('booking_travellers'),('payments'),('package_availability')
    ) required(table_name) join pg_class c on c.oid=to_regclass('public.'||required.table_name)
      where c.relrowsecurity),
    '9'
  union all
  select 'storage_policies_preserved',
    (select count(*) from pg_policies where schemaname='storage' and tablename='objects'
      and policyname in ('site_media_public_read','site_media_admin_insert','site_media_admin_update','site_media_admin_delete'))=4,
    (select count(*)::text from pg_policies where schemaname='storage' and tablename='objects'
      and policyname in ('site_media_public_read','site_media_admin_insert','site_media_admin_update','site_media_admin_delete')),'4'
  union all
  select 'rls_and_storage_policy_definitions_preserved',
    not exists(
      select 1 from expected_policies e
      left join pg_policies p on p.schemaname=e.schema_name and p.tablename=e.table_name and p.policyname=e.policy_name
      where p.policyname is null or p.permissive<>e.permissive or p.roles<>e.roles or p.cmd<>e.command
        or regexp_replace(coalesce(p.qual,'<null>'),'\s+','','g')<>
           regexp_replace(coalesce(e.using_expression,'<null>'),'\s+','','g')
        or regexp_replace(coalesce(p.with_check,'<null>'),'\s+','','g')<>
           regexp_replace(coalesce(e.check_expression,'<null>'),'\s+','','g')
    ) and not exists(
      select 1 from pg_policies p
      where ((p.schemaname='public' and p.tablename in (
        'tour_packages','tour_itinerary_days','destinations','gallery_items','site_settings',
        'bookings','booking_travellers','payments','package_availability'
      )) or (p.schemaname='storage' and p.tablename='objects'))
        and not exists(select 1 from expected_policies e where e.schema_name=p.schemaname and e.table_name=p.tablename and e.policy_name=p.policyname)
    ),
    (select count(*)::text from expected_policies e join pg_policies p
      on p.schemaname=e.schema_name and p.tablename=e.table_name and p.policyname=e.policy_name
      where p.permissive=e.permissive and p.roles=e.roles and p.cmd=e.command
        and regexp_replace(coalesce(p.qual,'<null>'),'\s+','','g')=
            regexp_replace(coalesce(e.using_expression,'<null>'),'\s+','','g')
        and regexp_replace(coalesce(p.with_check,'<null>'),'\s+','','g')=
            regexp_replace(coalesce(e.check_expression,'<null>'),'\s+','','g')),
    '22'
  union all
  select 'reconciliation_marker',
    exists(select 1 from public.site_settings where key='_migration_reconciliation_cr1_12_20261019'
      and value->>'migration'='202610190001_production_reconciliation_cr1_12.sql'),
    coalesce((select value::text from public.site_settings where key='_migration_reconciliation_cr1_12_20261019'),'missing'),
    'marker present'
)
select jsonb_build_object(
  'all_checks_passed',not exists(select 1 from checks where not passed),
  'checks',(select jsonb_agg(to_jsonb(checks) order by check_name) from checks),
  'staged_tours',(select jsonb_agg(to_jsonb(tour_actual) order by slug) from tour_actual),
  'preservation_observation',jsonb_build_object(
    'bookings', (select count(*) from public.bookings),
    'payments', (select count(*) from public.payments),
    'package_images', (select count(*) from public.package_images),
    'gallery_items', (select count(*) from public.gallery_items)
  )
) as reconciliation_verification;

