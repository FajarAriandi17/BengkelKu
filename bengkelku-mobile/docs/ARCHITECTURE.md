# ARCHITECTURE — BengkelKu Mobile

Bagaimana aplikasi dibangun di atas **Supabase**. Lihat `docs/PRD.md` untuk *apa* & *kenapa*, dan `supabase/migrations/*` untuk skema nyata.

## 1. Gambaran besar

```
┌─────────────────┐        ┌─────────────────────┐
│  Flutter (app)  │        │  Next.js (admin web)│
│  Rider + Owner  │        │  repo terpisah      │
└────────┬────────┘        └──────────┬──────────┘
         │  Supabase SDK (JWT aud=mobile)      │ (JWT aud=admin)
         ▼                                      ▼
┌───────────────────────────────────────────────────────┐
│                      SUPABASE                           │
│  Auth · Postgres+PostGIS · Storage · Realtime           │
│  Edge Functions (Deno) · Row Level Security             │
└───────────────────────────────────────────────────────┘
         │                 │                 │
         ▼                 ▼                 ▼
   Mayar (bayar)       FCM / APNs       Google Maps
   + payout-batch      (push)           (peta)
```

Kedua aplikasi memakai **satu project Supabase**. Skema kanonik ada di repo mobile (`supabase/`). Admin web hanya menambah migrasi khusus admin (roles, audit, RLS admin).

## 2. Lapisan aplikasi (Flutter)

Arsitektur feature-first + Riverpod:

```
lib/
├── app/        app.dart (root), router.dart (go_router)
├── core/       theme (token), motion, network (supabase_client), utils, l10n
├── design/     komponen UI reusable (katalog di DESIGN_SYSTEM.md)
└── features/   auth, location, workshops, booking, payment, garage,
                oil, favorites, notifications, reviews, owner
```

Setiap feature: `data/` (repository + model DTO), `domain/` (entity + logika murni), `presentation/` (provider + screen + widget). Logika murni (mis. `oil_calculator.dart`) tidak menyentuh I/O agar mudah diuji.

## 3. Akses data & keamanan

- Semua akses DB lewat Supabase SDK dengan **RLS aktif**. Klien **tidak** boleh mengandalkan filter sisi klien untuk keamanan.
- Pengguna hanya bisa membaca/menulis barisnya sendiri (users, vehicles, bookings, dll.). Bengkel hanya mengelola data bengkelnya. Lihat `supabase/migrations/0007_rls_policies.sql`.
- Dokumen privat (KTP/selfie) tidak pernah dibaca langsung dari klien; hanya admin via signed URL (≤ 60 dtk) yang dibuat Edge Function.
- Rahasia (service_role key, gateway secret) hanya ada di Edge Functions, tidak pernah di app.

## 4. Aturan media 2 MB (dua lapis)

1. **Klien** — `lib/core/utils/media_guard.dart` → `MediaGuard.ensureUnderLimit(bytes)` menolak berkas > 2.097.152 byte dan melempar pesan **persis**: *"ukuran media anda terlalu besar segera kompres file media untuk melanjutkan"*.
2. **Server** — kebijakan bucket Supabase Storage membatasi `file_size_limit = 2MB` (lihat `supabase/migrations/0008_storage_buckets.sql`).

Tujuan: hemat kuota free tier. (P1) kompresi gambar otomatis sebelum unggah.

## 5. Realtime

Status booking memakai Supabase Realtime (postgres changes pada `bookings`). Tiket & dashboard owner subscribe ke baris relevan dan memperbarui UI tanpa polling.

## 6. Edge Functions (Deno)

| Function | Pemicu | Tugas |
|---|---|---|
| `mayar-pay` | App (JWT pengendara) | Buat invoice Mayar via RPC `booking_create_payment`; simpan `invoice_url`+`gateway_txn_id`. |
| `payment-webhook` | Webhook Mayar | Verifikasi token query string; update `payments` + `bookings` (idempoten). |
| `oil-reminder-cron` | Cron harian | Hitung ulang status oli, buat `notifications`, kirim push. |
| `payout-batch` | Cron harian | Agregasi booking SELESAI H-1, potong komisi 8%, buat `payouts` + disbursement. |

## 7. Pembayaran (escrow)

Pengendara bayar penuh → dana ditahan platform → saat SELESAI, H+1 payout ke bengkel dikurangi komisi. Refund mengikuti kebijakan pembatalan (PRD Bagian 7). Webhook harus idempoten (gunakan `gateway_txn_id` unik). Detail setup & alur Mayar: `docs/PAYMENTS_MAYAR.md`.

## 8. Zona waktu & format

Simpan semua timestamp **UTC** di DB. Tampilkan di zona bengkel (WIB/WITA/WIT) via util `formatters.dart`. Uang: `Rp 55.000`.

## 9. Observabilitas

Sentry (`sentry_flutter`) menangkap crash & error. Edge Functions menulis log terstruktur. Metrik produk (PRD Bagian 3) ditarik dari tabel + event.
