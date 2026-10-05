-- My Tripon Travel production foundation.
-- Apply after the original schema. Privileged writes are performed only by authorized
-- users under RLS or by audited Edge Functions using server-held credentials.

create extension if not exists pgcrypto;

create type public.app_role as enum ('customer','staff','admin','super_admin');
create type public.package_category as enum ('domestic','maharashtra','international','trek','expedition','weekend','villa','custom');
create type public.booking_status as enum ('draft','pending_payment','confirmed','cancelled','completed');
create type public.payment_status as enum ('pending','processing','success','failed','refunded');
create type public.lead_status as enum ('new','contacted','follow_up','qualified','converted','closed_lost');
create type public.document_status as enum ('draft','issued','void');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'customer',
  full_name text,
  phone text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.profiles(id, full_name)
  values(new.id, nullif(new.raw_user_meta_data->>'full_name',''))
  on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
$$;

alter table public.destinations add column if not exists country text;
alter table public.destinations add column if not exists state text;
alter table public.destinations add column if not exists seo_title text;
alter table public.destinations add column if not exists seo_description text;
alter table public.destinations add column if not exists featured boolean not null default false;

alter table public.tour_packages add column if not exists category public.package_category not null default 'domestic';
alter table public.tour_packages add column if not exists description text;
alter table public.tour_packages add column if not exists highlights jsonb not null default '[]'::jsonb;
alter table public.tour_packages add column if not exists inclusions jsonb not null default '[]'::jsonb;
alter table public.tour_packages add column if not exists exclusions jsonb not null default '[]'::jsonb;
alter table public.tour_packages add column if not exists important_information text;
alter table public.tour_packages add column if not exists base_price integer check (base_price is null or base_price >= 0);
alter table public.tour_packages add column if not exists child_price integer check (child_price is null or child_price >= 0);
alter table public.tour_packages add column if not exists infant_price integer check (infant_price is null or infant_price >= 0);
alter table public.tour_packages add column if not exists tax_rate numeric(5,2) not null default 0 check (tax_rate between 0 and 100);
alter table public.tour_packages add column if not exists advance_type text not null default 'percentage' check (advance_type in ('percentage','fixed'));
alter table public.tour_packages add column if not exists advance_value integer not null default 0 check (advance_value >= 0);
alter table public.tour_packages add column if not exists currency char(3) not null default 'INR';
alter table public.tour_packages add column if not exists featured boolean not null default false;
alter table public.tour_packages add column if not exists trending boolean not null default false;
alter table public.tour_packages add column if not exists seo_title text;
alter table public.tour_packages add column if not exists seo_description text;
alter table public.tour_packages add column if not exists published_at timestamptz;
create index if not exists tour_packages_public_idx on public.tour_packages(published, category, featured, trending);

create table if not exists public.package_images (
  id uuid primary key default gen_random_uuid(), package_id uuid not null references public.tour_packages(id) on delete cascade,
  storage_path text not null, alt_text text not null default '', display_order integer not null default 0,
  is_cover boolean not null default false, created_at timestamptz not null default now(), unique(package_id, storage_path)
);
create index if not exists package_images_package_idx on public.package_images(package_id, display_order);

create table if not exists public.package_availability (
  id uuid primary key default gen_random_uuid(), package_id uuid not null references public.tour_packages(id) on delete cascade,
  travel_date date not null, capacity integer not null check(capacity >= 0), reserved integer not null default 0 check(reserved >= 0),
  price_override integer check(price_override is null or price_override >= 0), status text not null default 'open' check(status in ('open','closed','sold_out')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(package_id, travel_date),
  check(reserved <= capacity)
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(), reference text unique not null,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  package_id uuid references public.tour_packages(id) on delete restrict,
  travel_date date not null, adult_count integer not null default 1 check(adult_count >= 1),
  child_count integer not null default 0 check(child_count >= 0), infant_count integer not null default 0 check(infant_count >= 0),
  currency char(3) not null default 'INR', subtotal_amount integer not null check(subtotal_amount >= 0),
  tax_amount integer not null check(tax_amount >= 0), total_amount integer not null check(total_amount >= 0),
  advance_amount integer not null check(advance_amount >= 0), paid_amount integer not null default 0 check(paid_amount >= 0),
  balance_amount integer not null check(balance_amount >= 0), price_snapshot jsonb not null,
  booking_status public.booking_status not null default 'pending_payment', payment_status public.payment_status not null default 'pending',
  idempotency_key uuid not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(customer_id, idempotency_key)
);
create index if not exists bookings_customer_idx on public.bookings(customer_id, created_at desc);
create index if not exists bookings_operations_idx on public.bookings(booking_status, payment_status, travel_date);

create table if not exists public.booking_travellers (
  id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id) on delete cascade,
  traveller_type text not null check(traveller_type in ('adult','child','infant')),
  first_name text not null check(length(first_name) between 1 and 100), last_name text not null check(length(last_name) between 1 and 100),
  date_of_birth date, passport_last_four char(4), created_at timestamptz not null default now()
);
create index if not exists booking_travellers_booking_idx on public.booking_travellers(booking_id);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id) on delete restrict,
  provider text not null, provider_order_id text, provider_payment_id text, amount integer not null check(amount > 0), currency char(3) not null default 'INR',
  payment_kind text not null check(payment_kind in ('advance','balance','full','refund')),
  status public.payment_status not null default 'pending', idempotency_key uuid not null unique,
  verified_at timestamptz, failure_code text, provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(provider, provider_order_id), unique(provider, provider_payment_id)
);
create index if not exists payments_booking_idx on public.payments(booking_id, created_at desc);

create table if not exists public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(), provider text not null, provider_event_id text not null,
  signature_valid boolean not null default false, payload jsonb not null, processed_at timestamptz,
  processing_error text, received_at timestamptz not null default now(), unique(provider, provider_event_id)
);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(), customer_id uuid references public.profiles(id) on delete set null,
  name text not null, phone text not null, email text, destination text, package_id uuid references public.tour_packages(id) on delete set null,
  travel_start date, travel_end date, travel_month text, adult_count integer check(adult_count is null or adult_count >= 0),
  child_count integer check(child_count is null or child_count >= 0), infant_count integer check(infant_count is null or infant_count >= 0),
  message text, source text not null default 'website', status public.lead_status not null default 'new', assigned_to uuid references public.profiles(id) on delete set null,
  admin_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists leads_pipeline_idx on public.leads(status, created_at desc);

create table if not exists public.lead_history (
  id uuid primary key default gen_random_uuid(), lead_id uuid not null references public.leads(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null, event_type text not null,
  old_value jsonb, new_value jsonb, note text, created_at timestamptz not null default now()
);

create table if not exists public.quotations (
  id uuid primary key default gen_random_uuid(), quotation_number text unique not null,
  customer_id uuid references public.profiles(id) on delete restrict, lead_id uuid references public.leads(id) on delete set null,
  package_id uuid references public.tour_packages(id) on delete set null, version integer not null default 1 check(version > 0),
  status text not null default 'draft' check(status in ('draft','sent','accepted','expired','cancelled')),
  currency char(3) not null default 'INR', subtotal_amount integer not null default 0, discount_amount integer not null default 0,
  tax_amount integer not null default 0, fee_amount integer not null default 0, total_amount integer not null default 0,
  payment_terms text, notes text, valid_until date, created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(lead_id, version)
);

create table if not exists public.quotation_items (
  id uuid primary key default gen_random_uuid(), quotation_id uuid not null references public.quotations(id) on delete cascade,
  item_type text not null default 'service', description text not null, quantity numeric(10,2) not null default 1 check(quantity > 0),
  unit_amount integer not null check(unit_amount >= 0), tax_rate numeric(5,2) not null default 0 check(tax_rate between 0 and 100), display_order integer not null default 0
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(), invoice_number text unique not null,
  booking_id uuid not null references public.bookings(id) on delete restrict, customer_id uuid not null references public.profiles(id) on delete restrict,
  status public.document_status not null default 'draft', currency char(3) not null default 'INR',
  subtotal_amount integer not null, tax_amount integer not null, total_amount integer not null, amount_due integer not null,
  issued_at timestamptz, due_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(), voucher_number text unique not null,
  booking_id uuid not null references public.bookings(id) on delete cascade, customer_id uuid not null references public.profiles(id) on delete restrict,
  voucher_type text not null check(voucher_type in ('hotel','transport','activity','other')), status public.document_status not null default 'draft',
  content jsonb not null default '{}'::jsonb, issued_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(), document_number text unique not null,
  booking_id uuid references public.bookings(id) on delete cascade, customer_id uuid not null references public.profiles(id) on delete restrict,
  document_type text not null, title text not null, private_storage_path text not null unique,
  mime_type text not null, file_size integer not null check(file_size > 0 and file_size <= 15728640),
  status public.document_status not null default 'draft', issued_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(mime_type in ('application/pdf','image/jpeg','image/png'))
);
create index if not exists documents_customer_idx on public.documents(customer_id, booking_id);

create table if not exists public.travel_services (
  id uuid primary key default gen_random_uuid(), slug text unique not null, name text not null,
  category text not null, description text, service_mode text not null default 'enquiry' check(service_mode in ('enquiry','bookable')),
  base_price integer check(base_price is null or base_price >= 0), published boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.blogs (
  id uuid primary key default gen_random_uuid(), slug text unique not null, title text not null, excerpt text, body_markdown text,
  cover_image text, author_id uuid references public.profiles(id) on delete set null, seo_title text, seo_description text,
  published boolean not null default false, published_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(), slug text unique not null, title text not null, description text,
  starts_at timestamptz, ends_at timestamptz, location text, cover_image text, registration_url text,
  published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(), customer_id uuid references public.profiles(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null, quote text not null,
  rating smallint check(rating between 1 and 5), verified boolean not null default false,
  published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.faqs (
  id uuid primary key default gen_random_uuid(), question text not null, answer text not null, category text,
  display_order integer not null default 0, published boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(), email text not null, consent_at timestamptz not null default now(),
  source text not null default 'website', status text not null default 'subscribed' check(status in ('subscribed','unsubscribed')),
  unsubscribed_at timestamptz, created_at timestamptz not null default now()
);
create unique index if not exists newsletter_email_unique_idx on public.newsletter_subscribers(lower(email));

create table if not exists public.hero_slides (
  id uuid primary key default gen_random_uuid(), title text not null, subtitle text, destination_id uuid references public.destinations(id) on delete set null,
  image_url text not null, alt_text text not null, cta_label text, cta_url text, display_order integer not null default 0,
  published boolean not null default false, starts_at timestamptz, ends_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.site_sections (
  id uuid primary key default gen_random_uuid(), section_key text unique not null, title text, content jsonb not null default '{}'::jsonb,
  display_order integer not null default 0, published boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.navigation_items (
  id uuid primary key default gen_random_uuid(), location text not null check(location in ('header','footer')),
  label text not null, url text not null, parent_id uuid references public.navigation_items(id) on delete cascade,
  display_order integer not null default 0, published boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.seo_entries (
  id uuid primary key default gen_random_uuid(), route text unique not null, title text not null, description text not null,
  canonical_url text, og_image text, robots text not null default 'index,follow', schema_json jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid references public.profiles(id) on delete cascade,
  booking_id uuid references public.bookings(id) on delete cascade, channel text not null check(channel in ('email','whatsapp','in_app')),
  template_key text not null, recipient text, payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check(status in ('queued','sent','failed','skipped_unconfigured')),
  provider_reference text, error_message text, created_at timestamptz not null default now(), sent_at timestamptz
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key, actor_id uuid references public.profiles(id) on delete set null,
  action text not null, entity_type text not null, entity_id text, before_data jsonb, after_data jsonb,
  ip_hash text, user_agent text, created_at timestamptz not null default now()
);

create table if not exists public.report_exports (
  id uuid primary key default gen_random_uuid(), requested_by uuid not null references public.profiles(id) on delete restrict,
  report_type text not null, parameters jsonb not null default '{}'::jsonb, private_storage_path text,
  status text not null default 'queued' check(status in ('queued','processing','ready','failed')),
  created_at timestamptz not null default now(), expires_at timestamptz
);

create table if not exists public.request_rate_limits (
  id bigint generated always as identity primary key, key_hash text not null, action text not null,
  created_at timestamptz not null default now()
);
create index if not exists request_rate_limits_lookup_idx on public.request_rate_limits(action,key_hash,created_at desc);

do $$ declare table_name text; begin
  foreach table_name in array array[
    'profiles','destinations','tour_packages','tour_itinerary_days','package_images','package_availability','bookings','booking_travellers',
    'payments','payment_webhook_events','leads','lead_history','quotations','quotation_items','invoices','vouchers','documents','travel_services',
    'blogs','events','gallery_items','testimonials','reviews','faqs','newsletter_subscribers','hero_slides','site_sections','navigation_items',
    'seo_entries','site_settings','notifications','audit_logs','report_exports','request_rate_limits'
  ] loop execute format('alter table public.%I enable row level security', table_name); end loop;
end $$;

-- Profiles: customers may edit ordinary profile fields, never their role.
drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles for select to authenticated using(id = auth.uid() or public.is_admin());
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update to authenticated using(id = auth.uid() or public.is_admin())
with check(id = auth.uid() or public.is_admin());
revoke update on public.profiles from authenticated;
grant update(full_name,phone,avatar_path,updated_at) on public.profiles to authenticated;

-- Published CMS content is public; all writes require an admin role.
do $$ declare table_name text; begin
  foreach table_name in array array['destinations','tour_packages','gallery_items','testimonials','travel_services','blogs','events','reviews','faqs','hero_slides','site_sections','navigation_items'] loop
    execute format('drop policy if exists public_read_published on public.%I',table_name);
    execute format('create policy public_read_published on public.%I for select to anon, authenticated using(published = true or public.is_admin())',table_name);
    execute format('drop policy if exists admin_manage on public.%I',table_name);
    execute format('create policy admin_manage on public.%I for all to authenticated using(public.is_admin()) with check(public.is_admin())',table_name);
  end loop;
end $$;

drop policy if exists public_package_images on public.package_images;
create policy public_package_images on public.package_images for select to anon, authenticated using(exists(select 1 from public.tour_packages p where p.id=package_id and (p.published or public.is_admin())));
drop policy if exists admin_package_images on public.package_images;
create policy admin_package_images on public.package_images for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists public_itinerary_days on public.tour_itinerary_days;
create policy public_itinerary_days on public.tour_itinerary_days for select to anon, authenticated using(exists(select 1 from public.tour_packages p where p.id=package_id and (p.published or public.is_admin())));
drop policy if exists admin_itinerary_days on public.tour_itinerary_days;
create policy admin_itinerary_days on public.tour_itinerary_days for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists public_availability on public.package_availability;
create policy public_availability on public.package_availability for select to anon, authenticated using(status='open' and exists(select 1 from public.tour_packages p where p.id=package_id and p.published));
drop policy if exists admin_availability on public.package_availability;
create policy admin_availability on public.package_availability for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- Transactional ownership policies. Inserts occur through validated Edge Functions.
drop policy if exists customer_bookings on public.bookings;
create policy customer_bookings on public.bookings for select to authenticated using(customer_id=auth.uid() or public.is_admin());
drop policy if exists admin_bookings on public.bookings;
create policy admin_bookings on public.bookings for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists customer_travellers on public.booking_travellers;
create policy customer_travellers on public.booking_travellers for select to authenticated using(exists(select 1 from public.bookings b where b.id=booking_id and (b.customer_id=auth.uid() or public.is_admin())));
drop policy if exists customer_payments on public.payments;
create policy customer_payments on public.payments for select to authenticated using(exists(select 1 from public.bookings b where b.id=booking_id and (b.customer_id=auth.uid() or public.is_admin())));

do $$ declare table_name text; owner_column text; begin
  for table_name, owner_column in select * from (values ('invoices','customer_id'),('vouchers','customer_id'),('documents','customer_id')) as owned(table_name,owner_column) loop
    execute format('drop policy if exists customer_owned on public.%I',table_name);
    execute format('create policy customer_owned on public.%I for select to authenticated using(%I=auth.uid() or public.is_admin())',table_name,owner_column);
    execute format('drop policy if exists admin_owned_manage on public.%I',table_name);
    execute format('create policy admin_owned_manage on public.%I for all to authenticated using(public.is_admin()) with check(public.is_admin())',table_name);
  end loop;
end $$;

create or replace function public.capture_lead_history()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if old.status is distinct from new.status or old.admin_notes is distinct from new.admin_notes or old.assigned_to is distinct from new.assigned_to then
    insert into public.lead_history(lead_id,actor_id,event_type,old_value,new_value,note)
    values(new.id,auth.uid(),'lead_updated',jsonb_build_object('status',old.status,'assigned_to',old.assigned_to),jsonb_build_object('status',new.status,'assigned_to',new.assigned_to),new.admin_notes);
  end if;
  return new;
end $$;
drop trigger if exists capture_lead_history on public.leads;
create trigger capture_lead_history after update on public.leads for each row execute function public.capture_lead_history();

do $$ declare table_name text; begin
  foreach table_name in array array['profiles','package_availability','bookings','payments','leads','quotations','invoices','vouchers','documents','travel_services','blogs','events','reviews','faqs','hero_slides','site_sections','navigation_items','seo_entries'] loop
    execute format('drop trigger if exists production_updated_at on public.%I',table_name);
    execute format('create trigger production_updated_at before update on public.%I for each row execute function public.set_updated_at()',table_name);
  end loop;
end $$;

create or replace function public.capture_admin_audit()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is not null and public.is_admin() then
    insert into public.audit_logs(actor_id,action,entity_type,entity_id,before_data,after_data)
    values(auth.uid(),lower(tg_op),tg_table_name,coalesce(to_jsonb(new)->>'id',to_jsonb(old)->>'id',to_jsonb(new)->>'key',to_jsonb(old)->>'key'),case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
do $$ declare table_name text; begin
  foreach table_name in array array['destinations','tour_packages','package_availability','bookings','leads','quotations','invoices','vouchers','documents','travel_services','blogs','events','gallery_items','testimonials','reviews','faqs','hero_slides','site_sections','navigation_items','seo_entries','site_settings'] loop
    execute format('drop trigger if exists admin_audit on public.%I',table_name);
    execute format('create trigger admin_audit after insert or update or delete on public.%I for each row execute function public.capture_admin_audit()',table_name);
  end loop;
end $$;

do $$ declare table_name text; begin
  foreach table_name in array array['leads','lead_history','quotations','quotation_items','payment_webhook_events','newsletter_subscribers','seo_entries','site_settings','notifications','audit_logs','report_exports','request_rate_limits'] loop
    execute format('drop policy if exists admin_only on public.%I',table_name);
    execute format('create policy admin_only on public.%I for all to authenticated using(public.is_admin()) with check(public.is_admin())',table_name);
  end loop;
end $$;

-- Site settings are public only when explicitly flagged as public JSON.
drop policy if exists public_site_settings on public.site_settings;
create policy public_site_settings on public.site_settings for select to anon, authenticated using(coalesce((value->>'public')::boolean,false) or public.is_admin());
drop policy if exists "Public can read site settings" on public.site_settings;
drop policy if exists "Public can submit enquiries" on public.enquiries;
alter table public.enquiries enable row level security;

create or replace function public.create_booking_secure(
  p_package_slug text, p_travel_date date, p_travellers jsonb,
  p_payment_mode text, p_idempotency_key uuid
) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_user uuid := auth.uid(); v_package public.tour_packages%rowtype; v_availability public.package_availability%rowtype;
  v_booking public.bookings%rowtype; v_adults integer; v_children integer; v_infants integer; v_people integer;
  v_subtotal integer; v_tax integer; v_total integer; v_advance integer; v_adult_price integer;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='28000'; end if;
  if p_travel_date <= current_date then raise exception 'invalid_travel_date'; end if;
  if p_payment_mode not in ('advance','full') then raise exception 'invalid_payment_mode'; end if;
  if jsonb_typeof(p_travellers) <> 'array' or jsonb_array_length(p_travellers) < 1 or jsonb_array_length(p_travellers) > 12 then raise exception 'invalid_traveller_count'; end if;
  if exists(select 1 from jsonb_array_elements(p_travellers) t where t->>'type' not in ('adult','child','infant') or length(trim(t->>'firstName')) not between 1 and 100 or length(trim(t->>'lastName')) not between 1 and 100) then raise exception 'invalid_traveller'; end if;

  select * into v_package from public.tour_packages where slug=p_package_slug and published=true for share;
  if not found or v_package.base_price is null then raise exception 'package_unavailable'; end if;
  select * into v_availability from public.package_availability where package_id=v_package.id and travel_date=p_travel_date for update;
  if not found or v_availability.status <> 'open' then raise exception 'date_unavailable'; end if;

  select count(*) filter(where value->>'type'='adult'), count(*) filter(where value->>'type'='child'), count(*) filter(where value->>'type'='infant')
  into v_adults,v_children,v_infants from jsonb_array_elements(p_travellers);
  if v_adults < 1 then raise exception 'adult_required'; end if;
  v_people := v_adults+v_children+v_infants;
  if v_availability.reserved+v_people > v_availability.capacity then raise exception 'insufficient_capacity'; end if;
  v_adult_price := coalesce(v_availability.price_override,v_package.base_price);
  v_subtotal := v_adults*v_adult_price + v_children*coalesce(v_package.child_price,v_adult_price) + v_infants*coalesce(v_package.infant_price,0);
  v_tax := round(v_subtotal*v_package.tax_rate/100.0);
  v_total := v_subtotal+v_tax;
  v_advance := case when p_payment_mode='full' then v_total when v_package.advance_type='fixed' then least(v_package.advance_value,v_total) else least(round(v_total*v_package.advance_value/100.0),v_total) end;

  insert into public.bookings(reference,customer_id,package_id,travel_date,adult_count,child_count,infant_count,currency,subtotal_amount,tax_amount,total_amount,advance_amount,balance_amount,price_snapshot,idempotency_key)
  values('MYT-'||to_char(clock_timestamp(),'YYMMDD')||'-'||upper(substr(encode(gen_random_bytes(5),'hex'),1,8)),v_user,v_package.id,p_travel_date,v_adults,v_children,v_infants,v_package.currency,v_subtotal,v_tax,v_total,v_advance,v_total,
    jsonb_build_object('package_id',v_package.id,'title',v_package.title,'adult_price',v_adult_price,'child_price',coalesce(v_package.child_price,v_adult_price),'infant_price',coalesce(v_package.infant_price,0),'tax_rate',v_package.tax_rate,'calculated_at',now()),p_idempotency_key)
  on conflict(customer_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning * into v_booking;

  if not exists(select 1 from public.booking_travellers where booking_id=v_booking.id) then
    insert into public.booking_travellers(booking_id,traveller_type,first_name,last_name,date_of_birth)
    select v_booking.id,(t->>'type'),trim(t->>'firstName'),trim(t->>'lastName'),nullif(t->>'dateOfBirth','')::date from jsonb_array_elements(p_travellers) t;
    update public.package_availability set reserved=reserved+v_people,status=case when reserved+v_people>=capacity then 'sold_out' else status end where id=v_availability.id;
  end if;
  return to_jsonb(v_booking);
end $$;
revoke all on function public.create_booking_secure(text,date,jsonb,text,uuid) from public;
grant execute on function public.create_booking_secure(text,date,jsonb,text,uuid) to authenticated;

-- Private booking documents. Edge Functions issue short-lived signed URLs after RLS ownership checks.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('booking-documents','booking-documents',false,15728640,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

-- No direct public storage policy is created. Admin upload and customer download are mediated by secure functions.
