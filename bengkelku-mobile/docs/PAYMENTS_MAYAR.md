# PAYMENTS — Integrasi Mayar.id

Gateway pembayaran produksi BengkelKu adalah **Mayar** (Headless API v2). Halaman hosted
checkout-nya menampilkan semua kanal aktif (QRIS, e-wallet, virtual account, retail), dan
kanal aktual tercatat di DB dari payload webhook. Mode **sandbox** tetap tersedia untuk demo
& pengujian tanpa dana sungguhan. Lihat `docs/PRD.md` Bagian 8.5 (FR-P).

> Rahasia Mayar (`MAYAR_API_KEY`, `MAYAR_WEBHOOK_SECRET`) **hanya** ada di Edge Functions
> (`supabase/functions/`), tidak pernah di aplikasi mobile. Lihat `docs/ARCHITECTURE.md` §3.

## 1. Arus pembayaran

```
App (payment_screen)
  │  functions.invoke("mayar-pay", {booking_id})   ← JWT pengendara
  ▼
Edge Function mayar-pay
  │  1. RPC booking_create_payment(booking)
  │     • auth.uid() validasi kepemilikan + status MENUNGGU_PEMBAYARAN
  │     • nominal = bookings.total_idr (server, tidak bisa dimanipulasi)
  │     • insert payments (provider='mayar', status='pending', provider_ref)
  │     • kembalikan juga customer (nama/email/no HP) + item + biaya layanan
  │     • idempoten: kembalikan intent lama bila sudah ada
  │  2. POST https://api.mayar.id/hl/v2/invoices/create  (Bearer API key)
  │     • item layanan + satu line item "Biaya layanan" bila ada fee
  │     • extraData = {provider_ref} (traceability)
  │     • tanpa paymentMethod → hosted page tampilkan semua kanal aktif
  │  3. RPC payment_set_invoice → simpan link + gateway_txn_id + expires_at
  ▼
App menampilkan PaymentInstructionSheet
  │  • tombol "Buka Halaman Pembayaran" → invoice_url (url_launcher)
  │  • polling status booking tiap 3 detik
  ▼
Mayar memproses pembayaran (kanal dipilih di hosted page)
  │  webhook payment.received  (data.status = true)
  ▼
Edge Function payment-webhook  (token di query string == MAYAR_WEBHOOK_SECRET)
  │  RPC payment_mark(gateway_txn_id, status, method, amount)
  │     • validasi nominal webhook == payments.amount_idr
  │     • payments.status → paid/failed  (idempoten)
  │     • payments.method ← kanal pilihan pengguna
  │     • bookings.status → DIBAYAR_MENUNGGU_KONFIRMASI
  │     • trigger trg_booking_paid_chat buat thread chat
  │     • notifikasi ke owner bengkel
  ▼
App mendeteksi perubahan status → /payment-success
```

Sesuai FR-P2 (escrow): dana ditahan platform hingga booking SELESAI, lalu
`payout-batch` mencairkan ke bengkel H+1 dikurangi komisi 8%.

## 2. Konfigurasi (admin)

Dua saklar di tabel `app_config` (migrasi 0023 & 0025):

| Key | Default | Keterangan |
|---|---|---|
| `payments_sandbox` | `true` | Mode simulasi (`booking_sandbox_pay`); harus `false` saat produksi. |
| `mayar_enabled` | `false` | Aktifkan alur Mayar produksi. |

Precedensi di klien: sandbox > mayar. Saat keduanya `false`, tombol bayar
dinonaktifkan ("Pembayaran online segera hadir").

Untuk menyalakan produksi:

```sql
update public.app_config set value = 'false'::jsonb where key = 'payments_sandbox';
update public.app_config set value = 'true'::jsonb  where key = 'mayar_enabled';
```

## 3. Setup Mayar (one-time)

1. Daftar akun di [mayar.id](https://mayar.id) (produksi) atau [web.mayar.io](https://web.mayar.io)
   (sandbox), verifikasi bisnis, aktifkan kanal QRIS/e-wallet/VA/retail di pengaturan
   *Payment Method*.
2. Buat API key (tipe **Read & Write**) di
   [web.mayar.id/api-keys](https://web.mayar.id/api-keys).
3. Dashboard → **Integration → Webhook**: daftarkan URL webhook produksi **lengkap dengan
   token rahasia** (Mayar tidak mengirim signature header, jadi token ini satu-satunya
   kunci verifikasi):
   ```
   https://<project-ref>.functions.supabase.co/payment-webhook?token=<MAYAR_WEBHOOK_SECRET>
   ```
   Lalu klik *test* untuk memastikan URL terjangkau.
4. Set secret di Supabase:
   ```bash
   supabase secrets set \
     MAYAR_API_KEY=<api-key-read-and-write> \
     MAYAR_WEBHOOK_SECRET=<token-acak-yang-anda-buat> \
     MAYAR_MERCHANT_ID=<opsional-untuk-lapisan-verifikasi-kedua>
   ```
   (`MAYAR_API_BASE` opsional; default `https://api.mayar.id/hl/v2`. Untuk sandbox:
   `https://api.mayar.io/hl/v2` dipakai bersama API key dari web.mayar.io.)
5. Deploy Edge Functions:
   ```bash
   supabase functions deploy mayar-pay
   supabase functions deploy payment-webhook --no-verify-jwt
   ```
   `--no-verify-jwt` wajib untuk webhook — Mayar tidak membawa JWT Supabase;
   keamanan dijamin oleh token di query string + validasi merchant + kecocokan nominal.
6. Jalankan ulang langkah 2 untuk menyalakan `mayar_enabled`.

## 4. Skema data (migrasi 0025)

Tabel `payments`:

| Kolom | Keterangan |
|---|---|
| `invoice_url` | Tautan hosted checkout Mayar. |
| `gateway_txn_id` | `transactionId` Mayar — kunci lookup webhook (unik). |
| `expires_at` | Kedaluwarsa invoice gateway. |

`provider_ref` (unik) = `bk-<booking-id-tanpa-strip>`; dikirim ke Mayar sebagai
`extraData.provider_ref` untuk traceability dan dipakai `payment_set_invoice`.

RPC (lihat `supabase/migrations/0025_mayar_payments.sql`):

| RPC | Akses | Tugas |
|---|---|---|
| `booking_create_payment(booking)` | `authenticated` | Buat/ambil intent pending; validasi nominal & deadline; sertakan data invoice (customer + items). |
| `payment_set_invoice(ref, url, txn, exp)` | `service_role` | Simpan hasil create-invoice. |
| `payment_mark(txn, status, method, amount)` | `service_role` | Transisi status dari webhook; idempoten; validasi nominal. |

## 5. Uji

SQL (butuh PostgreSQL + PostGIS lokal):

```bash
PGHOST=/var/run/postgresql bash supabase/tests/run_local.sh
```

Mencakup: penolakan gateway nonaktif, kepemilikan, data customer+items ikut intent,
idempotensi intent, `payment_set_invoice`, `payment_mark` hanya untuk service role,
nominal webhook salah ditolak, lunas → DIBAYAR_MENUNGGU_KONFIRMASI + thread chat +
notifikasi owner, idempotensi webhook ulang, kedaluwarsa otomatis, dan kegagalan yang
dapat dicoba ulang. Output sukses: `MAYAR_PAYMENT_OK`.

Dart:

```bash
flutter test test/payment_intent_test.dart
```

Uji gateway asli (sandbox Mayar): set `MAYAR_API_BASE=https://api.mayar.io/hl/v2` +
`MAYAR_API_KEY` sandbox, buat booking di app, tekan Bayar → halaman Mayar tampilkan semua
kanal → bayar pakai QR simulator → webhook `payment.received` masuk → status booking
berubah menjadi DIBAYAR_MENUNGGU_KONFIRMASI.

## 6. Catatan

- **Aman diulang**: `payment_mark` menolak mengubah transaksi `paid`/`refunded`;
  `booking_create_payment` mengembalikan intent yang sama untuk booking yang sama.
- **Webhook sebelum invoice tersimpan**: `payment-webhook` mengembalikan 500 agar Mayar
  mengirim ulang — `gateway_txn_id` disimpan segera setelah `payment_set_invoice`.
- **Nominal**: klien tidak pernah mengirim angka ke gateway. `mayar-pay` mengambil
  `amount_idr` dari RPC yang membaca `bookings.total_idr`, dan webhook divalidasi terhadap
  nilai tersebut.
- **Biaya layanan**: Mayar menjumlahkan item invoice sendiri, sehingga
  `user_service_fee` ditambahkan sebagai line item tersendiri agar total yang ditagih
  sama persis dengan `bookings.total_idr`.
- **Kedaluwarsa**: Mayar tidak mengirim event kedaluwarsa. Timer `payment_deadline` di
  app menampilkan hitung mundur, dan booking otomatis `KEDALUWARSA` saat pengguna
  mencoba membayar setelah batas waktu (di dalam RPC).
- **Refund**: pembatalan pengendara tetap lewat `booking_cancel` (PRD Bagian 7).
  Pengembalian dana via API Mayar belum tersambung (P1) — saat ini
  `refunds.status='processing'` dicatat untuk rekonsiliasi manual.
- **Notifikasi push**: webhook memasukkan baris `notifications`; pengiriman push
  FCM/APNs mengikuti alur notifikasi yang ada.
