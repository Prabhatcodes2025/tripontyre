-- Read-only verification for CR8-CR12. Run after the migration and review the output.
with expected(slug,expected_days) as (
  values
    ('delhi-agra-amritsar-tour',5),
    ('rajasthan',7),
    ('kashmir-kargil-dhooth-pathri-tour',6),
    ('delhi-kullu-manali-tour',4),
    ('kullu-manali-kasol',5)
)
select
  p.slug,
  p.title,
  p.duration_days,
  p.duration_nights,
  p.base_price,
  jsonb_array_length(p.age_pricing) as price_band_count,
  jsonb_array_length(p.inclusions) as inclusion_count,
  jsonb_array_length(p.exclusions) as exclusion_count,
  count(i.id) as itinerary_day_count,
  array_agg(i.day_number order by i.day_number) as itinerary_day_labels,
  p.published,
  p.booking_enabled,
  count(i.id)=expected.expected_days as day_count_ok,
  (not p.published and not p.booking_enabled) as safety_flags_ok
from expected
join public.tour_packages p using(slug)
left join public.tour_itinerary_days i on i.package_id=p.id
group by p.id,expected.expected_days
order by p.slug;

-- Must return zero rows: no CR8-CR12 package may be bookable or public yet.
select slug,title,published,booking_enabled
from public.tour_packages
where slug in (
  'delhi-agra-amritsar-tour','rajasthan','kashmir-kargil-dhooth-pathri-tour',
  'delhi-kullu-manali-tour','kullu-manali-kasol'
)
and (published or booking_enabled);
