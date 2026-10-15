-- My Tripon Travel Pvt Ltd — full organized client tour content (CR2–CR6)
-- Prerequisite: 202610150001_client_changes_1_6.sql.
-- Forward-only, idempotent and non-destructive. This migration intentionally
-- leaves every package unpublished and booking-disabled pending client review.

begin;

do $$
declare
  missing_slugs text;
  unexpected_days text;
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
  where d.day_number>expected.max_day;

  if unexpected_days is not null then
    raise exception 'Unexpected existing itinerary rows require manual review; no rows were deleted: %', unexpected_days;
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
  hero_image=source.hero_image,
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
    '/travel/mountain-river-bridge.webp',
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
    'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1600&q=85',
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
    'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1600&q=85',
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
    'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1600&q=85',
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
    'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1600&q=85',
    '["Delhi","Agra","Jaipur","Fatehpur Sikri","Mathura","Amritsar","Attari–Wagah Border"]'::jsonb,
    '["Three-star hotel (client wording: ‘5 days’), twin sharing.","AC pushback Urbania/bus sightseeing.","Delhi–Amritsar train tickets.","Amritsar–Delhi AC Volvo semi-sleeper tickets.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","Taxes, tolls and parking.","Airport or railway pickup and drop."]'::jsonb,
    '["Flights or trains required to reach Delhi.","Anything outside the supplied inclusions.","Costs arising from strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses."]'::jsonb,
    $note$Schedule subject to confirmation: the source heading says 7 Days / 6 Nights, while the supplied itinerary contains Day 1–8 and an overnight bus journey. Age exactly 3 is undefined. The client-supplied 3:15 PM Vande Bharat schedule, Volvo service, room availability, attraction access and Attari–Wagah ceremony time are not verified inventory or guarantees. No automatic checkout.$note$,
    3400000,
    '[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":3400000},{"label":"Below 3 years – free, no bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":2100000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":2900000}]'::jsonb,
    'percentage',0
  )
) source(
  slug,title,duration_days,duration_nights,summary,description,hero_image,
  highlights,inclusions,exclusions,important_information,base_price,age_pricing,
  advance_type,advance_value
)
where p.slug=source.slug;

-- Exact organized day-wise schedules. Descriptions retain every supplied time,
-- stop, conditional arrangement and operational caution without adding inventory.
insert into public.tour_itinerary_days(package_id,day_number,title,description,location)
select p.id,source.day_number,source.title,source.description,source.location
from (values
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
) source(slug,day_number,title,description,location)
join public.tour_packages p on p.slug=source.slug
on conflict(package_id,day_number) do update set
  title=excluded.title,
  description=excluded.description,
  location=excluded.location,
  updated_at=now();

commit;
