-- My Tripon Travel content and enquiry foundation.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;

create table if not exists public.destinations (
 id uuid primary key default gen_random_uuid(), slug text unique not null,
 name text not null, region text, summary text, description text, hero_image text,
 published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.tour_packages (
 id uuid primary key default gen_random_uuid(), slug text unique not null,
 title text not null, destination_id uuid references public.destinations(id) on delete set null,
 duration_days integer, duration_nights integer, summary text, overview text, hero_image text,
 trip_style text, published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.tour_itinerary_days (
 id uuid primary key default gen_random_uuid(), package_id uuid not null references public.tour_packages(id) on delete cascade,
 day_number integer not null, title text not null, description text, location text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(package_id, day_number)
);
create table if not exists public.gallery_items (
 id uuid primary key default gen_random_uuid(), slug text unique, title text, media_url text not null,
 media_type text not null default 'image' check (media_type in ('image','video')),
 poster_url text, category text, destination_id uuid references public.destinations(id) on delete set null,
 alt_text text, display_order integer not null default 0, published boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.testimonials (
 id uuid primary key default gen_random_uuid(), name text, location text, quote text,
 media_url text, media_type text not null default 'text' check(media_type in ('text','video')),
 poster_url text, published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.awards (
 id uuid primary key default gen_random_uuid(), title text not null, issuer text, description text,
 awarded_on date, image_url text, published boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.travel_articles (
 id uuid primary key default gen_random_uuid(), slug text unique not null, title text not null,
 excerpt text, body text, hero_image text, published_at timestamptz,
 published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.site_settings (
 key text primary key, value jsonb not null default '{}'::jsonb,
 updated_at timestamptz not null default now()
);
create table if not exists public.enquiries (
 id uuid primary key default gen_random_uuid(), name text not null,
 phone text not null, email text, destination text, travel_month text,
 travellers integer check (travellers is null or travellers between 1 and 100),
 message text, status text not null default 'new' check (status in ('new','contacted','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

do $$ declare t text; begin
 foreach t in array array['destinations','tour_packages','tour_itinerary_days','gallery_items','testimonials','awards','travel_articles','site_settings','enquiries'] loop
  execute format('drop trigger if exists set_updated_at on public.%I', t);
  execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t);
 end loop;
end $$;

alter table public.destinations enable row level security;
alter table public.tour_packages enable row level security;
alter table public.tour_itinerary_days enable row level security;
alter table public.gallery_items enable row level security;
alter table public.testimonials enable row level security;
alter table public.awards enable row level security;
alter table public.travel_articles enable row level security;
alter table public.site_settings enable row level security;
alter table public.enquiries enable row level security;

create policy "Public can read published destinations" on public.destinations for select to anon, authenticated using (published = true);
create policy "Public can read published packages" on public.tour_packages for select to anon, authenticated using (published = true);
create policy "Public can read itinerary for published packages" on public.tour_itinerary_days for select to anon, authenticated using (exists(select 1 from public.tour_packages p where p.id=package_id and p.published=true));
create policy "Public can read published gallery" on public.gallery_items for select to anon, authenticated using (published = true);
create policy "Public can read published testimonials" on public.testimonials for select to anon, authenticated using (published = true);
create policy "Public can read published awards" on public.awards for select to anon, authenticated using (published = true);
create policy "Public can read published articles" on public.travel_articles for select to anon, authenticated using (published = true);
create policy "Public can read site settings" on public.site_settings for select to anon, authenticated using (true);
-- Public insert is constrained by RLS; pair with Supabase CAPTCHA/Edge Function rate limiting before launch.
create policy "Public can submit enquiries" on public.enquiries for insert to anon, authenticated with check (status = 'new' and length(name) between 2 and 120 and length(phone) between 8 and 30 and (email is null or length(email) <= 254));
-- No public update/delete policies. Restrict content writes and enquiry reads to trusted server/admin roles.
