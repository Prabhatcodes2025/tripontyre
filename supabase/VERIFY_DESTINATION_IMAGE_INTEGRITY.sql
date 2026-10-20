-- Read-only destination/package image audit. Safe to run before or after
-- 202610200001_destination_image_integrity.sql.
-- Expected after migration: result sets 1, 2, 3 and 4 return zero rows.

-- 1. Unresolved audited placeholder mappings.
with image_uses as (
  select 'destination'::text as source,slug,name as label,hero_image as image_url
  from public.destinations
  union all
  select 'package',slug,title,hero_image
  from public.tour_packages
)
select source,slug,label,image_url
from image_uses
where (image_url='/travel/tulip-garden.webp'
       and concat_ws(' ',slug,label) !~* '(kashmir|tulip)')
   or image_url in (
        '/travel/mountain-river-bridge.webp',
        '/travel/nusa-penida.webp',
        '/travel/beach-reflections.webp'
      )
order by source,slug;

-- 2. Missing or still-legacy records among all 39 corrected destination slugs.
with expected(slug) as (select unnest(array[
  'agumbe','ajanta-ellora','andaman',
  'ayodhya-kashi-prayagraj-gaya-bodh-gaya','azerbaijan','bangalore-mysore-kodagu',
  'bhutan','bijapur-hampi-badami-aihole-pattadakkal-chitradurga','chikmagalur',
  'delhi-agra-jaipur-amritsar-wagah-border','gujarat','hampi','hyderabad','jog-falls',
  'kerala-full','kolkata','malaysia-singapore','matheran','meghalaya','mumbai',
  'munnar-thekkady-kochi-alappuzha-kumarakom-varkala-kovalam',
  'munnar-thekkady-vagamon-kochi-athirappalli','nepal','odisha','ooty-mysore',
  'rameswaram-dhanushkodi-madurai-kodaikanal','sikkim-darjeeling','sri-lanka',
  'vagamon','valparai-athirappalli','wayanad','kashmir-kargil','kasol',
  'kullu-manali-kasol','ladakh','bali-nusa-penida','indonesia','gokarna','lakshadweep'
]::text[])), image_rows as (
  select e.slug,'destination'::text as source,d.hero_image as image_url
  from expected e left join public.destinations d on d.slug=e.slug
  union all
  select e.slug,'package',p.hero_image
  from expected e
  left join public.destinations d on d.slug=e.slug
  left join public.tour_packages p on p.slug=e.slug or p.destination_id=d.id
)
select slug,source,image_url
from image_rows
where image_url is null
   or image_url in (
        '/travel/tulip-garden.webp','/travel/mountain-river-bridge.webp',
        '/travel/nusa-penida.webp','/travel/beach-reflections.webp'
      )
order by slug,source;

-- 3. A destination image reused by more than one unrelated destination.
with normalized as (
  select slug,hero_image,
         lower(regexp_replace(split_part(coalesce(hero_image,''),'?',1),'/+$','')) as image_key
  from public.destinations
  where nullif(btrim(hero_image),'') is not null
)
select image_key,count(*) as destination_count,array_agg(slug order by slug) as slugs
from normalized
group by image_key
having count(*)>1
order by destination_count desc,image_key;

-- 4. Tulip imagery carrying an incorrect Agumbe label in the gallery.
select id,title,alt_text,media_url
from public.gallery_items
where media_type='image' and media_url ilike '%tulip%'
  and (title ilike '%agumbe%' or alt_text ilike '%agumbe%')
order by created_at,id;
