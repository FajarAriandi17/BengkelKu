# SUPABASE BACKEND — Panduan

Backend & database BengkelKu = **Supabase** (satu project untuk mobile + admin web). Skema kanonik ada di repo ini: `supabase/`. **SQL = kebenaran struktur DB.**

## 1. Struktur folder

```
supabase/
├── config.toml                 # konfigurasi project lokal
├── seed.sql                    # data awal (preset oli, dll.)
├── migrations/
│   ├── 0001_extensions.sql       # postgis, pgcrypto, enum
│   ├── 0002_core_tables.sql      # users, vehicles, odometer_logs
│   ├── 0003_workshops_geo.sql    # workshops (geography POINT), hours, slots, services, documents
│   ├── 0004_bookings_payments.sql
│   ├── 0005_oil_reminders.sql    # presets, service_records, oil_reminders
│   ├── 0006_reviews_social.sql   # reviews, favorites, notifications
│   ├── 0007_rls_policies.sql
│   ├── 0008_storage_buckets.sql  # bucket + batas 2 MB
│   ├── 0009_functions_rpc.sql    # nearby_workshops RPC, trigger odometer→oli
│   └── 0025_mayar_payments.sql  # RPC pembayaran Mayar (intent, invoice, mark)
└── functions/
    ├── mayar-pay/index.ts           # buat invoice Mayar (JWT pengendara)
    ├── payment-webhook/index.ts    # terima webhook Mayar (token query string)
    ├── oil-reminder-cron/index.ts
    └── payout-batch/index.ts
```

Migrasi khusus admin (roles, audit, RLS admin: `0100_*`, `0101_*`, `0102_*`) ada di repo `bengkelku-admin-web` tetapi mentarget project Supabase yang sama.

## 2. Perintah

```bash
supabase start          # jalankan stack lokal (Docker)
supabase db reset       # terapkan ulang semua migrasi + seed
supabase functions serve
supabase db push        # dorong migrasi ke project cloud
```

## 3. Ekstensi

`postgis` (geospasial "bengkel terdekat") dan `pgcrypto` (UUID/randomness). Lihat `0001_extensions.sql`.

## 4. Geospasial

`workshops.location` bertipe `geography(Point,4326)`. Query terdekat lewat RPC `nearby_workshops(lat, lng, radius_m, limit_n)` yang memakai `ST_DWithin` + `ST_Distance` dan hanya mengembalikan bengkel `status='verified'` & aktif. Index GiST pada `location`.

## 5. Row Level Security

RLS **aktif di semua tabel**. Prinsip:
- `users`/`vehicles`/`bookings`/`favorites`/`notifications`/`oil_reminders`: pemilik baris (`auth.uid()`) saja.
- `workshops`/`services`/`workshop_hours`/`slots`: baca publik bila `verified`; tulis hanya oleh owner-nya.
- `workshop_documents`: tulis oleh owner; **tidak** ada baca publik (hanya admin via service role / signed URL).
- `payments`/`payouts`/`refunds`: dibuat/di-update oleh Edge Function (service role), dibaca pihak terkait saja.

## 6. Storage & batas 2 MB

Dua bucket:
- `workshop-photos` (publik, baca publik) — foto bengkel & foto ulasan.
- `verification-docs` (privat) — KTP, selfie, foto lokasi.

Keduanya diset `file_size_limit = 2097152` (2 MB) dan `allowed_mime_types` gambar. Lihat `0008_storage_buckets.sql`. Validasi kedua di klien (`MediaGuard`). Pesan gagal **persis**: *"ukuran media anda terlalu besar segera kompres file media untuk melanjutkan"*.

Akses dokumen privat untuk admin memakai signed URL ≤ 60 dtk (dibuat Edge Function di repo admin).

## 7. Edge Functions

| Function | Pemicu | Ringkas |
|---|---|---|
| `mayar-pay` | HTTP POST dari app (JWT pengendara) | Buat invoice Mayar via RPC `booking_create_payment`; simpan `invoice_url`+`gateway_txn_id`. |
| `payment-webhook` | Webhook Mayar (`--no-verify-jwt`) | Verifikasi token query string; `payment_mark` update `payments`+`bookings`; idempoten. |
| `oil-reminder-cron` | Cron harian | Recompute status oli; buat `notifications`; push. |
| `payout-batch` | Cron harian | Agregasi SELESAI H-1; potong komisi 8%; buat `payouts`; disbursement. |

Rahasia (`SERVICE_ROLE_KEY`, gateway secret, FCM key) disimpan sebagai secret Edge Functions, tidak pernah di klien. Setup Mayar lengkap: `docs/PAYMENTS_MAYAR.md`.

## 8. Trigger odometer → oli

Saat `service_records` dibuat dengan odometer baru: trigger memperbarui `vehicles.odometer`, menulis `odometer_logs`, dan menghitung ulang `oil_reminders` (target km = odometer + interval; target tanggal = tanggal servis + interval hari).
