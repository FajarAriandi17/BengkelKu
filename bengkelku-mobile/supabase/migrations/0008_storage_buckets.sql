-- 0008_storage_buckets.sql — bucket Storage + batas 2 MB (FR-U1)
-- Dua bucket: foto publik & dokumen verifikasi privat. Keduanya dibatasi 2 MB.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('workshop-photos', 'workshop-photos', true, 2097152,
    array['image/jpeg','image/png','image/webp']),
  ('verification-docs', 'verification-docs', false, 2097152,
    array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Catatan: batas 2.097.152 byte (2 MB) juga divalidasi di klien
-- (MediaGuard.ensureUnderLimit) dengan pesan baku:
-- "ukuran media anda terlalu besar segera kompres file media untuk melanjutkan".

-- workshop-photos: baca publik; tulis oleh pengguna terautentikasi.
create policy "wp_public_read" on storage.objects
  for select using (bucket_id = 'workshop-photos');
create policy "wp_auth_write" on storage.objects
  for insert to authenticated with check (bucket_id = 'workshop-photos');
create policy "wp_auth_update" on storage.objects
  for update to authenticated using (bucket_id = 'workshop-photos' and owner = auth.uid());

-- verification-docs: PRIVAT. Pengguna hanya kelola berkasnya; tak ada baca publik.
-- Admin mengakses lewat signed URL (service role), bukan policy publik.
create policy "vd_owner_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'verification-docs' and owner = auth.uid());
create policy "vd_owner_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'verification-docs' and owner = auth.uid());
