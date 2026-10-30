-- Forward-only hardening for testimonial thumbnails and browser video codecs.
-- Existing site-media thumbnail URLs and testimonial records remain unchanged.

begin;

update storage.buckets
set allowed_mime_types = array['video/mp4','video/webm']
where id = 'testimonial-videos';

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'testimonial-thumbnails',
  'testimonial-thumbnails',
  false,
  8388608,
  array['image/jpeg','image/png','image/webp']
)
on conflict(id) do update set
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists testimonial_thumbnails_published_read on storage.objects;
create policy testimonial_thumbnails_published_read
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'testimonial-thumbnails'
  and (
    public.is_admin()
    or exists (
      select 1
      from public.testimonials t
      where t.published = true
        and t.media_type = 'video'
        and t.poster_url = storage.objects.name
    )
  )
);

drop policy if exists testimonial_thumbnails_admin_insert on storage.objects;
create policy testimonial_thumbnails_admin_insert
on storage.objects for insert
to authenticated
with check (bucket_id = 'testimonial-thumbnails' and public.is_admin());

drop policy if exists testimonial_thumbnails_admin_update on storage.objects;
create policy testimonial_thumbnails_admin_update
on storage.objects for update
to authenticated
using (bucket_id = 'testimonial-thumbnails' and public.is_admin())
with check (bucket_id = 'testimonial-thumbnails' and public.is_admin());

drop policy if exists testimonial_thumbnails_admin_delete on storage.objects;
create policy testimonial_thumbnails_admin_delete
on storage.objects for delete
to authenticated
using (bucket_id = 'testimonial-thumbnails' and public.is_admin());

commit;
