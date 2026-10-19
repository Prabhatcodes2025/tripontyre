-- Client change requests 8-12: five complete, distinct tour records.
-- Prerequisites: all migrations through 202610180002_cr7_catalogue_corrections.sql.
-- Forward-only, idempotent and non-destructive. Existing bookings, payments,
-- leads, media and unrelated CMS content are not deleted or reassigned.

begin;

drop table if exists pg_temp.client_cr8_12_packages;
create temporary table pg_temp.client_cr8_12_packages (
  slug text primary key,
  title text not null,
  destination_slug text,
  placeholder_title text,
  duration_days integer not null,
  duration_nights integer not null,
  summary text not null,
  description text not null,
  highlights jsonb not null,
  inclusions jsonb not null,
  exclusions jsonb not null,
  important_information text not null,
  base_price integer,
  age_pricing jsonb not null,
  advance_type text not null,
  advance_value integer not null
) on commit preserve rows;

insert into pg_temp.client_cr8_12_packages values
(
  'delhi-agra-amritsar-tour',
  'Delhi–Agra–Amritsar Tour',null,null,5,4,
  'A 5-day/4-night Delhi, Agra and Amritsar tour with Vande Bharat travel to Amritsar and an overnight AC Volvo return to Delhi.',
  'Client-supplied Delhi, Agra and Amritsar itinerary covering Akshardham, Agra Fort, Taj Mahal, Delhi monuments, Golden Temple, Jallianwala Bagh, Attari–Wagah Border and Sarojini Market.',
  $json$["Delhi","Agra","Amritsar"]$json$::jsonb,
  $json$["3 days accommodation at three-star-category hotels; one bedroom for one family / two sharing.","5 breakfasts, 5 lunches and 4 dinners (vegetarian and non-vegetarian).","AC pushback-seat 27-seater bus for sightseeing.","Vande Bharat train tickets to Amritsar.","AC Volvo semi-sleeper tickets from Amritsar to Delhi.","All entry tickets worth around ₹2,000 per person (client-stated amount).","Malayali tour manager and tour guide.","All taxes, tolls and parking charges.","Two mineral-water bottles per day per person.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets from Kerala to Delhi and return.","Meals other than those mentioned in the inclusions.","Camera tickets or other additional charges.","Loss caused by flight or train cancellation or delay.","Loss caused by natural calamities, hartals, strikes or bandhs.","Medical expenses, if any."]$json$::jsonb,
  $note$Age exactly 3 is not priced in the source. The source states 3 days of hotel accommodation within a 5-day/4-night tour and uses a hotel for freshening up on Day 5; the precise room/night allocation requires confirmation. The client-supplied 3:15 PM Vande Bharat timing, attraction access, ticket values and transport schedules require operational verification. No package image was supplied. Keep unpublished and booking-disabled until reviewed.$note$,
  2450000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2450000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":1100000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1800000}]$json$::jsonb,
  'percentage',50
),
(
  'rajasthan',
  'Rajasthan Tour','rajasthan','Rajasthan',7,6,
  'A 7-day/6-night Udaipur-to-Jaipur land package through Jodhpur, Jaisalmer, Pushkar and Ajmer.',
  'Client-supplied Rajasthan land itinerary with Udaipur pickup and Jaipur drop, including a Sam Sand Dunes desert-tent stay.',
  $json$["Udaipur","Jodhpur","Jaisalmer","Ajmer","Pushkar","Jaipur"]$json$::jsonb,
  $json$["Three-star hotel stay for 6 days, two-sharing basis.","AC pushback-seat Urbania / bus for sightseeing.","All meals.","All entry tickets worth around ₹5,000+ (client-stated amount).","Tour manager and guide.","Two mineral-water bottles per day per person.","All taxes, tolls and parking charges.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets to reach Rajasthan and return.","Anything not included in the package inclusions.","Unexpected expenses caused by strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses, etc."]$json$::jsonb,
  $note$Package price, age-wise prices and booking advance were not supplied; show Enquire for Price and do not enable checkout. The source calls this a 7-day/6-night tour but describes the hotel inclusion as “6 days”; confirm the exact hotel-night allocation. Early Udaipur check-in is subject to room availability. The source does not specify individual sightseeing times for several grouped stops. No package image was supplied; retain existing CMS media.$note$,
  null,$json$[]$json$::jsonb,'percentage',0
),
(
  'kashmir-kargil-dhooth-pathri-tour',
  'Kashmir–Kargil–Dhooth Pathri Tour','kashmir-kargil',null,6,5,
  'A June–November Kashmir, Kargil and Dhooth Pathri tour supplied as 6 days/5 nights but containing Day 1–7 with Day 4 missing.',
  'Client-supplied seasonal itinerary covering Srinagar, Sonmarg, Drass, Kargil LOC, Pahalgam, Gulmarg and Dhooth Pathri, subject to route, weather and access conditions.',
  $json$["Srinagar","Gulmarg","Pahalgam","Sonmarg","Drass","Zero Point","Kargil War Memorial","Kargil LOC","Dhooth Pathri"]$json$::jsonb,
  $json$["Delhi–Srinagar return economy-class flight tickets.","Three-star-category hotel accommodation for 4 days: one day at Kargil and three days at Srinagar; one bedroom for one family / two sharing; breakfast and dinner at hotel.","AC bus for sightseeing.","All entry tickets, including Gondola Cable Car Phase 1 worth around ₹1,000 per person (client-stated amount).","All meals: vegetarian breakfast, vegetarian lunch, and vegetarian and non-vegetarian dinner.","Two mineral-water bottles per day per person.","Local union taxi charges at Pahalgam, Sonmarg and Kargil.","Srinagar Airport pickup and drop.","All taxes, tolls and parking fees.","Malayali tour guide and manager."]$json$::jsonb,
  $json$["Additional expenses not included in the package inclusions.","Gondola Cable Car Phase 2 ticket charges.","Expenses caused by natural calamities, strikes or bandhs.","Expenses caused by flight cancellation or delay.","Food on the flight or at airports.","Transportation to Delhi Airport and from the airport."]$json$::jsonb,
  $note$Schedule subject to confirmation: the heading says 6 Days / 5 Nights, the source contains Day 1, 2, 3, 5, 6 and 7, and Day 4 is absent. Do not invent Day 4. Age exactly 3 and the booking advance are not supplied. The source states June–November only and says the Kargil route is closed from the last week of November to May; all route and access claims require operational verification. Hotel inclusion says 4 days and requires reconciliation with the advertised duration. The source document footer names another agency; content rights and attribution must be confirmed before publication. No package image was supplied. Keep unpublished and booking-disabled.$note$,
  2600000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2600000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":600000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1600000}]$json$::jsonb,
  'percentage',0
),
(
  'delhi-kullu-manali-tour',
  'Delhi–Kulu–Manali Tour','kullu-manali-kasol',null,4,3,
  'A 4-day/3-night Delhi, Kulu and Manali tour with Atal Tunnel, Rohtang Pass when permitted, Solang Valley and overnight bus travel.',
  'Client-supplied Delhi, Kulu and Manali itinerary covering Delhi sightseeing, Manali local sightseeing, Solang Valley and Kulu.',
  $json$["Delhi","Kulu","Manali","Atal Tunnel","Rohtang Pass"]$json$::jsonb,
  $json$["Three-star hotel stay for 2 days, two-sharing basis.","AC pushback-seat Urbania / bus for sightseeing.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","All taxes, tolls and parking charges.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets to reach Delhi.","Anything not included in the package inclusions.","Unexpected expenses caused by strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses, etc."]$json$::jsonb,
  $note$Age exactly 3 and the booking advance are not supplied. The source advertises 4 Days / 3 Nights, includes overnight bus travel after Day 4 and expects Delhi arrival around 5:00 AM on the following day; confirm how this is presented commercially. The hotel inclusion says 2 days and requires confirmation. Rohtang Pass is conditional on permission/opening. The source lists optional adventure activities but does not state whether their charges are included. No package image was supplied. Keep unpublished and booking-disabled.$note$,
  2200000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2200000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – bus seat without bed","min_age":4,"max_age":6,"price":600000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":1700000}]$json$::jsonb,
  'percentage',0
),
(
  'kullu-manali-kasol',
  'Delhi–Kulu–Manali & Kasol Tour','kullu-manali-kasol','Kullu - Manali - Kasol',5,4,
  'A 5-day/4-night Delhi, Kulu, Manali and Kasol tour with Atal Tunnel, Rohtang Pass when permitted, Solang Valley and overnight bus travel.',
  'Client-supplied Delhi, Kulu, Manali and Kasol itinerary covering Delhi sightseeing, Manali, Solang Valley, Kasol, Manikaran and Kulu.',
  $json$["Delhi","Kulu","Manali","Atal Tunnel","Rohtang Pass","Kasol"]$json$::jsonb,
  $json$["Three-star hotel stay for 3 days, two-sharing basis.","AC pushback-seat Urbania / bus for sightseeing.","All meals.","All entry tickets.","Tour manager and guide.","Two mineral-water bottles per day per person.","All taxes, tolls and parking charges.","Airport or railway-station pickup and drop."]$json$::jsonb,
  $json$["Flight or train tickets to reach Delhi.","Anything not included in the package inclusions.","Unexpected expenses caused by strikes, hartals, bandhs or natural calamities.","Personal expenses.","Medical expenses, etc."]$json$::jsonb,
  $note$Age exactly 3 and the booking advance are not supplied. The age 4–6 condition says “seat in bus. Without bus”; preserve this wording and obtain client clarification before any automated charge. The source advertises 5 Days / 4 Nights, includes overnight bus travel after Day 5 and expects Delhi arrival around 5:00 AM on the following day; confirm the commercial duration. The hotel inclusion says 3 days and requires confirmation. Rohtang Pass is conditional on permission/opening. The source lists optional adventure activities but does not state whether their charges are included. No new package image was supplied; retain existing CMS media. Keep unpublished and booking-disabled.$note$,
  2900000,
  $json$[{"label":"Adult / above 14","min_age":15,"max_age":null,"price":2900000},{"label":"Below 3 years – free, no separate bus seat","min_age":0,"max_age":2,"price":0},{"label":"Age 4–6 – ‘seat in bus. Without bus’ (client wording; clarification required)","min_age":4,"max_age":6,"price":700000},{"label":"Age 7–14 – with bed","min_age":7,"max_age":14,"price":2100000}]$json$::jsonb,
  'percentage',0
);

-- Abort rather than silently replace a non-placeholder/Admin-authored package.
do $$
declare conflicts text;
begin
  select string_agg(existing.slug, ', ' order by existing.slug)
  into conflicts
  from public.tour_packages existing
  join pg_temp.client_cr8_12_packages source on source.slug=existing.slug
  where not (
    (source.placeholder_title is not null
      and existing.title=source.placeholder_title
      and existing.summary='Details coming soon. Contact My Tripon Travel to register your interest.'
      and existing.base_price is null
      and existing.age_pricing='[]'::jsonb
      and not exists(select 1 from public.tour_itinerary_days d where d.package_id=existing.id))
    or
    (existing.title=source.title
      and existing.duration_days=source.duration_days
      and existing.duration_nights=source.duration_nights
      and existing.summary=source.summary
      and existing.description=source.description
      and existing.highlights=source.highlights
      and existing.inclusions=source.inclusions
      and existing.exclusions=source.exclusions
      and existing.important_information=source.important_information
      and existing.base_price is not distinct from source.base_price
      and existing.age_pricing=source.age_pricing
      and existing.advance_type=source.advance_type
      and existing.advance_value=source.advance_value
      and existing.booking_enabled=false
      and existing.published=false)
  );

  if conflicts is not null then
    raise exception 'CR8-CR12 package rows contain non-placeholder/Admin content. Export and review before replacement: %', conflicts;
  end if;
end $$;

insert into public.tour_packages(
  slug,title,destination_id,category,duration_days,duration_nights,summary,overview,description,
  hero_image,trip_style,highlights,inclusions,exclusions,important_information,base_price,
  child_price,infant_price,age_pricing,advance_type,advance_value,currency,is_upcoming,
  booking_enabled,published,published_at
)
select source.slug,source.title,d.id,'domestic'::public.package_category,source.duration_days,source.duration_nights,
  source.summary,source.description,source.description,d.hero_image,'Guided domestic group tour',
  source.highlights,source.inclusions,source.exclusions,source.important_information,source.base_price,
  null,null,source.age_pricing,source.advance_type,source.advance_value,'INR',false,false,false,null
from pg_temp.client_cr8_12_packages source
left join public.destinations d on d.slug=source.destination_slug
on conflict(slug) do update set
  title=excluded.title,
  destination_id=coalesce(excluded.destination_id,public.tour_packages.destination_id),
  category=excluded.category,
  duration_days=excluded.duration_days,
  duration_nights=excluded.duration_nights,
  summary=excluded.summary,
  overview=excluded.overview,
  description=excluded.description,
  hero_image=coalesce(public.tour_packages.hero_image,excluded.hero_image),
  trip_style=excluded.trip_style,
  highlights=excluded.highlights,
  inclusions=excluded.inclusions,
  exclusions=excluded.exclusions,
  important_information=excluded.important_information,
  base_price=excluded.base_price,
  child_price=null,
  infant_price=null,
  age_pricing=excluded.age_pricing,
  advance_type=excluded.advance_type,
  advance_value=excluded.advance_value,
  currency='INR',
  is_upcoming=false,
  booking_enabled=false,
  published=false,
  published_at=null,
  updated_at=now();

-- Prevent the earlier generic Rajasthan seed from appearing as a second offer.
-- Its content remains recoverable and is not deleted.
update public.tour_packages
set booking_enabled=false,published=false,published_at=null,updated_at=now()
where slug='rajasthan-heritage';

drop table if exists pg_temp.client_cr8_12_itinerary;
create temporary table pg_temp.client_cr8_12_itinerary (
  slug text not null,
  day_number integer not null,
  title text not null,
  description text not null,
  location text not null,
  primary key(slug,day_number)
) on commit preserve rows;

insert into pg_temp.client_cr8_12_itinerary values
('delhi-agra-amritsar-tour',1,'Delhi, Akshardham and Agra',$day$6:00 AM — Start from Delhi.
8:00 AM — Akshardham Temple. Swaminarayan Akshardham in Delhi is a newly constructed divine centre famous for its stunning architectural wonder. Spend one hour here.
12:30 PM — Lunch in Agra.
1:30 PM — Agra Fort. It was built by Mughal emperors, and the present construction of the fort was renovated in Akbar’s period. It is similar to the Red Fort in Delhi, so it is also called “Agra’s Red Fort”. Spend one hour at Agra Fort.
3:30 PM — Taj Mahal. The Taj Mahal is one of the Seven Wonders of the World and one of India’s UNESCO World Heritage properties. “The Taj” is described as a legend of an emperor’s eternal love for his favourite queen. Mughal emperor Shah Jahan built it for his favourite wife, Mumtaz Mahal. It was constructed from 1631 to 1653 and is an ivory-white marble mausoleum on the bank of the Yamuna River. The tombs of Shah Jahan and Mumtaz Mahal are at the Taj Mahal. The best time to visit is early morning or evening. Stay until sunset.
7:00 PM — Depart toward Delhi.
9:00 PM — Dinner on the way.
11:30 PM — Check in at the Delhi hotel; overnight stay.$day$,'Delhi · Agra'),
('delhi-agra-amritsar-tour',2,'Delhi sightseeing',$day$7:30 AM — Breakfast.
8:00 AM — Leave the hotel for sightseeing.
9:00 AM — Qutub Minar. Qutub Minar was built from 1199 to 1220 as a victory tower. Qutb-ud-din Aibak started its construction in 1199 after the victory against Prithviraj Chauhan, and his successor Iltutmish completed it. It is one of India’s UNESCO World Heritage properties and a pride of Delhi.
10:30 AM — Lotus Temple.
12:00 noon — Teen Murti Bhavan. The source says it is now known as the Prime Minister’s Home and was the Nehru family’s house. Visitors can see rooms used by Jawaharlal Nehru from childhood onward. It was a place where many national leaders and British rulers held meetings.
1:00 PM — Lunch.
2:00 PM — Birla House. It is the place where Mahatma Gandhi was shot. Visit Gandhi’s ashram, where he spent his last days.
3:00 PM — Indira Gandhi Museum. It is a museum at the house in front of which Indira Gandhi was shot.
4:00 PM — Raj Ghat / Samadhi Sthal. Raj Ghat is Mahatma Gandhi’s memorial. Visit the memorials of Jawaharlal Nehru, Indira Gandhi, Rajiv Gandhi, Lal Bahadur Shastri and Atal Bihari Vajpayee, among others.
5:30 PM — Outside view of the new and old Parliament buildings and Rashtrapati Bhavan.
6:00 PM — India Gate. Formerly known as the All India War Memorial, it is a 42-metre-high war memorial in New Delhi designed by Sir Edwin Lutyens. It honours more than 70,000 Indian and British soldiers who died in the World War. Spend the evening at India Gate and travel along the roads where the Independence Day and Republic Day parades are held.
8:30 PM — Reach the hotel.
9:00 PM — Dinner; overnight stay.$day$,'Delhi'),
('delhi-agra-amritsar-tour',3,'South Delhi and train to Amritsar',$day$7:30 AM — Breakfast.
8:00 AM — Check out from the hotel.
9:00 AM — Humayun’s Tomb. It is listed among India’s UNESCO World Heritage properties. It is a mausoleum commissioned in 1558 by Empress Bega Begum.
11:00 AM — Red Fort. It is a historic Mughal fort in Old Delhi and was the main residence of Mughal emperors. Shah Jahan commissioned it in 1639. On 15 August 1947, India’s first Prime Minister, Jawaharlal Nehru, hoisted the Indian flag at the main entrance. Since then, every Prime Minister of India has ceremonially raised the national flag at the main gate on Independence Day.
1:00 PM — Lunch.
3:00 PM — Head toward Amritsar.
3:15 PM — Vande Bharat train to Amritsar (client-supplied time; verify the operating schedule).
8:30 PM — Reach Amritsar.
9:00 PM — Hotel check-in.
9:30 PM — Dinner; overnight stay.$day$,'Delhi · Amritsar'),
('delhi-agra-amritsar-tour',4,'Amritsar and Attari–Wagah Border',$day$7:30 AM — Breakfast.
8:00 AM — Golden Temple. It is a famous gurudwara in Amritsar and spiritually the most significant shrine in Sikhism. Spend at least two hours here; it may take up to four hours depending on the queue to enter.
11:00 AM — Jallianwala Bagh. Also associated with the “Amritsar Massacre”, it took place on 13 April 1919. People gathered there to protest against the Rowlatt Act, after which General Dyer surrounded them and fired. Jallianwala Bagh had only one exit, with buildings surrounding all other sides. The source states that more than 1,500 Indian freedom fighters were killed and more than 1,200 were seriously injured; these figures require editorial verification. It was a shocking incident in the history of India’s freedom struggle. Spend one hour at Jallianwala Bagh.
1:00 PM — Lunch.
2:00 PM — Depart toward Attari–Wagah Border.
4:00 PM — Attari–Wagah Border. The source describes Attari as the only official road crossing between India and Pakistan and as world-famous for its daily Beating Retreat flag-lowering ceremony.
5:30 PM — Flag-lowering ceremony at Wagah Border. Witness a one-hour display of military precision, patriotism and rivalry jointly performed by the Indian Border Security Force (BSF) and the Pakistan Rangers. The border gate then remains closed for the day.
7:00 PM — Return to Amritsar.
8:30 PM — Dinner and shopping time.
10:30 PM — AC Volvo semi-sleeper bus to Delhi; overnight on the bus.$day$,'Amritsar · Attari–Wagah Border'),
('delhi-agra-amritsar-tour',5,'Delhi departure',$day$6:00 AM — Reach Delhi.
7:30 AM — Hotel check-in for freshening up.
9:00 AM — Breakfast.
9:30 AM — Check out with all luggage.
10:30 AM — Shopping at Sarojini Market; allow three hours.
1:30 PM — Lunch.
2:00 PM — Drop at Delhi Airport Terminal 1, 2 or 3 depending on the flight.$day$,'Delhi'),

('rajasthan',1,'Udaipur arrival and sightseeing',$day$Arrive in Udaipur by flight, train or bus; select a service reaching on or before 10:00 AM.
Pickup from the airport, railway station or bus stand.
Hotel check-in and freshening up; early check-in is subject to room availability.
Udaipur sightseeing: City Palace, Lake Pichola, Jagmandir Palace, Saheliyon Ki Bari, Fateh Sagar Lake, Shilpagram and Maharana Pratap Smarak.
7:00 PM — Shopping at the local market.
9:00 PM — Dinner; overnight at the hotel.$day$,'Udaipur'),
('rajasthan',2,'Udaipur to Jodhpur',$day$7:00 AM — Breakfast.
7:30 AM — Hotel checkout and depart toward Jodhpur.
The client estimates four to five hours for the journey.
12:30 PM — Expected arrival in Jodhpur and hotel check-in.
1:00 PM — Lunch.
2:00 PM — Jodhpur local sightseeing: Umaid Bhawan Palace and Museum, Mehrangarh Fort, Jaswant Thada and Sardar Market.
8:30 PM — Dinner; overnight at the Jodhpur hotel.$day$,'Udaipur · Jodhpur'),
('rajasthan',3,'Jodhpur to Jaisalmer and Sam Sand Dunes',$day$7:00 AM — Breakfast.
7:30 AM — Hotel checkout and depart toward Jaisalmer.
The client estimates five to six hours for the journey.
Visit Jaisalmer War Museum, located 10 km before Jaisalmer on the Jodhpur–Jaisalmer National Highway, and Gadisar Lake.
2:00 PM — Lunch.
3:00 PM — Jaisalmer / Thar Desert. Camel ride on Sam Sand Dunes and sunset view in the Thar Desert.
Check in at a desert tent at Sam Sand Dunes.
8:00 PM — Dinner; overnight in the tent.$day$,'Jodhpur · Jaisalmer · Sam Sand Dunes'),
('rajasthan',4,'Jaisalmer sightseeing and Pushkar transfer',$day$8:00 AM — Breakfast.
8:30 AM — Check out from the tent stay.
Jaisalmer sightseeing: Jaisalmer Fort, Patwon Ki Haveli and Sonar Kella.
1:00 PM — Lunch.
Visit Nathmal Ki Haveli and Salim Singh Ki Haveli.
Evening departure toward Pushkar; the client estimates five to six hours.
11:00 PM — Hotel check-in; overnight stay.$day$,'Jaisalmer · Pushkar'),
('rajasthan',5,'Pushkar, Ajmer and Jaipur',$day$8:00 AM — Breakfast.
Pushkar sightseeing: Brahma Temple and Brahma Sarovar Lake.
1:00 PM — Lunch.
Afternoon — Ajmer Dargah.
Evening — Depart toward Jaipur and shop in Jaipur.
8:00 PM — Dinner; overnight in Jaipur.$day$,'Pushkar · Ajmer · Jaipur'),
('rajasthan',6,'Jaipur sightseeing',$day$7:30 AM — Breakfast.
Jaipur sightseeing: Jantar Mantar, Hawa Mahal, Albert Hall and Museum, Birla Mandir and city tour.
Shopping at Johari Bazaar.
9:00 PM — Dinner; overnight at the Jaipur hotel.$day$,'Jaipur'),
('rajasthan',7,'Jaipur sightseeing and departure',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout.
Jaipur local sightseeing: Amber Fort (Amar Fort), Panna Meena Kund and Water Palace (Jal Mahal).
2:00 PM — Lunch.
Visit City Palace.
4:30 PM — Drop at Jaipur Airport, railway station or bus stand.$day$,'Jaipur'),

('kashmir-kargil-dhooth-pathri-tour',1,'Srinagar, Sonmarg, Drass and Kargil',$day$9:00 AM — Meet and greet at Srinagar Airport; the tour manager joins the group. Freshening up and breakfast.
11:45 AM — Depart directly for Sonmarg.
1:00 PM — River Sindhu.
2:00 PM — Lunch.
3:00 PM — Sonmarg Tunnel; spend one hour at Sonmarg.
Then take the thrilling journey through Zojila Pass, described in the source as the world’s third-highest motorable pass. Zojila Pass, Drass, Zero Point and Kargil can be visited only if Zojila Pass is open to tourists. The source says it is currently open but may close because of heavy snowfall, landslides or natural calamities. In that case, return from Sonmarg and stay in Srinagar.
5:00 PM — Captain Mod Point.
6:00 PM — Zero Point. The source describes it as the world’s second-coldest place after Siberia; verify this claim before publication. Spend 30 minutes at Zero Point.
7:00 PM — Drass.
8:30 PM — Reach Kargil.
9:00 PM — Dinner; overnight in Kargil.$day$,'Srinagar · Sonmarg · Zojila Pass · Zero Point · Drass · Kargil'),
('kashmir-kargil-dhooth-pathri-tour',2,'Kargil LOC, Hunterman and Srinagar',$day$7:30 AM — Breakfast.
8:00 AM — Depart toward the Kargil India–Pakistan border / LOC. The tour vehicle is not permitted; use locally hired permitted cars from Kargil.
9:00 AM — Shivaji Temple.
10:00 AM — Kargil LOC. Visit the last picket point of the Indian military. The source says visitors can see a village and picket point on the Pakistan side. Spend one hour at the LOC.
11:30 AM — Hunterman Village, described in the source as the last Indian village on the border.
12:30 PM — Reach the hotel, then lunch.
1:00 PM — Hotel checkout and depart toward Srinagar.
2:00 PM — Kargil War Memorial. Spend 30 minutes at the memorial and visit the museum and documentary relating to the Kargil War. After honouring the soldiers, return.
6:00 PM — Shikara ride on Dal Lake. Srinagar city is surrounded by Dal Lake. Enjoy a one-hour ride through the lake, exploring the houseboats, floating market and village.
7:30 PM — Shopping at Dal Lake.
9:00 PM — Hotel check-in.
9:30 PM — Dinner; overnight stay.$day$,'Kargil · Hunterman · Kargil War Memorial · Srinagar'),
('kashmir-kargil-dhooth-pathri-tour',3,'Pahalgam, Chandanwadi and Betaab Valley',$day$7:30 AM — Breakfast.
8:00 AM — Depart toward Pahalgam.
9:00 AM — Saffron paddy at Pampore.
9:30 AM — Pulwama terrorist-attack point.
10:00 AM — Cricket-bat factory.
11:30 AM — Apple farms at Pahalgam. Take photographs and pluck fresh apples from the trees to purchase. The source describes apples from Pahalgam, Kashmir as very tasty and good quality.
1:00 PM — Lunch.
2:30 PM — Depart toward Chandanwadi and Betaab Valley. The tour vehicles are not permitted at these places, so hire local cars from the taxi stand. Taxi charges are included in the package. The source describes this as a two-hour journey, with 30 minutes at each place.
3:30 PM — Chandanwadi.
4:30 PM — Betaab Valley.
5:30 PM — Mini Switzerland / Baisaran Valley (source wording: “Byson Valley”).
7:00 PM — Return to Srinagar.
9:30 PM — Reach the hotel.
10:00 PM — Dinner; overnight stay.$day$,'Pampore · Pahalgam · Chandanwadi · Betaab Valley · Baisaran Valley · Srinagar'),
('kashmir-kargil-dhooth-pathri-tour',5,'Gulmarg and Hazratbal',$day$7:30 AM — Breakfast.
8:00 AM — Depart toward Gulmarg.
9:00 AM — Nishat Gardens. Spend 30 minutes here. Travellers can take photographs in traditional Kashmiri dress.
11:30 AM — Tangmarg and lunch.
2:00 PM — Gondola Cable Car at Gulmarg. The source describes the Gondola as a great experience and Asia’s highest cable-car service. It has two phases. Phase 1, Gulmarg to Kongdori, has an entry ticket stated as worth around ₹1,000 and is included in the package. A Phase 2 ticket from Kongdori to Apharwat is stated as available for ₹1,200 per person extra. Verify current prices, route names and operation. Explore Gulmarg for two to three hours.
5:30 PM — Return to Srinagar.
7:00 PM — Hazratbal Mosque. The source describes it as a very old mosque where a hair of Prophet Muhammad is kept. It says women should cover their heads when entering the mosque. Verify this wording before publication.
8:00 PM — Campfire.
9:00 PM — Dinner; overnight stay.$day$,'Srinagar · Nishat Gardens · Tangmarg · Gulmarg · Hazratbal'),
('kashmir-kargil-dhooth-pathri-tour',6,'Shankaracharya Temple and Dhooth Pathri',$day$8:00 AM — Breakfast.
9:00 AM — Sree Shankaracharya Hills and Temple. The source describes it as one of the four maths created by Shankaracharya. It describes the panoramic view from the hilltop as amazing, with the entire view of Dal Lake and Srinagar. Spend one hour here.
1:00 PM — Lunch.
2:00 PM — Dhooth Pathri. The source describes it as one of the main tourist places near Srinagar, with mind-blowing green mountains and landscapes. Visit the huts of local people and stay until evening.
6:00 PM — Return to Srinagar.
7:00 PM — Shopping at Lal Chowk.
10:00 PM — Dinner; overnight stay.$day$,'Srinagar · Shankaracharya Temple · Dhooth Pathri · Lal Chowk'),
('kashmir-kargil-dhooth-pathri-tour',7,'Shalimar Gardens and departure',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout.
9:00 AM — Shalimar Gardens. It is described as one of Kashmir’s famous gardens built by the Mughal Empire and by the Mughal emperor Jahangir. The source says Kashmir was the Mughal Empire’s summer capital. Spend 30 minutes at Shalimar Gardens.
11:30 AM — Depart toward Srinagar Airport.
12:30 PM — Reach and check in at Srinagar Airport.
2:40 PM — Flight to Delhi (client-supplied time; verify schedule).
4:20 PM — Reach Delhi Airport (client-supplied time; verify schedule).$day$,'Srinagar · Delhi'),

('delhi-kullu-manali-tour',1,'Delhi sightseeing and overnight bus to Manali',$day$8:00 AM — India Gate. Formerly known as the All India War Memorial, it is a 42-metre-high war memorial in New Delhi designed by Sir Edwin Lutyens. It honours more than 70,000 Indian and British soldiers who died in the World War. Spend the evening at India Gate and travel along the roads where the Independence Day and Republic Day parades are held.
9:00 AM — Outside view of Parliament House and Rashtrapati Bhavan.
10:00 AM — Indira Gandhi Museum. It is a museum at the house in front of which Indira Gandhi was shot.
11:30 AM — Qutub Minar. Qutub Minar was built from 1199 to 1220 as a victory tower. Qutb-ud-din Aibak started its construction in 1199 after the victory against Prithviraj Chauhan, and his successor Iltutmish completed it. It is one of India’s UNESCO World Heritage properties and a pride of Delhi.
1:00 PM — Lotus Temple.
2:00 PM — Lunch at Raj Ghat.
2:30 PM — Raj Ghat / Samadhi Sthal. Raj Ghat is Mahatma Gandhi’s memorial. Visit the memorials of Jawaharlal Nehru, Indira Gandhi, Rajiv Gandhi, Lal Bahadur Shastri and Atal Bihari Vajpayee, among others.
4:00 PM — Red Fort. It is a historic Mughal fort in Old Delhi and was the main residence of Mughal emperors. Shah Jahan commissioned it in 1639. On 15 August 1947, India’s first Prime Minister, Jawaharlal Nehru, hoisted the Indian flag at the main entrance. Since then, every Prime Minister of India has ceremonially raised the national flag at the main gate on Independence Day.
5:30 PM — Bus toward Manali.
9:00 PM — Dinner on the way at Chandigarh; overnight on the bus.$day$,'Delhi · Chandigarh · Manali'),
('delhi-kullu-manali-tour',2,'Manali local sightseeing',$day$10:00 AM — Expected arrival in Manali and hotel check-in.
10:30 AM — Breakfast and rest at the hotel.
1:00 PM — Lunch.
1:30 PM — Leave for Manali local sightseeing.
2:00 PM — Hadimba Temple. It was built in 1553 with a well-crafted, four-tiered pagoda roof and is famous for its exquisitely carved doorways. Spend 30 minutes here. Travellers can take photographs in Himachal traditional dress.
3:30 PM — Tibetan Monastery.
4:30 PM — Van Vihar and Manu Temple.
6:00 PM — Mall Road. It is an old market in Manali; time for shopping.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali'),
('delhi-kullu-manali-tour',3,'Solang Valley, Atal Tunnel and Rohtang Pass',$day$8:00 AM — Breakfast.
8:30 AM — Leave the hotel for sightseeing.
10:30 AM onward — Atal Tunnel, Nehru Kund, Kothi Village and Rohtang Pass if permitted/open to travellers.
1:30 PM — Lunch.
3:00 PM — Solang Valley. It is a beautiful valley where adventure activities such as paragliding, cable-car ropeway, snow scooter, snow skiing and horse riding may be available. The source does not specify whether these activity charges are included.
5:00 PM — Return to Manali.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali · Atal Tunnel · Nehru Kund · Kothi Village · Rohtang Pass · Solang Valley'),
('delhi-kullu-manali-tour',4,'Kulu sightseeing and overnight bus to Delhi',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout and depart for Kulu sightseeing.
11:00 AM — Kulu. Kulu is famous for river rafting. River rafting, paragliding and other activities may be available; the source does not specify whether their charges are included.
2:00 PM — Lunch.
3:00 PM — Shawl factory visit.
4:00 PM — Return toward Delhi.
9:00 PM — Dinner on the way; overnight on the bus.
Expected arrival in Delhi at 5:00 AM on the following day.$day$,'Manali · Kulu · Delhi'),

('kullu-manali-kasol',1,'Delhi sightseeing and overnight bus to Manali',$day$8:00 AM — India Gate. Formerly known as the All India War Memorial, it is a 42-metre-high war memorial in New Delhi designed by Sir Edwin Lutyens. It honours more than 70,000 Indian and British soldiers who died in the World War. Spend the evening at India Gate and travel along the roads where the Independence Day and Republic Day parades are held.
9:00 AM — Outside view of Parliament House and Rashtrapati Bhavan.
10:00 AM — Indira Gandhi Museum. It is a museum at the house in front of which Indira Gandhi was shot.
11:30 AM — Qutub Minar. Qutub Minar was built from 1199 to 1220 as a victory tower. Qutb-ud-din Aibak started its construction in 1199 after the victory against Prithviraj Chauhan, and his successor Iltutmish completed it. It is one of India’s UNESCO World Heritage properties and a pride of Delhi.
1:00 PM — Lotus Temple.
2:00 PM — Lunch at Raj Ghat.
2:30 PM — Raj Ghat / Samadhi Sthal. Raj Ghat is Mahatma Gandhi’s memorial. Visit the memorials of Jawaharlal Nehru, Indira Gandhi, Rajiv Gandhi, Lal Bahadur Shastri and Atal Bihari Vajpayee, among others.
4:00 PM — Red Fort. It is a historic Mughal fort in Old Delhi and was the main residence of Mughal emperors. Shah Jahan commissioned it in 1639. On 15 August 1947, India’s first Prime Minister, Jawaharlal Nehru, hoisted the Indian flag at the main entrance. Since then, every Prime Minister of India has ceremonially raised the national flag at the main gate on Independence Day.
5:30 PM — Bus toward Manali.
9:00 PM — Dinner on the way at Chandigarh; overnight on the bus.$day$,'Delhi · Chandigarh · Manali'),
('kullu-manali-kasol',2,'Manali local sightseeing',$day$10:00 AM — Expected arrival in Manali and hotel check-in.
10:30 AM — Breakfast and rest at the hotel.
1:00 PM — Lunch.
1:30 PM — Leave for Manali local sightseeing.
2:00 PM — Hadimba Temple. It was built in 1553 with a well-crafted, four-tiered pagoda roof and is famous for its exquisitely carved doorways. Spend 30 minutes here. Travellers can take photographs in Himachal traditional dress.
3:30 PM — Tibetan Monastery.
4:30 PM — Van Vihar and Manu Temple.
6:00 PM — Mall Road. It is an old market in Manali; time for shopping.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali'),
('kullu-manali-kasol',3,'Solang Valley, Atal Tunnel and Rohtang Pass',$day$8:00 AM — Breakfast.
8:30 AM — Leave the hotel for sightseeing.
10:30 AM onward — Atal Tunnel, Nehru Kund, Kothi Village and Rohtang Pass if permitted/open to travellers.
1:30 PM — Lunch.
3:00 PM — Solang Valley. It is a beautiful valley where adventure activities such as paragliding, cable-car ropeway, snow scooter, snow skiing and horse riding may be available. The source does not specify whether these activity charges are included.
5:00 PM — Return to Manali.
8:30 PM — Dinner; overnight at the hotel.$day$,'Manali · Atal Tunnel · Nehru Kund · Kothi Village · Rohtang Pass · Solang Valley'),
('kullu-manali-kasol',4,'Kasol and Manikaran sightseeing',$day$8:00 AM — Breakfast.
8:30 AM — Leave the hotel for full-day Kasol sightseeing.
Visit Kasol, Manikaran Sahib Gurudwara, Shiv Temple and Kasol Market.
2:00 PM — Lunch.
Return to the Manali hotel.
6:00 PM — Shopping at Mall Road, Manali.
9:00 PM — Dinner; overnight at the hotel.$day$,'Manali · Kasol · Manikaran · Manali'),
('kullu-manali-kasol',5,'Kulu sightseeing and overnight bus to Delhi',$day$8:00 AM — Breakfast.
8:30 AM — Hotel checkout and depart for Kulu sightseeing.
11:00 AM — Kulu. Kulu is famous for river rafting. River rafting, paragliding and other activities may be available; the source does not specify whether their charges are included.
2:00 PM — Lunch.
3:00 PM — Shawl factory visit.
4:00 PM — Return toward Delhi.
9:00 PM — Dinner on the way; overnight on the bus.
Expected arrival in Delhi at 5:00 AM on the following day.$day$,'Manali · Kulu · Delhi');

-- Existing differing itinerary rows may be approved Admin edits. Exact reruns
-- pass; any conflict or unexpected extra day aborts without deleting data.
do $$
declare conflicts text;
declare extras text;
begin
  select string_agg(p.slug || ': day ' || existing.day_number::text, ', ' order by p.slug,existing.day_number)
  into conflicts
  from public.tour_itinerary_days existing
  join public.tour_packages p on p.id=existing.package_id
  join pg_temp.client_cr8_12_itinerary source on source.slug=p.slug and source.day_number=existing.day_number
  where existing.title is distinct from source.title
     or existing.description is distinct from source.description
     or existing.location is distinct from source.location;

  select string_agg(p.slug || ': day ' || existing.day_number::text, ', ' order by p.slug,existing.day_number)
  into extras
  from public.tour_itinerary_days existing
  join public.tour_packages p on p.id=existing.package_id
  join pg_temp.client_cr8_12_packages source_package on source_package.slug=p.slug
  left join pg_temp.client_cr8_12_itinerary source_day on source_day.slug=p.slug and source_day.day_number=existing.day_number
  where source_day.slug is null;

  if conflicts is not null then
    raise exception 'CR8-CR12 itinerary rows differ from the reviewed client source. Export and review: %', conflicts;
  end if;
  if extras is not null then
    raise exception 'Unexpected CR8-CR12 itinerary rows require manual review; no rows were deleted: %', extras;
  end if;
end $$;

insert into public.tour_itinerary_days(package_id,day_number,title,description,location)
select p.id,source.day_number,source.title,source.description,source.location
from pg_temp.client_cr8_12_itinerary source
join public.tour_packages p on p.slug=source.slug
on conflict(package_id,day_number) do update set
  title=excluded.title,
  description=excluded.description,
  location=excluded.location,
  updated_at=now();

drop table if exists pg_temp.client_cr8_12_itinerary;
drop table if exists pg_temp.client_cr8_12_packages;

commit;
