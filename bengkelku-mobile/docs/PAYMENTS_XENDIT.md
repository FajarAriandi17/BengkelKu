# PAYMENTS — Integrasi Xendit

Gateway pembayaran produksi BengkelKu adalah **Xendit** (Invoice API v2) untuk
QRIS, e-wallet, dan virtual account. Mode **sandbox** tetap tersedia untuk demo
& pengujian tanpa dana sungguhan. Lihat `docs/PRD.md` Bagian 8.5 (FR-P).

> Rahasia Xendit (`XENDIT_SECRET_KEY`, `XENDIT_WEBHOOK_TOKEN`) **hanya** ada di
> Edge Functions (`supabase/functions/`), tidak pernah di aplikasi mobile.
> Lihat `docs/ARCHITECTURE.md` §3.

## 1. Arus pembayaran

```
App (payment_screen)
  │  functions.invoke("xendit-pay", {booking_id, method})   ← JWT pengendara
  ▼
Edge Function xendit-pay
  │  1. RPC booking_create_payment(booking, method)
  │     • auth.uid() validasi kepemilikan + status MENUNGGU_PEMBAYARAN
  │     • nominal = bookings.total_idr (server, tidak bisa dimanipulasi)
  │     • insert payments (provider='xendit', status='pending', provider_ref)
  │     • idempoten: kembalikan intent lama bila sudah ada
  │  2. POST https://api.xendit.co/v2/invoices  (Basic auth secret key)
  │  3. RPC payment_set_invoice → simpan invoice_url + qr_string + expires_at
  ▼
App menampilkan PaymentInstructionSheet
  │  • QRIS  → QR dirender dari qr_string (qr_flutter)
  │  • e-wallet/VA → tombol buka invoice_url (url_launcher)
  │  • polling status booking tiap 3 detik
  ▼
Xendit memproses pembayaran
  │  webhook invoice.paid / invoice.expired
  ▼
Edge Function payment-webhook  (X-Callback-Token == XENDIT_WEBHOOK_TOKEN)
  │  RPC payment_mark(provider_ref, status, method, paid_at)
  │     • payments.status → paid/expired/failed  (idempoten)
  │     • bookings.status → DIBAYAR_MENUNGGU_KONFIRMASI / KEDALUWARSA
  │     • trigger trg_booking_paid_chat buat thread chat
  │     • notifikasi ke owner bengkel
  ▼
App mendeteksi perubahan status → /payment-success
```

Sesuai FR-P2 (escrow): dana ditahan platform hingga booking SELESAI, lalu
`payout-batch` mencairkan ke bengkel H+1 dikurangi komisi 8%.

## 2. Konfigurasi (admin)

Dua saklar di tabel `app_config` (migrasi 0023 & 0024):

| Key | Default | Keterangan |
|---|---|---|
| `payments_sandbox` | `true` | Mode simulasi (`booking_sandbox_pay`); harus `false` saat produksi. |
| `xendit_enabled` | `false` | Aktifkan alur Xendit produksi. |

Precedensi di klien: sandbox > xendit. Saat keduanya `false`, tombol bayar
dinonaktifkan ("Pembayaran online segera hadir").

Untuk menyalakan produksi:

```sql
update public.app_config set value = 'false'::jsonb where key = 'payments_sandbox';
update public.app_config set value = 'true'::jsonb  where key = 'xendit_enabled';
```

## 3. Setup Xendit (one-time)

1. Daftar akun Xendit, verifikasi bisnis (KYB), aktifkan QRIS/e-wallet/VA.
2. Dashboard → **Settings → API Keys**: salin **Secret key**.
3. Dashboard → **Settings → Callbacks**: salin **Verification Token**, lalu
   daftarkan URL webhook produksi:
   ```
   https://<project-ref>.functions.supabase.co/payment-webhook
   ```
   Centang event: `invoice.paid`, `invoice.expired` (dan opsional
   `payment.succeeded`, `payment.failed`).
4. Set secret di Supabase:
   ```bash
   supabase secrets set \
     XENDIT_SECRET_KEY=xnd_secret_development_... \
     XENDIT_WEBHOOK_TOKEN=<verification token>
   ```
   (`XENDIT_API_BASE` opsional untuk test mode, default `https://api.xendit.co`.)
5. Deploy Edge Functions:
   ```bash
   supabase functions deploy xendit-pay
   supabase functions deploy payment-webhook --no-verify-jwt
   ```
   `--no-verify-jwt` wajib untuk webhook — Xendit tidak membawa JWT Supabase;
   keamanan dijamin oleh `X-Callback-Token`.
6. Jalankan ulang langkah 2 untuk menyalakan `xendit_enabled`.

## 4. Skema data (migrasi 0024)

Tabel `payments` mendapat kolom baru:

| Kolom | Keterangan |
|---|---|
| `invoice_url` | Tautan hosted checkout Xendit. |
| `qr_string` | String QRIS untuk dirender di aplikasi. |
| `expires_at` | Kedaluwarsa invoice gateway. |

`provider_ref` (unik) = Xendit `external_id` = `bk-<booking-id-tanpa-strip>`;
berperan sebagai kunci idempotensi webhook.

RPC baru (lihat `supabase/migrations/0024_xendit_payments.sql`):

| RPC | Akses | Tugas |
|---|---|---|
| `booking_create_payment(booking, method)` | `authenticated` | Buat/ambil intent pending; validasi nominal & deadline. |
| `payment_set_invoice(ref, url, qr, exp)` | `service_role` | Simpan hasil create-invoice. |
| `payment_mark(ref, status, method, paid_at)` | `service_role` | Transisi status dari webhook; idempoten. |

## 5. Uji

SQL (butuh PostgreSQL + PostGIS lokal):

```bash
PGHOST=/var/run/postgresql bash supabase/tests/run_local.sh
```

Mencakup: penolakan gateway nonaktif, kepemilikan, idempotensi intent,
lunas → DIBAYAR_MENUNGGU_KONFIRMASI + thread chat + notifikasi owner,
idempotensi webhook ulang, kedaluwarsa otomatis, dan kegagalan yang dapat
dicoba ulang. Output sukses: `XENDIT_PAYMENT_OK`.

Uji gateway asli (test mode Xendit): set `XENDIT_API_BASE` ke
`https://api.xendit.co` dengan secret key test-mode Xendit, buat booking di app,
pilih QRIS, lalu bayar pakai QR simulator di dashboard Xendit → webhook masuk →
status booking berubah.

## 6. Catatan

- **Aman diulang**: `payment_mark` menolak mengubah transaksi `paid`/`refunded`;
  `booking_create_payment` mengembalikan intent yang sama untuk booking yang sama.
- **Webhook sebelum invoice tersimpan**: `payment-webhook` mengembalikan 500 agar
  Xendit mengirim ulang — `provider_ref` sudah ada sejak `booking_create_payment`.
- **Nominal**: klien tidak pernah mengirim angka ke gateway. `xendit-pay`
  mengambil `amount_idr` dari RPC yang membaca `bookings.total_idr`.
- **Refund**: pembatalan pengendara tetap lewat `booking_cancel` (PRD Bagian 7).
  Pengembalian dana via API refund Xendit belum tersambung (P1) — saat ini
  `refunds.status='processing'` dicatat untuk rekonsiliasi manual.
- **Notifikasi push**: webhook memasukkan baris `notifications`; pengiriman push
  FCM/APNs mengikuti alur notifikasi yang ada.
