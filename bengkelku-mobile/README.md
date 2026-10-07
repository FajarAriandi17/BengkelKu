# BengkelKu — Aplikasi Mobile (Android & iOS)

Marketplace bengkel motor: cari bengkel terdekat (GPS), booking + bayar online, dan pengingat ganti oli pintar. Satu codebase **Flutter** untuk Android dan iOS, backend & database **Supabase**.

> Proyek ini adalah **satu dari dua** repo BengkelKu:
> 1. `bengkelku-mobile/` — aplikasi pengendara & pemilik bengkel (folder ini).
> 2. `bengkelku-admin-web/` — panel admin/developer untuk verifikasi bengkel (repo terpisah).
>
> Keduanya memakai **satu project Supabase yang sama**. Skema database kanonik (source of truth) ada di folder ini: `supabase/`.

---

## Stack

| Lapisan | Teknologi | Catatan |
|---|---|---|
| Mobile | **Flutter** 3.x (Dart 3) | Android 8.0+ (API 26), iOS 15+. Dipilih karena animasi 60 fps & UI kustom (lihat `docs/ANIMATIONS.md`) |
| State | Riverpod | `flutter_riverpod` |
| Routing | go_router | transisi shared-axis |
| Auth | **Supabase Auth** | Email+password, Google, Apple, (OTP HP P1) |
| Database | **Supabase Postgres + PostGIS** | query "bengkel terdekat" |
| Storage | **Supabase Storage** | foto bengkel (publik) + KTP/selfie (privat), **batas 2 MB/berkas** |
| Realtime | **Supabase Realtime** | status booking live |
| Serverless | **Supabase Edge Functions** (Deno) | webhook pembayaran, cron pengingat oli, batch payout |
| Peta | Google Maps SDK | gaya peta kustom (`docs/DESIGN_SYSTEM.md`) |
| Push | Firebase Cloud Messaging + APNs | — |
| Pembayaran | Mayar | QRIS, e-wallet, VA, retail + disbursement payout |
| Error | Sentry | `sentry_flutter` |

## Dokumentasi (baca sebelum ngoding)

| File | Isi |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Product Requirements (fitur, FR, metrik, roadmap) |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Arsitektur Supabase, alur data, keamanan, aturan 2 MB |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Token warna, tipografi, spasi, komponen |
| [`docs/ANIMATIONS.md`](docs/ANIMATIONS.md) | Spesifikasi gerak/animasi per layar |
| [`docs/SCREENS.md`](docs/SCREENS.md) | Inventaris layar + API/perilaku |
| [`docs/SUPABASE_BACKEND.md`](docs/SUPABASE_BACKEND.md) | Panduan skema, RLS, storage, functions |

## Setup cepat

```bash
# 1. Prasyarat: Flutter SDK 3.x, Dart 3, Supabase CLI, FVM (opsional)
flutter --version
supabase --version

# 2. Dependensi
flutter pub get

# 3. Konfigurasi environment
cp .env.example .env         # isi nilainya; file harus berformat JSON

# 4. Jalankan Supabase lokal (atau pakai project cloud)
supabase start
supabase db reset            # jalankan semua migrasi di supabase/migrations + seed

# 5. Jalankan aplikasi
flutter run --dart-define-from-file=.env

# Build APK release bertanda tangan Android
flutter build apk --release --dart-define-from-file=.env
```

File `.env` harus berupa JSON valid karena dipakai oleh `--dart-define-from-file`.
Isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` dari project Supabase yang digunakan.
Signing key lokal berada di `android/app/upload-keystore.jks`; simpan cadangan aman
dan jangan bagikan atau commit file `android/key.properties` maupun keystore.

## Struktur folder

```
bengkelku-mobile/
├── docs/              # PRD + semua spesifikasi desain
├── assets/            # logo, animasi (Lottie/Rive), ilustrasi, ikon
├── lib/
│   ├── app/           # app.dart, router (go_router)
│   ├── core/          # theme (tokens), motion, network (Supabase), utils, l10n
│   ├── design/        # komponen UI reusable (katalog di DESIGN_SYSTEM.md)
│   └── features/      # auth, location, workshops, booking, payment, garage,
│                      # oil, favorites, notifications, reviews, owner
├── test/              # unit test (mis. oil_calculator_test.dart)
└── supabase/          # skema DB kanonik: migrations, functions, seed, config
```

## Prinsip penting
- **Batas upload 2 MB**: semua unggah media (KTP, selfie, foto bengkel/ulasan) dibatasi 2 MB agar muat di Supabase free tier. Jika lebih besar, tampilkan **persis**: *"ukuran media anda terlalu besar segera kompres file media untuk melanjutkan"*. Lihat `lib/core/utils/media_guard.dart` dan kebijakan storage di `supabase/migrations/0008_storage_buckets.sql`.
- **Admin tidak ada di sini**: tidak ada layar/route/string/endpoint admin di build Android/iOS. Verifikasi bengkel 100% di `bengkelku-admin-web`.
- **Waktu**: simpan UTC, tampilkan di zona waktu bengkel (WIB/WITA/WIT).
