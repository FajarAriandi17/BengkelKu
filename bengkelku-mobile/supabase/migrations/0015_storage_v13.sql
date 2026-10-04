-- 0015_storage_v13.sql — bucket media untuk fitur v1.3 (semua dibatasi 2 MB)

-- chat-media: foto di thread chat (maks 3 per pesan, ≤ 2 MB).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('chat-media', 'chat-media', true, 2097152,
    array['image/jpeg','image/png','image/webp']),
  ('sos-photos', 'sos-photos', true, 2097152,
    array['image/jpeg','image/png','image/webp']),
  ('quote-photos', 'quote-photos', true, 2097152,
    array['image/jpeg','image/png','image/webp']),
  ('support-photos', 'support-photos', false, 2097152,
    array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ===========================================================================
-- chat-media: peserta thread boleh baca; pemilik menulis.
-- ===========================================================================

create policy "chat_media_read" on storage.objects
  for select using (bucket_id = 'chat-media');

create policy "chat_media_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'chat-media' and owner = auth.uid()
  );

create policy "chat_media_update" on storage.objects
  for update to authenticated using (
    bucket_id = 'chat-media' and owner = auth.uid()
  );

-- ===========================================================================
-- sos-photos: foto kerusakan dari pengendara (publik dibaca, owner tulis).
-- ===========================================================================

create policy "sos_photos_read" on storage.objects
  for select using (bucket_id = 'sos-photos');

create policy "sos_photos_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'sos-photos' and owner = auth.uid()
  );

-- ===========================================================================
-- quote-photos: foto bukti penawaran dari bengkel.
-- ===========================================================================

create policy "quote_photos_read" on storage.objects
  for select using (bucket_id = 'quote-photos');

create policy "quote_photos_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'quote-photos' and owner = auth.uid()
  );

-- ===========================================================================
-- support-photos: PRIVAT. Hanya pemilik tiket yang upload & baca.
-- Admin membaca lewat signed URL (service role).
-- ===========================================================================

create policy "support_photos_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'support-photos' and owner = auth.uid()
  );

create policy "support_photos_read_owner" on storage.objects
  for select to authenticated using (
    bucket_id = 'support-photos' and owner = auth.uid()
  );
