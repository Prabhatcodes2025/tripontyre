-- Read-only verification for CR1–CR6. Run after all migrations complete.
-- Every result should be reviewed; this file performs no writes.

-- 1. Package identity, safety state, money (minor INR units) and images.
select id,slug,title,duration_days,duration_nights,base_price,currency,
       advance_type,advance_value,age_pricing,hero_image,published,
       booking_enabled,published_at
from public.tour_packages
where slug in (
  'kashmir-kargil',
  'delhi-agra-jaipur-golden-triangle-tour',
  'delhi-agra-mathura-jaipur-tour',
  'delhi-agra-tour',
  'delhi-agra-jaipur-amritsar-wagah-border'
)
order by slug;

-- Expected: exactly five rows; every published/booking_enabled is false;
-- Kashmir advance_value is 1000000 (₹10,000 in paise).
select count(*) as package_count,
       count(*) filter(where published=false and booking_enabled=false) as safely_held_count,
       count(*) filter(where published_at is null) as unpublished_timestamp_count
from public.tour_packages
where slug in (
  'kashmir-kargil',
  'delhi-agra-jaipur-golden-triangle-tour',
  'delhi-agra-mathura-jaipur-tour',
  'delhi-agra-tour',
  'delhi-agra-jaipur-amritsar-wagah-border'
);

-- 2. Expected itinerary counts: 5 + 5 + 6 + 3 + 8 = 27.
with expected(slug,expected_days) as (values
  ('kashmir-kargil',5),
  ('delhi-agra-jaipur-golden-triangle-tour',5),
  ('delhi-agra-mathura-jaipur-tour',6),
  ('delhi-agra-tour',3),
  ('delhi-agra-jaipur-amritsar-wagah-border',8)
)
select expected.slug,expected.expected_days,count(d.id) as actual_days,
       min(d.day_number) as first_day,max(d.day_number) as last_day
from expected
join public.tour_packages p on p.slug=expected.slug
left join public.tour_itinerary_days d on d.package_id=p.id
group by expected.slug,expected.expected_days
order by expected.slug;

-- Expected: zero rows (no missing or extra day numbers).
with expected(slug,expected_days) as (values
  ('kashmir-kargil',5),
  ('delhi-agra-jaipur-golden-triangle-tour',5),
  ('delhi-agra-mathura-jaipur-tour',6),
  ('delhi-agra-tour',3),
  ('delhi-agra-jaipur-amritsar-wagah-border',8)
), expected_numbers as (
  select expected.slug,generate_series(1,expected.expected_days) as day_number from expected
), actual as (
  select p.slug,d.day_number
  from public.tour_packages p
  join public.tour_itinerary_days d on d.package_id=p.id
  join expected on expected.slug=p.slug
)
select 'missing' as issue,e.slug,e.day_number from expected_numbers e
left join actual a using(slug,day_number) where a.day_number is null
union all
select 'extra',a.slug,a.day_number from actual a
left join expected_numbers e using(slug,day_number) where e.day_number is null
order by slug,day_number;

-- Expected: zero rows (the ON CONFLICT key is unique).
select package_id,day_number,count(*) as duplicate_count
from public.tour_itinerary_days
group by package_id,day_number
having count(*)>1;

-- 3. Review complete day content in display order.
select p.slug,d.day_number,d.title,d.location,d.description
from public.tour_packages p
join public.tour_itinerary_days d on d.package_id=p.id
where p.slug in (
  'kashmir-kargil',
  'delhi-agra-jaipur-golden-triangle-tour',
  'delhi-agra-mathura-jaipur-tour',
  'delhi-agra-tour',
  'delhi-agra-jaipur-amritsar-wagah-border'
)
order by p.slug,d.day_number;

-- 4. Confirm unresolved approvals remain present in the stored notes.
select slug,important_information,inclusions,exclusions
from public.tour_packages
where slug in (
  'kashmir-kargil',
  'delhi-agra-jaipur-golden-triangle-tour',
  'delhi-agra-mathura-jaipur-tour',
  'delhi-agra-tour',
  'delhi-agra-jaipur-amritsar-wagah-border'
)
order by slug;

-- 5. Contact setting and the narrowly targeted Tulip correction.
select key,value from public.site_settings where key='company_contact';
select id,slug,title,media_url,alt_text,published
from public.gallery_items
where media_type='image' and (media_url ilike '%tulip%' or title ilike '%agumbe%' or alt_text ilike '%agumbe%')
order by created_at;

-- 6. Confirm the server function enforces both publication and booking switch.
select pg_get_functiondef('public.create_booking_secure(text,date,jsonb,text,uuid)'::regprocedure);
