# ARCHITECTURE — BengkelKu Admin Web

## 1. Gambaran

Next.js 14 (App Router) + TypeScript di Vercel, memakai **project Supabase yang sama** dengan mobile. Admin punya domain & login sendiri. Service role key hanya dipakai di server (Route Handler / Server Component / Edge Function).

```
Browser (admin) ── cookie sesi ──> Next.js (middleware guard)
     │                                   │ server: service role (bypass RLS, terbatas & teraudit)
     └── anon key (klien) ──────────────> Supabase (Auth, DB, Storage)
```

## 2. Autentikasi & sesi

- Login email+password via Supabase Auth; **2FA TOTP** sebagai langkah kedua.
- `middleware.ts` menjaga semua rute kecuali `/login` & aset: tanpa sesi → redirect `/login`.
- Pengecekan **admin aktif** dilakukan di server/RLS (`admin_users.is_active`) dan di Route Handler sensitif (`/api/verify`).
- Sesi: idle 30 menit, absolut 12 jam (konfigurasi Supabase/host). Cookie `HttpOnly; Secure; SameSite=Strict`.
- JWT `aud=admin` memisahkan admin dari pengguna mobile (`aud=mobile`).

## 3. Otorisasi

Peran di `admin_users.role` (super_admin/verifikator/finance/cs). RLS memakai `is_admin()` & `has_admin_role()`. Operasi tulis sensitif (ubah status workshop, payout) melewati server dengan service role **dan** selalu menulis `audit_logs`.

## 4. Akses dokumen sensitif

- Dokumen KTP/selfie ada di bucket **privat** `verification-docs` (dibuat di repo mobile, batas 2 MB).
- Admin tidak pernah mendapat URL publik. Server membuat **signed URL ≤ 60 dtk** (service role) saat halaman detail dibuka, dan menulis audit `VIEW_DOCUMENTS`.
- Di UI: `DocViewer` memblur default, menampilkan watermark email admin, menonaktifkan menu konteks & unduh, dan menutup tampilan setelah jendela 2 menit.

## 5. Data flow verifikasi

`/verifikasi` (list `pending`) → `/verifikasi/[id]` (profil + signed URL dokumen + checklist) → POST `/api/verify` (service role: update status + audit + notifikasi owner) → kembali ke antrean.

Alternatif serverless: Edge Functions `admin-verify-decision` & `admin-signed-doc-url` (di `supabase/functions`).

## 6. Keamanan tambahan

- Header: `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy` mematikan kamera/mikrofon/geolokasi (`next.config.mjs`).
- `robots: noindex`.
- IP allowlist opsional via `ADMIN_IP_ALLOWLIST` (dicek di middleware/host).
- Service role key tidak pernah diimpor ke komponen klien (`"use client"`).
