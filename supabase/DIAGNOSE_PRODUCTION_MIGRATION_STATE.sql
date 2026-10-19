-- ONE-TIME, READ-ONLY production compatibility diagnostic.
-- Run as a Supabase project owner in SQL Editor. It returns one JSON document.
-- It performs no DDL or DML and does not acquire write locks.

with
expected_tables(schema_name,table_name) as (
  values
    ('public','profiles'),('public','destinations'),('public','tour_packages'),
    ('public','tour_itinerary_days'),('public','package_images'),
    ('public','package_availability'),('public','bookings'),
    ('public','booking_travellers'),('public','payments'),
    ('public','payment_webhook_events'),('public','leads'),
    ('public','lead_history'),('public','quotations'),
    ('public','quotation_items'),('public','invoices'),('public','vouchers'),
    ('public','documents'),('public','travel_services'),('public','blogs'),
    ('public','events'),('public','reviews'),('public','faqs'),
    ('public','newsletter_subscribers'),('public','hero_slides'),
    ('public','site_sections'),('public','navigation_items'),
    ('public','seo_entries'),('public','notifications'),('public','audit_logs'),
    ('public','report_exports'),('public','request_rate_limits'),
    ('public','gallery_items'),('public','testimonials'),('public','awards'),
    ('public','travel_articles'),('public','site_settings'),('public','enquiries'),
    ('storage','buckets'),('storage','objects')
),
table_state as (
  select e.schema_name,e.table_name,
    c.oid is not null as exists,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as rls_forced,
    coalesce(s.n_live_tup,0)::bigint as estimated_rows
  from expected_tables e
  left join pg_namespace n on n.nspname=e.schema_name
  left join pg_class c on c.relnamespace=n.oid and c.relname=e.table_name and c.relkind in ('r','p')
  left join pg_stat_all_tables s on s.relid=c.oid
),
column_state as (
  select c.table_schema,c.table_name,c.ordinal_position,c.column_name,c.data_type,
    c.udt_schema,c.udt_name,c.is_nullable,c.column_default
  from information_schema.columns c
  join expected_tables e on e.schema_name=c.table_schema and e.table_name=c.table_name
),
enum_state as (
  select n.nspname as schema_name,t.typname as enum_name,
    jsonb_agg(e.enumlabel order by e.enumsortorder) as labels
  from pg_type t
  join pg_namespace n on n.oid=t.typnamespace
  join pg_enum e on e.enumtypid=t.oid
  where n.nspname='public'
  group by n.nspname,t.typname
),
function_state as (
  select n.nspname as schema_name,p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as result_type,
    p.prosecdef as security_definer,p.provolatile as volatility,
    p.proconfig as configuration,p.proacl::text as acl,
    pg_get_functiondef(p.oid) as definition
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in (
      'create_booking_secure','apply_payment_webhook_event','is_admin',
      'handle_new_user','capture_lead_history','capture_admin_audit'
    )
),
policy_state as (
  select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
  from pg_policies
  where schemaname in ('public','storage')
    and (tablename in (select table_name from expected_tables)
      or policyname like 'site_media_%')
),
trigger_state as (
  select n.nspname as schema_name,c.relname as table_name,t.tgname as trigger_name,
    pg_get_triggerdef(t.oid,true) as definition
  from pg_trigger t
  join pg_class c on c.oid=t.tgrelid
  join pg_namespace n on n.oid=c.relnamespace
  where not t.tgisinternal and n.nspname in ('public','auth')
),
constraint_state as (
  select n.nspname as schema_name,c.relname as table_name,k.conname as constraint_name,
    k.contype as constraint_type,pg_get_constraintdef(k.oid,true) as definition
  from pg_constraint k
  join pg_class c on c.oid=k.conrelid
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relname in (select table_name from expected_tables where schema_name='public')
),
index_state as (
  select schemaname,tablename,indexname,indexdef
  from pg_indexes
  where schemaname='public'
    and tablename in (
      'tour_packages','tour_itinerary_days','package_images','package_availability',
      'bookings','booking_travellers','payments'
    )
),
grant_state as (
  select table_schema,table_name,grantee,privilege_type
  from information_schema.role_table_grants
  where table_schema='public'
    and table_name in (
      'tour_packages','tour_itinerary_days','package_images','package_availability',
      'bookings','booking_travellers','payments','leads','profiles'
    )
    and grantee in ('anon','authenticated','service_role')
),
relevant_slugs(slug) as (
  values
    ('kashmir-kargil'),
    ('delhi-agra-jaipur-golden-triangle-tour'),
    ('delhi-agra-mathura-jaipur-tour'),
    ('delhi-agra-tour'),
    ('delhi-agra-jaipur-amritsar-wagah-border'),
    ('delhi-agra-amritsar-tour'),
    ('rajasthan'),('rajasthan-heritage'),
    ('kashmir-kargil-dhooth-pathri-tour'),
    ('delhi-kullu-manali-tour'),('kullu-manali-kasol'),
    ('bali'),('bali-nusa-penida'),('bali-island-escape'),
    ('agumbe'),('ajanta-ellora'),('andaman')
),
package_inventory as (
  select to_jsonb(p) as row_data
  from public.tour_packages p
),
relevant_packages as (
  select to_jsonb(p) as row_data
  from public.tour_packages p
  join relevant_slugs r on r.slug=to_jsonb(p)->>'slug'
),
relevant_itinerary as (
  select to_jsonb(i) || jsonb_build_object('package_slug',to_jsonb(p)->>'slug') as row_data
  from public.tour_itinerary_days i
  join public.tour_packages p on (to_jsonb(i)->>'package_id')=(to_jsonb(p)->>'id')
  join relevant_slugs r on r.slug=to_jsonb(p)->>'slug'
),
relevant_destinations as (
  select to_jsonb(d) as row_data
  from public.destinations d
  where to_jsonb(d)->>'slug' in (
    'bali','bali-nusa-penida','agumbe','ajanta-ellora','andaman',
    'rajasthan','kashmir-kargil','kullu-manali-kasol'
  )
),
booking_function_checks as (
  select function_name,arguments,
    position('published=true' in regexp_replace(lower(definition),'\s+','','g'))>0
      as requires_published,
    position('booking_enabled=true' in regexp_replace(lower(definition),'\s+','','g'))>0
      as requires_booking_enabled
  from function_state
  where function_name='create_booking_secure'
),
derived as (
  select
    (select count(*) from public.tour_packages) as exact_package_count,
    exists(
      select 1 from information_schema.columns
      where table_schema='public' and table_name='tour_packages' and column_name='booking_enabled'
    ) as booking_enabled_column_exists,
    exists(
      select 1 from information_schema.columns
      where table_schema='public' and table_name='tour_packages' and column_name='age_pricing'
    ) as age_pricing_column_exists,
    exists(
      select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='create_booking_secure'
    ) as create_booking_secure_exists,
    to_regclass('supabase_migrations.schema_migrations') is not null as migration_ledger_exists,
    (select count(*) from relevant_packages) as relevant_package_count,
    (select count(*) from relevant_itinerary) as relevant_itinerary_row_count
)
select jsonb_build_object(
  'diagnostic_version','2026-10-19-one-time',
  'generated_at',clock_timestamp(),
  'database',jsonb_build_object(
    'current_database',current_database(),
    'current_user',current_user,
    'server_version',current_setting('server_version'),
    'search_path',current_setting('search_path')
  ),
  'derived_findings',(select to_jsonb(derived) from derived),
  'extensions',coalesce((
    select jsonb_agg(jsonb_build_object('name',extname,'version',extversion) order by extname)
    from pg_extension
  ),'[]'::jsonb),
  'tables',coalesce((select jsonb_agg(to_jsonb(table_state) order by schema_name,table_name) from table_state),'[]'::jsonb),
  'columns',coalesce((select jsonb_agg(to_jsonb(column_state) order by table_schema,table_name,ordinal_position) from column_state),'[]'::jsonb),
  'enums',coalesce((select jsonb_agg(to_jsonb(enum_state) order by enum_name) from enum_state),'[]'::jsonb),
  'functions',coalesce((select jsonb_agg(to_jsonb(function_state) order by function_name,arguments) from function_state),'[]'::jsonb),
  'booking_function_checks',coalesce((select jsonb_agg(to_jsonb(booking_function_checks) order by arguments) from booking_function_checks),'[]'::jsonb),
  'policies',coalesce((select jsonb_agg(to_jsonb(policy_state) order by schemaname,tablename,policyname) from policy_state),'[]'::jsonb),
  'triggers',coalesce((select jsonb_agg(to_jsonb(trigger_state) order by schema_name,table_name,trigger_name) from trigger_state),'[]'::jsonb),
  'constraints',coalesce((select jsonb_agg(to_jsonb(constraint_state) order by schema_name,table_name,constraint_name) from constraint_state),'[]'::jsonb),
  'indexes',coalesce((select jsonb_agg(to_jsonb(index_state) order by tablename,indexname) from index_state),'[]'::jsonb),
  'grants',coalesce((select jsonb_agg(to_jsonb(grant_state) order by table_name,grantee,privilege_type) from grant_state),'[]'::jsonb),
  'all_package_inventory',coalesce((select jsonb_agg(row_data order by row_data->>'slug') from package_inventory),'[]'::jsonb),
  'relevant_packages',coalesce((select jsonb_agg(row_data order by row_data->>'slug') from relevant_packages),'[]'::jsonb),
  'relevant_itinerary',coalesce((select jsonb_agg(row_data order by row_data->>'package_slug',(row_data->>'day_number')::integer) from relevant_itinerary),'[]'::jsonb),
  'relevant_destinations',coalesce((select jsonb_agg(row_data order by row_data->>'slug') from relevant_destinations),'[]'::jsonb)
) as production_migration_diagnostic;
