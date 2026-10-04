# SUPABASE ADMIN — BengkelKu Admin Web

Admin memakai **project Supabase yang sama** dengan mobile. Skema inti (users, workshops, bookings, dll.) didefinisikan di `../bengkelku-mobile/supabase/migrations/0001–0009`. Repo admin hanya menambah objek khusus admin (migrasi `0100+`) dan dua Edge Function.

## 1. Migrasi admin

| File | Isi |
|---|---|
| `0100_admin_roles.sql` | enum `admin_role` (`super_admin`, `verifikator`, `finance`, `cs`); tabel `admin_users (id FK auth.users, role, is_active, created_at)`; helper `is_admin()` & `has_admin_role(role)` (SECURITY DEFINER, membaca `admin_users`). |
| `0101_audit_log.sql` | tabel `audit_logs (id, actor_id, action, target_type, target_id, meta jsonb, created_at)`; indeks pada `actor_id`, `action`, `created_at`. Append-only (tak ada UPDATE/DELETE policy). |
| `0102_admin_rls.sql` | RLS untuk `admin_users` (admin baca; super_admin kelola) & `audit_logs` (super_admin baca; insert via service role); kebijakan **baca** admin pada tabel mobile (workshops, workshop_documents, bookings, payments, payouts, users) memakai `is_admin()`. |

Terapkan setelah migrasi mobile:

```bash
supabase db push        # atau jalankan 0100–0102 setelah 0001–0009
```

## 2. Model peran & otorisasi

- Peran disimpan di `admin_users.role`. Satu admin satu peran.
- RLS memakai `is_admin()` (aktif?) dan `has_admin_role('finance')` dsb.
- JWT admin memakai `aud=admin` (dipisah dari `aud=mobile`) agar token mobile tak bisa mengakses rute admin dan sebaliknya.
- Operasi **tulis** sensitif (ubah status workshop, payout) tidak dilakukan langsung dari klien: lewat Route Handler Next.js dengan service role, **selalu** menulis `audit_logs`.

## 3. Akses dokumen sensitif

- Bucket privat `verification-docs` (dibuat di repo mobile, limit 2 MB).
- Server membuat **signed URL ≤ 60 dtk** memakai service role saat halaman detail dibuka; tak pernah ada URL publik.
- Setiap pembuatan URL menulis audit `VIEW_DOCUMENTS` dengan `document_id`.
- UI (`DocViewer`): blur default, watermark email admin, nonaktif unduh/menu konteks, jendela lihat 2 menit.

## 4. Edge Functions (opsional, alternatif Route Handler)

Di `supabase/functions/`:

| Function | Peran |
|---|---|
| `admin-signed-doc-url` | Verifikasi caller (Bearer JWT) admin aktif → signed URL ≤ 60 dtk untuk `workshop_documents.storage_path` → audit `VIEW_DOCUMENTS`. |
| `admin-verify-decision` | Verifikasi admin aktif → update `workshops.status` (`verified`/`rejected`) → audit `APPROVE_WORKSHOP`/`REJECT_WORKSHOP` → notifikasi owner. |

Secret yang dibutuhkan: `SUPABASE_URL`, `SERVICE_ROLE_KEY`.

```bash
supabase functions deploy admin-signed-doc-url
supabase functions deploy admin-verify-decision
```

Catatan: implementasi default aplikasi memakai Route Handler Next.js (`src/app/api/verify/route.ts` dan signed URL di `src/app/(dash)/verifikasi/[id]/page.tsx`). Edge Functions disediakan sebagai alternatif serverless yang setara.

## 5. Service role key

- Hanya dipakai di server (Route Handler / Server Component / Edge Function) via `createAdminClient()` di `src/lib/supabase/server.ts`.
- **Tidak pernah** diimpor ke komponen klien (`"use client"`) atau variabel `NEXT_PUBLIC_*`.
- Klien browser hanya memakai anon key (`src/lib/supabase/client.ts`).

## 6. Audit

Semua keputusan verifikasi dan akses dokumen tercatat di `audit_logs`. Tabel bersifat append-only; tidak ada jalur UI/RLS untuk mengubah atau menghapus baris audit.
