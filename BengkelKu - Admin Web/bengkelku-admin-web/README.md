# BengkelKu — Admin Web (Developer/Internal)

Panel web **khusus developer/admin internal** untuk **memverifikasi & menyetujui/menolak** bengkel sebelum tayang di aplikasi mobile, plus moderasi, keuangan, dan konfigurasi. **Login dengan username & kata sandi** (tidak ada signup publik).

> Ini adalah **repo kedua** dari dua repo BengkelKu:
> 1. `bengkelku-mobile/` — aplikasi pengendara & pemilik bengkel (Flutter).
> 2. `bengkelku-admin-web/` — panel admin ini (folder ini).
>
> Keduanya memakai **satu project Supabase yang sama**. Skema DB kanonik ada di `bengkelku-mobile/supabase/`. Repo ini hanya menambah migrasi khusus admin (`supabase/migrations/0100_*`+).

## Stack

| Lapisan | Teknologi | Catatan |
|---|---|---|
| Framework | **Next.js 14 (App Router) + TypeScript** | desktop-first (min 1024px) |
| UI | React + Tailwind CSS | token desain selaras mobile (`src/lib/theme/tokens.ts`) |
| Auth | **Supabase Auth** | invite-only, JWT `aud=admin`, 2FA TOTP |
| Database | **Supabase Postgres** (project sama) | akses via RLS admin + service role di server |
| Storage | **Supabase Storage** (bucket privat `verification-docs`) | akses dokumen via **signed URL ≤ 60 dtk** |
| Serverless | **Supabase Edge Functions** | `admin-verify-decision`, `admin-signed-doc-url` |
| Hosting | Vercel (disarankan) | subdomain terpisah, mis. `admin.bengkelku.app` |

## Keamanan (ringkas)

- **Tanpa signup publik**: akun dibuat lewat undangan admin saja.
- **2FA TOTP** wajib untuk semua admin.
- **JWT `aud=admin`** terpisah dari mobile (`aud=mobile`).
- Sesi: idle 30 menit, absolut 12 jam. Cookie `HttpOnly; Secure; SameSite=Strict`.
- Dokumen KTP/selfie: **blur default**, watermark, **tanpa unduh**, jendela lihat 2 menit, akses via signed URL ≤ 60 dtk, semua akses tercatat di **audit log**.
- IP allowlist opsional.

## Dokumentasi (baca sebelum ngoding)

| File | Isi |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Tujuan, peran, alur verifikasi, fitur admin |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Arsitektur, keamanan, sesi, akses dokumen |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Token, komponen admin |
| [`docs/ANIMATIONS.md`](docs/ANIMATIONS.md) | Gerak/animasi (halus, hormati reduce motion) |
| [`docs/PAGES.md`](docs/PAGES.md) | Inventaris halaman + perilaku |
| [`docs/SUPABASE_ADMIN.md`](docs/SUPABASE_ADMIN.md) | Migrasi admin (roles/audit/RLS), Edge Functions |

## Setup cepat

```bash
npm install
cp .env.example .env.local   # isi URL/anon + service role (server only)
npm run dev                  # http://localhost:3000
```

## Struktur folder

```
bengkelku-admin-web/
├── docs/
├── src/
│   ├── app/            # App Router: login, dashboard, verifikasi, dll.
│   ├── components/     # AdminShell, DocViewer, DataTable, dll.
│   └── lib/            # supabase (client/server), theme tokens, auth
├── supabase/
│   ├── migrations/     # 0100_admin_roles, 0101_audit_log, 0102_admin_rls
│   └── functions/      # admin-verify-decision, admin-signed-doc-url
├── middleware.ts       # guard auth (aud=admin) di seluruh rute kecuali /login
└── ...config
```

## Prinsip penting

- **Repo ini TIDAK ada di mobile.** Tidak ada kode admin yang masuk ke build Flutter.
- **Dokumen sensitif** hanya diakses via signed URL singkat; jangan pernah membuat bucket publik untuk `verification-docs`.
- **Semua aksi admin tercatat** di `audit_logs`.
