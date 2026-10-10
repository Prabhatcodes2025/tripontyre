-- My Tripon Travel - public launch content only.
-- Run after FRESH_SUPABASE_SETUP.sql.
-- No users, customers, testimonials, awards, reviews, bookings, payments,
-- leads, private documents, or other private/transactional records are created.

begin;

-- Dollar-quoted editorial text cannot be broken by apostrophes.
with seed(slug,name,region,country,state,summary,hero_image,featured,published) as (
  values
    ($seed$kerala$seed$,$seed$Kerala$seed$,$seed$Backwaters · South India$seed$,$seed$India$seed$,$seed$Kerala$seed$,$seed$Tea country, old harbour lanes and a quieter rhythm by the water.$seed$,$seed$https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1600&q=85$seed$,true,true),
    ($seed$kashmir$seed$,$seed$Kashmir$seed$,$seed$Mountains · North India$seed$,$seed$India$seed$,$seed$Jammu and Kashmir$seed$,$seed$Lake mornings, mountain air and wide Himalayan views.$seed$,$seed$https://images.unsplash.com/photo-1595815771614-ade9d652a65d?auto=format&fit=crop&w=1600&q=85$seed$,true,true),
    ($seed$rajasthan$seed$,$seed$Rajasthan$seed$,$seed$Heritage · North India$seed$,$seed$India$seed$,$seed$Rajasthan$seed$,$seed$Palaces, old streets, desert landscapes and living craft traditions.$seed$,$seed$https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=1600&q=85$seed$,true,true),
    ($seed$goa$seed$,$seed$Goa$seed$,$seed$Coast · West India$seed$,$seed$India$seed$,$seed$Goa$seed$,$seed$Coastal days, neighbourhood discoveries and an easy pace.$seed$,$seed$https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1600&q=85$seed$,false,true),
    ($seed$bali$seed$,$seed$Bali$seed$,$seed$Island life · Indonesia$seed$,$seed$Indonesia$seed$,null,$seed$Temple courtyards, green highlands and time set aside for the sea.$seed$,$seed$https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1600&q=85$seed$,true,true),
    ($seed$dubai$seed$,$seed$Dubai$seed$,$seed$City & desert · UAE$seed$,$seed$United Arab Emirates$seed$,null,$seed$A modern skyline, neighbourhood culture and open desert beyond the city.$seed$,$seed$https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1600&q=85$seed$,false,true),
    ($seed$thailand$seed$,$seed$Thailand$seed$,$seed$Culture · Southeast Asia$seed$,$seed$Thailand$seed$,null,$seed$Food, culture, coastlines and routes that can move at your pace.$seed$,$seed$https://images.unsplash.com/photo-1508009603885-50cf7c579365?auto=format&fit=crop&w=1600&q=85$seed$,false,true),
    ($seed$maldives$seed$,$seed$Maldives$seed$,$seed$Island escape · Indian Ocean$seed$,$seed$Maldives$seed$,null,$seed$Warm water, long horizons and days designed to move gently.$seed$,$seed$https://images.unsplash.com/photo-1514282401047-d79a71a590e8?auto=format&fit=crop&w=1600&q=85$seed$,false,true),
    -- Historical record retained but no longer promoted as a current offer.
    ($seed$europe$seed$,$seed$Europe$seed$,$seed$Culture · Across Europe$seed$,$seed$Europe$seed$,null,$seed$City streets, regional routes and journeys shaped around your interests.$seed$,$seed$https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=1600&q=85$seed$,false,false)
)
insert into public.destinations(slug,name,region,country,state,summary,hero_image,featured,published)
select slug,name,region,country,state,summary,hero_image,featured,published from seed
on conflict(slug) do update set
  name=excluded.name, region=excluded.region, country=excluded.country,
  state=excluded.state, summary=excluded.summary, hero_image=excluded.hero_image,
  featured=excluded.featured, published=excluded.published;

-- These packages remain enquiry-only until real prices and dated availability
-- are entered. No commercial data is fabricated by this seed.
with seed(
  slug,title,destination_slug,category,duration_days,duration_nights,summary,
  overview,hero_image,trip_style,important_information,featured,published
) as (
  values
    ($seed$kerala-backwaters$seed$,$seed$Backwaters & beyond$seed$,$seed$kerala$seed$,$seed$domestic$seed$,6,5,$seed$Harbour lanes, tea country and a gentle final night on the water.$seed$,$seed$A thoughtfully paced starting point through Kerala, ready to be tailored around the traveller.$seed$,$seed$https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1600&q=85$seed$,$seed$Backwaters & hills$seed$,$seed$Final pricing and inclusions are confirmed in a personal proposal.$seed$,true,true),
    ($seed$kashmir-at-your-pace$seed$,$seed$Kashmir, at your own pace$seed$,$seed$kashmir$seed$,$seed$domestic$seed$,6,5,$seed$Lake mornings and open mountain views, with time to take the longer way.$seed$,$seed$A considered Kashmir route with room to adapt the pace and stops.$seed$,$seed$https://images.unsplash.com/photo-1595815771614-ade9d652a65d?auto=format&fit=crop&w=1600&q=85$seed$,$seed$Mountains & lakes$seed$,$seed$Final pricing and inclusions are confirmed in a personal proposal.$seed$,true,true),
    ($seed$rajasthan-heritage$seed$,$seed$Palaces, pink streets & desert skies$seed$,$seed$rajasthan$seed$,$seed$domestic$seed$,8,7,$seed$Jaipur colour, Jodhpur blue and an evening beneath the desert sky.$seed$,$seed$A heritage-led Rajasthan route that can be adjusted for time and interests.$seed$,$seed$https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=1600&q=85$seed$,$seed$Heritage & culture$seed$,$seed$Final pricing and inclusions are confirmed in a personal proposal.$seed$,true,true),
    ($seed$bali-island-escape$seed$,$seed$A little more Bali$seed$,$seed$bali$seed$,$seed$international$seed$,6,5,$seed$Temple mornings, green highlands and time set aside for the sea.$seed$,$seed$An island route balancing cultural stops, highlands and the coast.$seed$,$seed$https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1600&q=85$seed$,$seed$Island escape$seed$,$seed$Final pricing and inclusions are confirmed in a personal proposal.$seed$,true,true)
)
insert into public.tour_packages(
  slug,title,destination_id,category,duration_days,duration_nights,summary,
  overview,hero_image,trip_style,highlights,inclusions,exclusions,
  important_information,base_price,featured,published,published_at
)
select
  seed.slug,seed.title,d.id,seed.category::public.package_category,
  seed.duration_days,seed.duration_nights,seed.summary,seed.overview,
  seed.hero_image,seed.trip_style,$json$[]$json$::jsonb,$json$[]$json$::jsonb,
  $json$[]$json$::jsonb,seed.important_information,null,seed.featured,
  seed.published,now()
from seed
join public.destinations d on d.slug=seed.destination_slug
on conflict(slug) do update set
  title=excluded.title, destination_id=excluded.destination_id,
  category=excluded.category, duration_days=excluded.duration_days,
  duration_nights=excluded.duration_nights, summary=excluded.summary,
  overview=excluded.overview, hero_image=excluded.hero_image,
  trip_style=excluded.trip_style, highlights=excluded.highlights,
  inclusions=excluded.inclusions, exclusions=excluded.exclusions,
  important_information=excluded.important_information,
  featured=excluded.featured, published=excluded.published,
  published_at=coalesce(tour_packages.published_at,excluded.published_at);

with seed(package_slug,day_number,title,description,location) as (
  values
    ($seed$kerala-backwaters$seed$,1,$seed$Arrive and settle in$seed$,$seed$Find your feet in the old harbour quarter.$seed$,$seed$Kochi$seed$),
    ($seed$kerala-backwaters$seed$,2,$seed$Into tea country$seed$,$seed$Take the scenic road into the hills.$seed$,$seed$Munnar$seed$),
    ($seed$kerala-backwaters$seed$,4,$seed$A slower day$seed$,$seed$Explore spice-country roads and forest edges.$seed$,$seed$Thekkady$seed$),
    ($seed$kerala-backwaters$seed$,6,$seed$Finish by the water$seed$,$seed$Leave room for a quiet backwater evening.$seed$,$seed$Alleppey$seed$),
    ($seed$kashmir-at-your-pace$seed$,1,$seed$Lake morning$seed$,$seed$Arrive and settle into the city at an easy pace.$seed$,$seed$Srinagar$seed$),
    ($seed$kashmir-at-your-pace$seed$,3,$seed$Mountain views$seed$,$seed$Make time for the landscape and a slower afternoon.$seed$,$seed$Gulmarg$seed$),
    ($seed$kashmir-at-your-pace$seed$,5,$seed$Valley roads$seed$,$seed$Follow the route through the valley.$seed$,$seed$Pahalgam$seed$),
    ($seed$rajasthan-heritage$seed$,1,$seed$Pink city arrival$seed$,$seed$Begin among Jaipur’s old streets.$seed$,$seed$Jaipur$seed$),
    ($seed$rajasthan-heritage$seed$,4,$seed$Blue city$seed$,$seed$Continue west through the changing landscape.$seed$,$seed$Jodhpur$seed$),
    ($seed$rajasthan-heritage$seed$,7,$seed$Desert horizon$seed$,$seed$Finish the route near the desert.$seed$,$seed$Jaisalmer$seed$),
    ($seed$bali-island-escape$seed$,1,$seed$A gentle beginning$seed$,$seed$Settle into the island in the cultural heart.$seed$,$seed$Ubud$seed$),
    ($seed$bali-island-escape$seed$,3,$seed$Green highlands$seed$,$seed$Take the slower road through the hills.$seed$,$seed$Sidemen$seed$),
    ($seed$bali-island-escape$seed$,5,$seed$Time for the coast$seed$,$seed$Finish with room for the sea.$seed$,$seed$Uluwatu$seed$)
)
insert into public.tour_itinerary_days(package_id,day_number,title,description,location)
select p.id,seed.day_number,seed.title,seed.description,seed.location
from seed
join public.tour_packages p on p.slug=seed.package_slug
on conflict(package_id,day_number) do update set
  title=excluded.title, description=excluded.description, location=excluded.location;

with seed(slug,name,category,description,service_mode,published) as (
  values
    ($seed$car-rental-transportation$seed$,$seed$Car Rental & Transportation$seed$,$seed$transport$seed$,$seed$Private transfers, intercity travel and local transport planning.$seed$,$seed$enquiry$seed$,true),
    ($seed$corporate-travel$seed$,$seed$Corporate Travel$seed$,$seed$corporate$seed$,$seed$Enquiry-led business travel coordination.$seed$,$seed$enquiry$seed$,true),
    ($seed$mice$seed$,$seed$MICE$seed$,$seed$corporate$seed$,$seed$Meetings, incentives, conferences and event travel planning.$seed$,$seed$enquiry$seed$,true),
    ($seed$hotels-accommodation$seed$,$seed$Hotels & Accommodation$seed$,$seed$stays$seed$,$seed$Stay sourcing within a confirmed itinerary or as a standalone enquiry.$seed$,$seed$enquiry$seed$,true),
    ($seed$visa-assistance$seed$,$seed$Visa Assistance$seed$,$seed$support$seed$,$seed$Process guidance based on destination and traveller profile.$seed$,$seed$enquiry$seed$,true),
    ($seed$travel-insurance$seed$,$seed$Travel Insurance$seed$,$seed$support$seed$,$seed$Provider options can be presented when configured.$seed$,$seed$enquiry$seed$,true)
)
insert into public.travel_services(slug,name,category,description,service_mode,published)
select slug,name,category,description,service_mode,published from seed
on conflict(slug) do update set
  name=excluded.name, category=excluded.category,
  description=excluded.description, service_mode=excluded.service_mode,
  published=excluded.published;

-- hero_slides has no natural UNIQUE constraint, so title prevents duplicate
-- seed rows without modifying the production schema.
with seed(title,subtitle,destination_slug,image_url,alt_text,display_order) as (
  values
    ($seed$Find your kind of beautiful.$seed$,$seed$Lake mornings. Mountain air. A little more time to take it all in.$seed$,$seed$kashmir$seed$,$seed$https://images.unsplash.com/photo-1595815771614-ade9d652a65d?auto=format&fit=crop&w=2200&q=88$seed$,$seed$Kashmir mountain landscape$seed$,1),
    ($seed$Journeys that stay with you.$seed$,$seed$Tea-scented hills, old harbour lanes and a quieter kind of holiday.$seed$,$seed$kerala$seed$,$seed$https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=2200&q=88$seed$,$seed$Kerala landscape$seed$,2),
    ($seed$Slow down. You’re somewhere special.$seed$,$seed$Temple courtyards, green hills and the freedom to follow the day.$seed$,$seed$bali$seed$,$seed$https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=2200&q=88$seed$,$seed$Bali landscape$seed$,3)
)
insert into public.hero_slides(title,subtitle,destination_id,image_url,alt_text,display_order,published)
select seed.title,seed.subtitle,d.id,seed.image_url,seed.alt_text,seed.display_order,true
from seed
join public.destinations d on d.slug=seed.destination_slug
where not exists (
  select 1 from public.hero_slides existing where existing.title=seed.title
);

-- faqs also has no natural UNIQUE constraint, so question text prevents
-- duplicate seed rows on rerun.
with seed(question,answer,category,display_order) as (
  values
    ($seed$Can an itinerary be customized?$seed$,$seed$Yes. Published packages are starting points and the final proposal can be tailored.$seed$,$seed$planning$seed$,1),
    ($seed$Is online payment active?$seed$,$seed$Online payment is available only when the payment provider is configured. The site never simulates a successful charge.$seed$,$seed$planning$seed$,2),
    ($seed$Where are my documents?$seed$,$seed$Issued invoices, vouchers and travel documents appear in the secure customer portal.$seed$,$seed$planning$seed$,3)
)
insert into public.faqs(question,answer,category,display_order,published)
select seed.question,seed.answer,seed.category,seed.display_order,true
from seed
where not exists (
  select 1 from public.faqs existing where existing.question=seed.question
);

with seed(slug,title,excerpt,body_markdown,cover_image) as (
  values
    ($seed$a-slower-way-through-kerala$seed$,$seed$A slower way through Kerala$seed$,$seed$Field notes for shaping a gentler route through Kerala.$seed$,$seed$A Kerala journey can leave room for harbour lanes, tea country and time by the water. The final route should follow your dates, interests and preferred pace.$seed$,$seed$https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1400&q=85$seed$),
    ($seed$what-to-leave-room-for-in-kashmir$seed$,$seed$What to leave room for in Kashmir$seed$,$seed$A destination note about pace, views and time outdoors.$seed$,$seed$A good Kashmir itinerary balances the places you hope to see with enough time to experience the landscape without rushing.$seed$,$seed$https://images.unsplash.com/photo-1595815771614-ade9d652a65d?auto=format&fit=crop&w=1400&q=85$seed$),
    ($seed$bali-beyond-the-first-picture$seed$,$seed$Bali beyond the first picture$seed$,$seed$Ideas for combining culture, highlands and coast.$seed$,$seed$Bali can be shaped as more than one stop: cultural mornings, green highlands and unhurried time near the sea.$seed$,$seed$https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1400&q=85$seed$)
)
insert into public.blogs(slug,title,excerpt,body_markdown,cover_image,published,published_at)
select slug,title,excerpt,body_markdown,cover_image,true,now() from seed
on conflict(slug) do update set
  title=excluded.title, excerpt=excluded.excerpt,
  body_markdown=excluded.body_markdown, cover_image=excluded.cover_image,
  published=excluded.published,
  published_at=coalesce(blogs.published_at,excluded.published_at);

with seed(section_key,title,content,display_order) as (
  values
    ($seed$homepage_welcome$seed$,$seed$We help shape the stories you’ll bring home.$seed$,jsonb_build_object($seed$eyebrow$seed$,$seed$Explore · Experience · Enjoy$seed$,$seed$copy$seed$,$seed$Thoughtful routes, practical details and breathing room around the holiday you want to have.$seed$),10),
    ($seed$homepage_approach$seed$,$seed$Your holiday deserves more than a template.$seed$,jsonb_build_object($seed$copy$seed$,$seed$Good planning starts with listening, then brings the details together around your people and pace.$seed$),20)
)
insert into public.site_sections(section_key,title,content,display_order,published)
select section_key,title,content,display_order,true from seed
on conflict(section_key) do update set
  title=excluded.title, content=excluded.content,
  display_order=excluded.display_order, published=excluded.published;

-- Canonical public company details used by the Footer and Site Settings modules.
insert into public.site_settings(key,value)
values (
  'company_contact',
  jsonb_build_object(
    'public', true,
    'legalName', 'My Tripon Travel Pvt. Ltd.',
    'corporateOffice', jsonb_build_object('address','Mahipalpur, Delhi - 110037','phone','7592999111'),
    'kozhikodeOffice', jsonb_build_object('address','Sky Tower, Major Road Junction, Kozhikode','phone','7592883311'),
    'additionalOffices', jsonb_build_array('Bengaluru','Hyderabad','Mumbai'),
    'email', 'infomytripontravel@gmail.com'
  )
)
on conflict(key) do update set value=excluded.value,updated_at=now();

-- No events are inserted: public event listings must represent real,
-- confirmed dates supplied by My Tripon Travel.

commit;
