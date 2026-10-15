-- Client change requests 1-6: non-destructive catalogue/contact preparation.
-- The five packages remain unpublished and non-bookable until the original
-- itinerary/inclusion/exclusion copy is supplied and reviewed.

alter type public.package_category add value if not exists 'strangers_meetup';
alter type public.package_category add value if not exists 'custom';

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

