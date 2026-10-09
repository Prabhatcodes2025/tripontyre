-- Public website media with admin-only browser writes. Safe to rerun.
-- Private booking documents remain isolated in the private booking-documents bucket.

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'site-media',
  'site-media',
  true,
  8388608,
  array['image/jpeg','image/png','image/webp']
)
on conflict(id) do update set
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists site_media_public_read on storage.objects;
create policy site_media_public_read
on storage.objects for select
to public
using(bucket_id='site-media');

drop policy if exists site_media_admin_insert on storage.objects;
create policy site_media_admin_insert
on storage.objects for insert
to authenticated
with check(bucket_id='site-media' and public.is_admin());

drop policy if exists site_media_admin_update on storage.objects;
create policy site_media_admin_update
on storage.objects for update
to authenticated
using(bucket_id='site-media' and public.is_admin())
with check(bucket_id='site-media' and public.is_admin());

drop policy if exists site_media_admin_delete on storage.objects;
create policy site_media_admin_delete
on storage.objects for delete
to authenticated
using(bucket_id='site-media' and public.is_admin());
