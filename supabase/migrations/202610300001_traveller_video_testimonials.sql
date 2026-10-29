-- Premium traveller video testimonials.
-- Apply through the normal Supabase migration workflow; do not run from the browser.

begin;

alter table public.testimonials
  add column if not exists display_order integer not null default 0;

create index if not exists testimonials_public_video_order_idx
  on public.testimonials(display_order, created_at desc)
  where published = true and media_type = 'video';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'testimonials_published_video_has_media'
      and conrelid = 'public.testimonials'::regclass
  ) then
    alter table public.testimonials
      add constraint testimonials_published_video_has_media
      check (
        not (published and media_type = 'video')
        or (media_url is not null and length(trim(media_url)) > 0)
      ) not valid;
  end if;
end $$;

alter table public.testimonials validate constraint testimonials_published_video_has_media;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'testimonial-videos',
  'testimonial-videos',
  false,
  104857600,
  array['video/mp4','video/webm','video/quicktime']
)
on conflict(id) do update set
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists testimonial_videos_published_read on storage.objects;
create policy testimonial_videos_published_read
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'testimonial-videos'
  and (
    public.is_admin()
    or exists (
      select 1
      from public.testimonials t
      where t.published = true
        and t.media_type = 'video'
        and t.media_url = storage.objects.name
    )
  )
);

drop policy if exists testimonial_videos_admin_insert on storage.objects;
create policy testimonial_videos_admin_insert
on storage.objects for insert
to authenticated
with check (bucket_id = 'testimonial-videos' and public.is_admin());

drop policy if exists testimonial_videos_admin_update on storage.objects;
create policy testimonial_videos_admin_update
on storage.objects for update
to authenticated
using (bucket_id = 'testimonial-videos' and public.is_admin())
with check (bucket_id = 'testimonial-videos' and public.is_admin());

drop policy if exists testimonial_videos_admin_delete on storage.objects;
create policy testimonial_videos_admin_delete
on storage.objects for delete
to authenticated
using (bucket_id = 'testimonial-videos' and public.is_admin());

commit;
