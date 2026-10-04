# SCREENS — BengkelKu Mobile

Inventaris layar + perilaku + data/akses Supabase. ID layar cocok dengan prototipe desain. Route didefinisikan di `lib/app/router.dart`.

## Pengendara (Rider)

| ID | Layar | Perilaku & data |
|---|---|---|
| `splash` | Splash | Cek sesi Supabase Auth → arahkan ke home/login. |
| `onboarding` | Onboarding | 3 slide nilai; sekali tampil. |
| `login` | Masuk/Daftar | Email+password, Google, Apple; lupa sandi. |
| `location` | Izin lokasi | Minta izin; fallback cari kota. |
| `home` | Beranda | Bengkel terdekat (RPC `nearby_workshops`), pencarian, akses peta, pengingat oli ringkas. |
| `nearby` | Bengkel terdekat | Daftar diurut jarak + filter (jarak, rating, buka, harga). |
| `map` | Peta | Pin bengkel; tap → kartu ringkas → detail. |
| `detail` | Detail bengkel | Profil, layanan (`services`), ulasan, slot, favorit. |
| `schedule` | Pilih jadwal | Pilih layanan + kendaraan + tanggal/slot. |
| `review` (ringkasan) | Ringkasan booking | Rincian biaya + total; lanjut bayar. |
| `payment` | Pembayaran | Buat `payments` via gateway; status realtime. |
| `paymentFailed` | Pembayaran gagal | Pesan + coba lagi. |
| `paymentExpired` | Pembayaran kedaluwarsa | Booking `KEDALUWARSA`; buat ulang. |
| `success` | Sukses | Konfirmasi + ke tiket. |
| `ticket` | Tiket booking | Status realtime (state machine), check-in, batal (sheet). |
| `bookings` | Daftar booking | Aktif & lampau. |
| `bookingEnded` | Booking berakhir | Selesai/batal/no-show; CTA ulasan. |
| `cancelSheet` | Sheet batal | Terapkan kebijakan refund (≥2 jam 100%, <2 jam 50%, no-show 0%). |
| `garage` | Garasi | Daftar kendaraan + odometer + status oli. |
| `oilDetail` | Detail oli | OilGauge, target km/tanggal, snooze, CTA booking. |
| `snoozeSheet` | Tunda pengingat | Pilih durasi tunda. |
| `profile` | Profil | Edit profil, zona waktu, logout, hapus akun. |
| `favorites` | Favorit | Daftar bengkel favorit. |
| `notif` | Notifikasi | Pusat notifikasi in-app. |
| `notifSettings` | Pengaturan notifikasi | Preferensi push. |
| `reviewList` | Daftar ulasan | Ulasan sebuah bengkel. |
| `rateForm` | Form ulasan | Rating+teks+foto (≤ 2 MB) setelah SELESAI. |

## Pemilik Bengkel (Owner)

| ID | Layar | Perilaku & data |
|---|---|---|
| `regVerify` | Registrasi + verifikasi | Profil bengkel, pin lokasi, jam, layanan, foto; unggah KTP+selfie+foto lokasi (≤ 2 MB, kamera in-app untuk selfie/lokasi). |
| `regStatus` | Status verifikasi | Menunggu/disetujui/ditolak + alasan; ajukan ulang. |
| `ownerDash` | Dashboard owner | Booking masuk (realtime), antrean, aksi terima/tolak. |
| `ownerScan` | Scan/check-in | Konfirmasi kedatangan pelanggan. |
| `ownerRecord` | Input riwayat servis | Pekerjaan + tambahan + odometer + catatan → memicu pengingat oli. |
| `rejectSheet` | Sheet tolak booking | Alasan penolakan → refund 100%. |
| `ownerReviews` | Ulasan masuk | Lihat rating/ulasan. |
| `ownerWallet` | Dompet | Saldo, riwayat payout. |
| `payoutDetail` | Detail payout | Rincian komisi 8% & disbursement. |
| `bankAccount` | Rekening bank | Rekening tujuan payout. |

## Catatan akses
- Semua query tunduk RLS. Rider melihat miliknya; owner mengelola bengkelnya.
- Dokumen verifikasi tidak dibaca di app setelah diunggah (privat; hanya admin).
- Tidak ada layar/route admin di aplikasi ini.
