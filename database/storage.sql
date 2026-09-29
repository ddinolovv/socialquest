-- Run after schema.sql. Creates private-per-user upload permissions in a public post-images bucket.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-images', 'post-images', true, 52428800, array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = 52428800,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime'];

create policy "Anyone can view post images"
on storage.objects for select using (bucket_id = 'post-images');

create policy "Users upload only to their folder"
on storage.objects for insert to authenticated
with check (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users update only their own images"
on storage.objects for update to authenticated
using (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users delete only their own images"
on storage.objects for delete to authenticated
using (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);
