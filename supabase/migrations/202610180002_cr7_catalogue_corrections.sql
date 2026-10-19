-- CR7 catalogue/category/media corrections.
-- Forward-only, idempotent and update-only: no package, booking, payment,
-- enquiry or itinerary rows are inserted, removed or replaced.
--
-- Verified image sources (free under the Unsplash License):
-- Agumbe, Karnataka: https://unsplash.com/photos/yOj9j2Ho-kE
-- Ajanta Caves, Maharashtra: https://unsplash.com/photos/ZP039_CRf3M
-- Andaman and Nicobar Islands: https://unsplash.com/photos/YZh8je9IYfc

begin;

update public.destinations
set primary_category='international',updated_at=now()
where slug in ('bali','bali-nusa-penida')
  and primary_category is distinct from 'international';

update public.tour_packages p
set category='international',updated_at=now()
where (p.slug in ('bali','bali-nusa-penida','bali-island-escape')
    or p.destination_id in (
      select d.id from public.destinations d where d.slug in ('bali','bali-nusa-penida')
    ))
  and p.category is distinct from 'international';

-- Each affected destination receives its own verified photograph. Existing
-- records are updated in place; absent records are deliberately not invented.
update public.destinations
set hero_image=case slug
  when 'agumbe' then 'https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85'
  when 'ajanta-ellora' then 'https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85'
  when 'andaman' then 'https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85'
end,
updated_at=now()
where slug in ('agumbe','ajanta-ellora','andaman');

update public.tour_packages
set hero_image=case slug
  when 'agumbe' then 'https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85'
  when 'ajanta-ellora' then 'https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85'
  when 'andaman' then 'https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85'
end,
updated_at=now()
where slug in ('agumbe','ajanta-ellora','andaman');

update public.tour_packages p
set hero_image=case d.slug
  when 'agumbe' then 'https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85'
  when 'ajanta-ellora' then 'https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85'
  when 'andaman' then 'https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85'
end,
updated_at=now()
from public.destinations d
where p.destination_id=d.id
  and d.slug in ('agumbe','ajanta-ellora','andaman');

-- The supplied flower photograph is Tulip Garden, Kashmir. Correct only rows
-- that still combine an Agumbe label with a tulip media URL; genuine Agumbe
-- rows remain separately named Agumbe and use the image set above.
update public.gallery_items
set title='Tulip Garden',
    alt_text='Rows of colourful tulips at Tulip Garden in Kashmir',
    updated_at=now()
where media_type='image'
  and media_url ilike '%tulip%'
  and (title ilike '%agumbe%' or alt_text ilike '%agumbe%');

commit;
