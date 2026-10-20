-- Destination image integrity follow-up.
-- Forward-only and idempotent: only known legacy placeholder paths are changed.
-- Admin-uploaded URLs, IDs, content, prices, bookings and media rows are preserved.
-- Source, creator and license metadata is mirrored in src/destinationImages.ts.

begin;

with replacements(slug,image_url,legacy_image) as (values
  ('agumbe','https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85','/travel/tulip-garden.webp'),
  ('ajanta-ellora','https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85','/travel/tulip-garden.webp'),
  ('andaman','https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85','/travel/beach-reflections.webp'),
  ('ayodhya-kashi-prayagraj-gaya-bodh-gaya','https://commons.wikimedia.org/wiki/Special:FilePath/Ram_Mandir,_Ayodhya.png?width=1600','/travel/tulip-garden.webp'),
  ('azerbaijan','https://commons.wikimedia.org/wiki/Special:FilePath/The_skyline_of_Baku,_Azerbaijan.jpg?width=1600','/travel/tulip-garden.webp'),
  ('bangalore-mysore-kodagu','https://commons.wikimedia.org/wiki/Special:FilePath/Exterior_of_the_Mysore_Palace,_Mysore,_Karnataka,_2018.jpg?width=1600','/travel/tulip-garden.webp'),
  ('bhutan','https://commons.wikimedia.org/wiki/Special:FilePath/Paro_Taktsang,_Bhutan_(edited).jpg?width=1600','/travel/tulip-garden.webp'),
  ('bijapur-hampi-badami-aihole-pattadakkal-chitradurga','https://commons.wikimedia.org/wiki/Special:FilePath/Hampi,_India,_Rocky_landscape_of_Hampi,_Granite_rocks_of_Matanga_Hill.jpg?width=1600','/travel/tulip-garden.webp'),
  ('chikmagalur','https://commons.wikimedia.org/wiki/Special:FilePath/Shade_coffee_plantation_landscape_Chikmagalur.jpg?width=1600','/travel/tulip-garden.webp'),
  ('delhi-agra-jaipur-amritsar-wagah-border','https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1600&q=85','/travel/tulip-garden.webp'),
  ('gujarat','https://commons.wikimedia.org/wiki/Special:FilePath/Pond,_Little_Rann_of_Kutch_(16494607670).jpg?width=1600','/travel/tulip-garden.webp'),
  ('hampi','https://commons.wikimedia.org/wiki/Special:FilePath/Krishna_Pushkarani_-_Hampi_Ruins.jpg?width=1600','/travel/tulip-garden.webp'),
  ('hyderabad','https://commons.wikimedia.org/wiki/Special:FilePath/Charminar_Hyderabad_1.jpg?width=1600','/travel/tulip-garden.webp'),
  ('jog-falls','https://commons.wikimedia.org/wiki/Special:FilePath/Jog_Falls,_Sep,_2016.jpg?width=1600','/travel/tulip-garden.webp'),
  ('kerala-full','https://commons.wikimedia.org/wiki/Special:FilePath/A_Houseboat_In_Kerala_Backwaters.jpg?width=1600','/travel/tulip-garden.webp'),
  ('kolkata','https://commons.wikimedia.org/wiki/Special:FilePath/Victoria_Memorial_situated_in_Kolkata.jpg?width=1600','/travel/tulip-garden.webp'),
  ('malaysia-singapore','https://commons.wikimedia.org/wiki/Special:FilePath/Singapore_Skyline.jpg?width=1600','/travel/tulip-garden.webp'),
  ('matheran','https://commons.wikimedia.org/wiki/Special:FilePath/Matheran_mountains.jpg?width=1600','/travel/tulip-garden.webp'),
  ('meghalaya','https://commons.wikimedia.org/wiki/Special:FilePath/Living_root_bridge,_Maghalaya,_India1.jpg?width=1600','/travel/tulip-garden.webp'),
  ('mumbai','https://commons.wikimedia.org/wiki/Special:FilePath/Panoramic_view_of_Taj_Palace_Hotel_and_Taj_Tower_with_the_iconic_Gateway_of_India_in_the_background.jpg?width=1600','/travel/tulip-garden.webp'),
  ('munnar-thekkady-kochi-alappuzha-kumarakom-varkala-kovalam','https://commons.wikimedia.org/wiki/Special:FilePath/Athirappilly_Falls_2024.jpg?width=1600','/travel/tulip-garden.webp'),
  ('munnar-thekkady-vagamon-kochi-athirappalli','https://commons.wikimedia.org/wiki/Special:FilePath/Tea_plantation_and_road_,munnar.jpg?width=1600','/travel/tulip-garden.webp'),
  ('nepal','https://commons.wikimedia.org/wiki/Special:FilePath/Durbar_Square,_Kathmandu.jpg?width=1600','/travel/tulip-garden.webp'),
  ('odisha','https://commons.wikimedia.org/wiki/Special:FilePath/Konark_Sun_Temple_,_Konark_,_Odisha_,_India.jpg?width=1600','/travel/tulip-garden.webp'),
  ('ooty-mysore','https://commons.wikimedia.org/wiki/Special:FilePath/Hills_in_ooty.jpg?width=1600','/travel/tulip-garden.webp'),
  ('rameswaram-dhanushkodi-madurai-kodaikanal','https://commons.wikimedia.org/wiki/Special:FilePath/Pamban_Bridge.Rameswaram.jpg?width=1600','/travel/tulip-garden.webp'),
  ('sikkim-darjeeling','https://commons.wikimedia.org/wiki/Special:FilePath/Kanchenjunga_from_Darjeeling.jpg?width=1600','/travel/tulip-garden.webp'),
  ('sri-lanka','https://commons.wikimedia.org/wiki/Special:FilePath/Sigiriya_Rock_fortress.jpg?width=1600','/travel/tulip-garden.webp'),
  ('vagamon','https://commons.wikimedia.org/wiki/Special:FilePath/Vagamon_hills_of_Kerala_02.jpg?width=1600','/travel/tulip-garden.webp'),
  ('valparai-athirappalli','https://commons.wikimedia.org/wiki/Special:FilePath/Valparai,Tamil_Nadu.jpg?width=1600','/travel/tulip-garden.webp'),
  ('wayanad','https://commons.wikimedia.org/wiki/Special:FilePath/Kerala-wayanad.jpg?width=1600','/travel/tulip-garden.webp'),
  ('kashmir-kargil','https://commons.wikimedia.org/wiki/Special:FilePath/Ladakh_landscape_near_Leh.jpg?width=1600','/travel/mountain-river-bridge.webp'),
  ('kasol','https://commons.wikimedia.org/wiki/Special:FilePath/Parvati_Valley_From_Kasol.jpg?width=1600','/travel/mountain-river-bridge.webp'),
  ('kullu-manali-kasol','https://commons.wikimedia.org/wiki/Special:FilePath/Solang_Valley_Manali.JPG?width=1600','/travel/mountain-river-bridge.webp'),
  ('ladakh','https://commons.wikimedia.org/wiki/Special:FilePath/Landscape_of_Ladakh_03.jpg?width=1600','/travel/mountain-river-bridge.webp'),
  ('bali-nusa-penida','https://commons.wikimedia.org/wiki/Special:FilePath/Nusa_Penida_Bali.jpg?width=1600','/travel/nusa-penida.webp'),
  ('indonesia','https://commons.wikimedia.org/wiki/Special:FilePath/Borobudur-Nothwest-view.jpg?width=1600','/travel/nusa-penida.webp'),
  ('gokarna','https://commons.wikimedia.org/wiki/Special:FilePath/Gokarna_beach.jpg?width=1600','/travel/beach-reflections.webp'),
  ('lakshadweep','https://commons.wikimedia.org/wiki/Special:FilePath/LakshadweepIsland.jpg?width=1600','/travel/beach-reflections.webp')
), updated_destinations as (
  update public.destinations d
  set hero_image=r.image_url,updated_at=now()
  from replacements r
  where d.slug=r.slug and d.hero_image=r.legacy_image
  returning d.id
)
update public.tour_packages p
set hero_image=r.image_url,updated_at=now()
from replacements r
left join public.destinations d on d.slug=r.slug
where (p.slug=r.slug or p.destination_id=d.id)
  and p.hero_image=r.legacy_image;

update public.gallery_items
set title='Tulip Garden',
    alt_text='Rows of colourful tulips at Tulip Garden in Kashmir',
    updated_at=now()
where media_type='image' and media_url ilike '%tulip%'
  and (title ilike '%agumbe%' or alt_text ilike '%agumbe%');

commit;
