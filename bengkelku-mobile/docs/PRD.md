# PRD — BengkelKu

**Aplikasi Marketplace Bengkel Motor: Booking Servis, Bengkel Terdekat (GPS) & Pengingat Ganti Oli**

| | |
|---|---|
| **Versi** | 1.2 (adaptasi stack ke Supabase) |
| **Tanggal** | 2 Oktober 2026 |
| **Platform** | Android & iOS (satu codebase Flutter) + Admin Web Panel (repo terpisah) |
| **Backend & Database** | **Supabase** (Postgres + PostGIS, Auth, Storage, Realtime, Edge Functions) |
| **Status** | Keputusan utama terkonfirmasi; sisa pertanyaan terbuka di Bagian 19 |

---

## Riwayat Revisi

| Versi | Perubahan |
|---|---|
| 1.0 | Draf awal |
| 1.1 | Peluncuran nasional; komisi 8% & kebijakan pembatalan dikonfirmasi; dokumen verifikasi disederhanakan (KTP + selfie + foto lokasi, NIB tidak wajib) |
| **1.2** | **Stack backend/database ditetapkan ke Supabase**; **batas unggah media 2 MB** ditambahkan sebagai kebutuhan fungsional (FR-U1); admin web dipisah menjadi repo sendiri |

---

## 1. Ringkasan Produk

BengkelKu adalah marketplace dua sisi yang mempertemukan **pemilik motor** dengan **bengkel motor** di sekitar mereka. Siapa pun dapat mendaftarkan usaha bengkelnya; setelah diverifikasi admin (di admin web), bengkel tampil di peta dan daftar "Bengkel Terdekat" berbasis GPS. Pengendara dapat memesan servis, membayar penuh secara online, dan menerima **pengingat ganti oli pintar** berdasarkan kilometer + waktu, di mana odometer diperbarui otomatis dari riwayat servis yang diinput bengkel.

### Keputusan kunci

| Topik | Keputusan |
|---|---|
| Pembayaran | Bayar penuh online (dana ditahan platform sampai servis selesai, lalu dicairkan ke bengkel) |
| Onboarding bengkel | Verifikasi admin dulu (foto, alamat, dokumen) sebelum tayang |
| Pengingat oli | Kilometer + waktu; odometer diperbarui otomatis dari riwayat servis |
| Cakupan peluncuran | Seluruh Indonesia |
| Komisi platform | 8% dari setiap transaksi |
| Kebijakan pembatalan | Refund 100% bila batal ≥ 2 jam sebelum slot; 50% bila < 2 jam; no-show 0% |
| Tambahan pekerjaan | Tetap P1 |
| Dokumen verifikasi bengkel | KTP + selfie memegang KTP + foto ruko/lokasi; NIB tidak wajib |
| **Infrastruktur** | **Supabase** untuk auth, database (Postgres+PostGIS), storage, realtime, dan serverless (Edge Functions) |
| **Batas media** | **Maks 2 MB per berkas** (KTP, selfie, foto bengkel/ulasan) agar hemat kuota Supabase free tier |

---

## 2. Latar Belakang & Masalah

**Masalah pengendara:** sulit menemukan bengkel terpercaya terdekat; tidak tahu harga di muka; antre lama; lupa ganti oli; riwayat servis tercecer.

**Masalah bengkel:** minim visibilitas digital; tidak punya sistem booking; antrean tidak terprediksi; tidak ada cara mengingatkan pelanggan kembali.

**Peluang:** populasi sepeda motor Indonesia sangat besar dengan ribuan bengkel independen belum terdigitalisasi. Kombinasi *discovery* berbasis lokasi + *retention* lewat pengingat oli menciptakan siklus kunjungan berulang.

---

## 3. Tujuan & Metrik Sukses

### Tujuan MVP
1. Pengendara menemukan bengkel terdekat < 10 detik sejak membuka aplikasi.
2. Pengendara menyelesaikan booking + pembayaran < 3 menit.
3. Bengkel mendaftar, lolos verifikasi, menerima booking pertama tanpa bantuan tim.
4. Pengingat oli mendorong pengguna kembali booking.

### Metrik (target 3 bulan pertama)

| Metrik | Target |
|---|---|
| Bengkel terverifikasi tayang | ≥ 300, ≥ 10 kota/kabupaten |
| Waktu verifikasi bengkel (median) | ≤ 48 jam |
| Pengguna terdaftar | ≥ 10.000 |
| Konversi lihat detail → booking | ≥ 8% |
| Payment success rate | ≥ 95% |
| Booking diterima bengkel | ≥ 85% |
| Pengguna punya ≥ 1 motor di Garasi | ≥ 70% |
| Reminder → booking (7 hari) | ≥ 10% |
| Retensi D30 | ≥ 25% |
| Rating rata-rata bengkel | ≥ 4,2 |

---
## 4. Peran Pengguna

| Peran | Di mana | Ringkas |
|---|---|---|
| **Pengendara (Rider)** | Aplikasi mobile | Cari bengkel, booking, bayar, kelola Garasi motor, terima pengingat oli, beri ulasan. |
| **Pemilik Bengkel (Owner)** | Aplikasi mobile | Daftarkan bengkel, kelola jadwal/slot & layanan, terima/tolak booking, input riwayat servis + odometer, kelola dompet & payout. |
| **Admin / Developer** | **Admin web (repo terpisah)** | Verifikasi & setujui/tolak bengkel sebelum tayang, moderasi, konfigurasi, keuangan. **Tidak ada di aplikasi mobile.** |

Satu akun bisa menjadi Rider sekaligus Owner (peran ganda). Peran admin benar-benar terpisah: akun admin memakai JWT `aud=admin`, akun mobile memakai `aud=mobile`. Tidak ada jalur signup admin dari mobile.

---

## 5. Lingkup

### Dalam lingkup (MVP)
- Autentikasi (email+password, Google, Apple) via Supabase Auth.
- Discovery bengkel: daftar "terdekat" (GPS) + peta.
- Detail bengkel: layanan, harga, jam buka, foto, ulasan, slot.
- Booking + pembayaran penuh online (escrow), konfirmasi bengkel, check-in, pengerjaan, selesai, payout H+1.
- Pekerjaan tambahan saat servis (P1) dengan persetujuan pengendara.
- Garasi motor + riwayat servis + odometer otomatis.
- Pengingat oli pintar (km + waktu).
- Ulasan & rating.
- Favorit.
- Notifikasi (push + in-app).
- Onboarding bengkel + unggah dokumen verifikasi (≤ 2 MB).
- Dompet owner & riwayat payout.

### Di luar lingkup (MVP)
- Chat realtime pengendara–bengkel (P2).
- Berlangganan/paket servis (P2).
- Multi-cabang bengkel (P2).
- Spare-part marketplace (P2).
- Program loyalitas/poin (P2).
- OTP nomor HP (P1, menyusul).

---

## 6. Alur Pengguna Inti

### 6.1 Pengendara: temukan → booking → bayar
1. Buka app → (login/daftar) → izin lokasi.
2. Home menampilkan bengkel terdekat + pencarian + peta.
3. Pilih bengkel → lihat detail (layanan, harga, slot).
4. Pilih layanan + tanggal/slot → ringkasan → bayar penuh.
5. Pembayaran berhasil → tiket booking (status realtime).
6. Bengkel konfirmasi → pengendara check-in → dikerjakan → selesai.
7. Dana dicairkan ke bengkel H+1 setelah selesai. Pengendara diminta memberi ulasan.

### 6.2 Pengendara: pengingat oli
1. Setelah servis, bengkel menginput riwayat (termasuk odometer & apakah ganti oli).
2. Sistem menghitung target ganti oli berikutnya (km + tanggal).
3. Mendekati ambang (≤ 300 km atau ≤ 7 hari) → status "segera"; lewat → "telat".
4. Notifikasi mengarahkan pengendara untuk booking lagi.

### 6.3 Bengkel: daftar → verifikasi → tayang
1. Owner daftar usaha: isi profil, alamat (pin peta), jam, layanan+harga, foto bengkel.
2. Unggah dokumen: KTP + selfie memegang KTP + foto ruko/lokasi (semua ≤ 2 MB).
3. Status "menunggu verifikasi". **Admin (di admin web)** meninjau.
4. Disetujui → bengkel tayang. Ditolak → owner melihat alasan & dapat memperbaiki.

### 6.4 Bengkel: kelola booking
1. Terima notifikasi booking baru → konfirmasi / tolak (dengan alasan).
2. Saat pelanggan datang: scan/konfirmasi check-in.
3. Input pekerjaan (termasuk tambahan dengan persetujuan pengendara).
4. Tandai selesai + input odometer & catatan servis.

---

## 7. Kebijakan Bisnis

| Kebijakan | Aturan |
|---|---|
| Komisi platform | 8% dari nilai transaksi (dapat dikonfigurasi di admin). |
| Pencairan (payout) | H+1 setelah status SELESAI, batch harian. |
| Pembatalan oleh pengendara | ≥ 2 jam sebelum slot: refund 100%. < 2 jam: refund 50%. Tidak hadir (no-show): refund 0%. |
| Penolakan oleh bengkel | Refund 100% ke pengendara. |
| Kedaluwarsa pembayaran | Booking batal otomatis bila pembayaran tidak selesai dalam tenggat (default 60 menit). |
| Pekerjaan tambahan | Harus disetujui pengendara di app sebelum ditagih. |
| Zona waktu | Simpan UTC; tampilkan di zona waktu bengkel (WIB/WITA/WIT). |
| Mata uang | Rupiah, format `Rp 55.000`. |

---
## 8. Kebutuhan Fungsional

Prioritas: **P0** = wajib MVP, **P1** = segera setelah MVP.

### 8.1 Autentikasi & Akun (FR-A)
- **FR-A1 (P0)** Daftar/masuk dengan email+password via Supabase Auth.
- **FR-A2 (P0)** Masuk dengan Google & Apple (Sign in with Apple wajib untuk rilis iOS).
- **FR-A3 (P0)** Lupa kata sandi (reset via email).
- **FR-A4 (P0)** Kelola profil: nama, foto, nomor HP, zona waktu.
- **FR-A5 (P1)** Verifikasi nomor HP via OTP.
- **FR-A6 (P0)** Logout & hapus akun (sesuai kebijakan store).

### 8.2 Lokasi & Discovery (FR-L)
- **FR-L1 (P0)** Minta izin lokasi; tangani kondisi ditolak (fallback input kota/alamat manual).
- **FR-L2 (P0)** Daftar "Bengkel Terdekat" diurut jarak (PostGIS `ST_Distance`/`ST_DWithin`).
- **FR-L3 (P0)** Peta dengan pin bengkel (Google Maps), gaya peta kustom.
- **FR-L4 (P0)** Pencarian berdasarkan nama/layanan + filter (jarak, rating, buka sekarang, harga).
- **FR-L5 (P0)** Hanya bengkel **terverifikasi & aktif** yang tampil.

### 8.3 Detail Bengkel (FR-W)
- **FR-W1 (P0)** Tampilkan profil: foto, alamat, jam buka (status buka/tutup sekarang), kontak.
- **FR-W2 (P0)** Daftar layanan + harga + estimasi durasi.
- **FR-W3 (P0)** Ringkasan rating + daftar ulasan.
- **FR-W4 (P0)** Ketersediaan slot per tanggal (dari konfigurasi slot bengkel).
- **FR-W5 (P0)** Tombol favorit & bagikan.

### 8.4 Booking (FR-B)
- **FR-B1 (P0)** Pilih satu/lebih layanan + kendaraan dari Garasi + tanggal/slot.
- **FR-B2 (P0)** Ringkasan biaya (subtotal, komisi tersirat ke platform, total yang dibayar pengendara).
- **FR-B3 (P0)** State machine booking: `MENUNGGU_PEMBAYARAN → DIBAYAR_MENUNGGU_KONFIRMASI → DIKONFIRMASI → CHECK_IN → DIKERJAKAN → SELESAI → (H+1) PAYOUT`, plus `KEDALUWARSA`, `DITOLAK`, `DIBATALKAN`, `TIDAK_HADIR`.
- **FR-B4 (P0)** Status booking realtime (Supabase Realtime) di tiket.
- **FR-B5 (P0)** Pembatalan oleh pengendara mengikuti kebijakan refund (Bagian 7).
- **FR-B6 (P1)** Pekerjaan tambahan: owner mengajukan item tambahan → pengendara menyetujui → ditagih/diselesaikan di akhir.
- **FR-B7 (P0)** Riwayat booking (aktif & lampau).

### 8.5 Pembayaran & Keuangan (FR-P)
- **FR-P1 (P0)** Bayar penuh online via Midtrans/Xendit (QRIS, e-wallet, VA).
- **FR-P2 (P0)** Dana ditahan platform (escrow) sampai SELESAI.
- **FR-P3 (P0)** Webhook pembayaran diproses di Supabase Edge Function (idempoten).
- **FR-P4 (P0)** Refund sesuai kebijakan (penuh/50%/0%).
- **FR-P5 (P0)** Payout ke bengkel H+1 (batch) via disbursement; dompet owner menampilkan saldo & riwayat.
- **FR-P6 (P0)** Komisi 8% dipotong otomatis saat payout (konfigurasi via admin).

### 8.6 Garasi & Riwayat Servis (FR-G)
- **FR-G1 (P0)** Tambah/edit/hapus kendaraan (merek, model, tahun, plat, odometer awal, interval oli).
- **FR-G2 (P0)** Riwayat servis per kendaraan (dari input bengkel + manual).
- **FR-G3 (P0)** Odometer diperbarui otomatis dari riwayat servis terakhir; boleh koreksi manual.

### 8.7 Pengingat Oli (FR-O)
- **FR-O1 (P0)** Hitung target oli berikutnya = odometer saat servis + interval km, dan tanggal servis + interval hari.
- **FR-O2 (P0)** Status: `ok` / `soon` (≤ 300 km **atau** ≤ 7 hari tersisa) / `late` (≤ 0). Logika di fungsi murni `oilStage()`.
- **FR-O3 (P0)** Preset interval oli (mis. mineral 2.000 km, semi-sintetik 4.000 km, sintetik 6.000–10.000 km).
- **FR-O4 (P0)** Notifikasi pengingat (cron Edge Function harian) + CTA booking.
- **FR-O5 (P0)** Tunda (snooze) pengingat.

### 8.8 Ulasan & Favorit (FR-R)
- **FR-R1 (P0)** Beri rating (1–5) + ulasan teks + foto (≤ 2 MB) setelah SELESAI.
- **FR-R2 (P0)** Satu ulasan per booking selesai.
- **FR-R3 (P0)** Tandai/lepas favorit; daftar favorit.

### 8.9 Notifikasi (FR-N)
- **FR-N1 (P0)** Push (FCM + APNs) untuk status booking, pengingat oli, hasil verifikasi.
- **FR-N2 (P0)** Pusat notifikasi in-app + pengaturan preferensi.

### 8.10 Sisi Bengkel/Owner (FR-M)
- **FR-M1 (P0)** Registrasi bengkel: profil, pin lokasi, jam, layanan+harga, foto.
- **FR-M2 (P0)** Unggah dokumen verifikasi: KTP + selfie memegang KTP + foto ruko/lokasi (≤ 2 MB; selfie & foto lokasi via kamera in-app).
- **FR-M3 (P0)** Lihat status verifikasi + alasan penolakan; ajukan ulang.
- **FR-M4 (P0)** Konfigurasi slot & kapasitas per hari.
- **FR-M5 (P0)** Terima/tolak booking (dengan alasan) & kelola antrean.
- **FR-M6 (P0)** Check-in pelanggan, input pekerjaan + pekerjaan tambahan.
- **FR-M7 (P0)** Tandai selesai + input odometer & catatan servis (memicu pengingat oli).
- **FR-M8 (P0)** Lihat ulasan masuk.
- **FR-M9 (P0)** Dompet: saldo, riwayat payout, rekening bank tujuan.

### 8.11 Media & Unggahan (FR-U) — batas 2 MB
- **FR-U1 (P0)** **Setiap berkas media (KTP, selfie, foto lokasi/bengkel, foto ulasan) dibatasi maksimal 2 MB.** Validasi dilakukan di klien (`MediaGuard.ensureUnderLimit()`) **dan** di kebijakan bucket Supabase Storage. Bila melebihi, tampilkan pesan **persis**: *"ukuran media anda terlalu besar segera kompres file media untuk melanjutkan"*.
- **FR-U2 (P0)** Dokumen privat (KTP/selfie) disimpan di bucket privat; diakses hanya lewat signed URL (admin).
- **FR-U3 (P0)** Foto bengkel/ulasan di bucket publik (baca publik).
- **FR-U4 (P1)** Kompresi gambar sisi klien otomatis sebelum unggah untuk membantu memenuhi batas 2 MB.

---
## 9. Kebutuhan Non-Fungsional

| Area | Target |
|---|---|
| Performa UI | 60 fps; waktu buka ke daftar bengkel < 10 dtk; booking+bayar < 3 mnt. |
| Keamanan | Row Level Security (RLS) di semua tabel; dokumen privat via signed URL; tak ada rahasia di klien. |
| Privasi | KTP/selfie hanya untuk verifikasi; akses admin tercatat di audit log; masking data sensitif. |
| Aksesibilitas | Kontras AA, label a11y, target sentuh ≥ 44 px, hormati *Reduce Motion*. |
| Lokalisasi | Bahasa Indonesia; Rupiah; UTC disimpan, ditampilkan per zona bengkel. |
| Keandalan | Webhook pembayaran idempoten; payout batch dapat diulang aman. |
| Observabilitas | Sentry untuk crash/error; log Edge Functions. |
| Biaya | Hemat kuota Supabase free tier (termasuk batas media 2 MB) sebelum beralih ke paket berbayar. |

---

## 10. Model Data (ringkas)

Skema kanonik ada di `supabase/migrations/*`. **SQL adalah kebenaran struktur DB.** Entitas inti:

| Tabel | Isi utama |
|---|---|
| `users` | profil (tertaut `auth.users`), peran, zona waktu, foto. |
| `vehicles` | kendaraan milik pengguna (merek, model, tahun, plat, odometer, interval oli). |
| `odometer_logs` | histori pembacaan odometer (sumber otomatis/manual). |
| `workshops` | bengkel; lokasi `geography(POINT)`, status verifikasi, jam, rating agregat. |
| `workshop_documents` | KTP/selfie/foto lokasi (bucket privat), status per dokumen. |
| `workshop_hours` | jam buka per hari. |
| `workshop_slots_config` | kapasitas & slot per hari. |
| `services` | layanan + harga + durasi per bengkel. |
| `bookings` | pesanan + status (state machine) + total + jadwal. |
| `booking_items` | item layanan & pekerjaan tambahan per booking. |
| `payments` | transaksi gateway (status, metode, ref). |
| `refunds` | pengembalian dana (penuh/50%/0%). |
| `payouts` | pencairan ke bengkel (batch H+1, komisi). |
| `service_records` | riwayat servis (memicu update odometer & pengingat oli). |
| `oil_reminders` | target km/tanggal + status (ok/soon/late) + snooze. |
| `oil_interval_presets` | preset interval oli. |
| `reviews` | rating + teks + foto. |
| `favorites` | relasi pengguna–bengkel. |
| `notifications` | notifikasi in-app + status baca. |
| `audit_logs` | jejak aksi admin (dikelola admin web). |

---

## 11. Inventaris Layar (mobile)

**Pengendara:** splash, onboarding, login/daftar, izin lokasi, home, bengkel terdekat, peta, detail bengkel, pilih jadwal, ringkasan, pembayaran, pembayaran gagal, pembayaran kedaluwarsa, sukses, tiket booking, daftar booking, booking berakhir, sheet batal, Garasi, detail oli, sheet tunda, profil, favorit, notifikasi, pengaturan notifikasi, daftar ulasan, form ulasan.

**Pemilik bengkel:** registrasi+verifikasi, status verifikasi, dashboard owner, scan/check-in, input riwayat servis, sheet tolak, ulasan masuk, dompet, detail payout, rekening bank.

Detail interaksi & API per layar ada di `docs/SCREENS.md`; token & komponen di `docs/DESIGN_SYSTEM.md`; animasi di `docs/ANIMATIONS.md`.

---

## 12. Microcopy Kunci

| Konteks | Teks |
|---|---|
| Media > 2 MB | **ukuran media anda terlalu besar segera kompres file media untuk melanjutkan** |
| Lokasi ditolak | "kami butuh lokasi untuk menampilkan bengkel terdekat. kamu juga bisa cari lewat nama kota." |
| Booking dibuat | "booking kamu dibuat. selesaikan pembayaran sebelum tenggat ya." |
| Menunggu konfirmasi | "pembayaran diterima. menunggu bengkel mengonfirmasi booking kamu." |
| Pengingat oli (soon) | "oli motor kamu sudah dekat waktunya ganti. yuk booking sekarang." |
| Verifikasi disetujui | "selamat! bengkel kamu sudah tayang di BengkelKu." |

Sapaan memakai "kamu", huruf kecil biasa, istilah baku: bengkel, servis, booking, tiket, Garasi, odometer, pengingat oli.

---

## 13. Arsitektur & Teknologi (Supabase)

Keputusan: **backend & database = Supabase**, dengan satu codebase Flutter untuk mobile dan admin web terpisah (Next.js) yang memakai **project Supabase yang sama**.

| Lapisan | Teknologi |
|---|---|
| Mobile | Flutter 3.x (Dart 3), Riverpod, go_router. |
| Admin web | Next.js + TypeScript (repo `bengkelku-admin-web`). |
| Auth | **Supabase Auth** (email+password, Google, Apple; OTP HP P1). JWT `aud=mobile` vs `aud=admin`. |
| Database | **Supabase Postgres + PostGIS** (query bengkel terdekat). |
| Storage | **Supabase Storage** — bucket publik (foto bengkel/ulasan) & privat (KTP/selfie); **batas 2 MB/berkas**. |
| Realtime | **Supabase Realtime** (status booking live). |
| Serverless | **Supabase Edge Functions** (Deno): webhook pembayaran, cron pengingat oli, batch payout, signed URL dokumen (admin). |
| Keamanan | **Row Level Security** di semua tabel; validasi 2 MB di bucket + klien. |
| Peta | Google Maps SDK (gaya kustom). |
| Push | FCM + APNs. |
| Pembayaran | Midtrans/Xendit (QRIS, e-wallet, VA + disbursement). |
| Error | Sentry. |

Alur, kebijakan RLS, dan aturan 2 MB diuraikan di `docs/ARCHITECTURE.md` dan `docs/SUPABASE_BACKEND.md`.

---

## 14. Roadmap

| Fase | Isi |
|---|---|
| **MVP (P0)** | Auth, discovery+peta, detail, booking+bayar+escrow, payout H+1, Garasi+riwayat, pengingat oli, ulasan, favorit, notifikasi, onboarding bengkel + verifikasi (admin web), dompet owner, batas media 2 MB. |
| **P1** | Pekerjaan tambahan lengkap, OTP HP, kompresi gambar otomatis klien. |
| **P2** | Chat, langganan/paket servis, multi-cabang, spare-part, loyalitas. |

---

## 15. Pertanyaan Terbuka

1. Retensi dokumen KTP/selfie setelah verifikasi — menunggu masukan legal.
2. Ambang jarak foto GPS ke pin (`max_gps_distance_m`, default 300 m) — kalibrasi lapangan.
3. Pemilihan final gateway (Midtrans vs Xendit) & biaya disbursement.
4. Besaran tenggat pembayaran (default 60 menit) — uji konversi.



