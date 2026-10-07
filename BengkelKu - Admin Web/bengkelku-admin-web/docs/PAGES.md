# PAGES — BengkelKu Admin Web

Inventaris halaman, peran yang berhak, data sumber, dan perilaku. Rute memakai App Router. Semua rute (kecuali `/login`) dijaga `middleware.ts` + cek `admin_users.is_active`.

## Peta rute

| Rute | Halaman | Peran | Status |
|---|---|---|---|
| `/login` | Login + 2FA | semua | inti |
| `/dashboard` | Ringkasan | semua | inti |
| `/verifikasi` | Antrean verifikasi | super_admin, verifikator | inti |
| `/verifikasi/[id]` | Detail & keputusan | super_admin, verifikator | inti |
| `/bengkel` | Daftar bengkel | semua (lihat) | placeholder |
| `/pengguna` | Pengguna | super_admin, cs (+lihat) | placeholder |
| `/transaksi` | Transaksi | super_admin, finance | placeholder |
| `/payout` | Payout | super_admin, finance | inti |
| `/moderasi` | Moderasi ulasan/konten | super_admin, cs | placeholder |
| `/konfigurasi` | Konfigurasi platform | super_admin, finance (sebagian) | placeholder |
| `/laporan` | Laporan | super_admin, finance | placeholder |
| `/audit` | Audit log | super_admin | inti |
| `/tim` | Tim admin & undangan | super_admin | placeholder |

"Inti" = sudah diimplementasikan untuk alur verifikasi end-to-end. "Placeholder" = kerangka halaman siap diisi (tidak 404), struktur & hak akses sudah ditentukan.

## Detail halaman

### Login (`/login`)
Email + kata sandi (Supabase Auth), lalu langkah **2FA TOTP**. Gagal → pesan netral tanpa membocorkan apakah email terdaftar. Sukses → cek `admin_users.is_active`; non-admin/ nonaktif langsung sign-out + pesan "akun tidak memiliki akses admin". Redirect ke `/dashboard`.

### Dashboard (`/dashboard`)
Kartu metrik: jumlah `pending`, `verified` hari ini, backlog tertua (umur antrean), payout menunggu. Tautan cepat ke antrean. Hanya baca.

### Verifikasi — antrean (`/verifikasi`)
Tabel bengkel berstatus `pending` diurutkan terlama dulu (SLA). Kolom: nama bengkel, kota, tanggal daftar, umur antrean, pemilik. Klik baris → detail. State loading/empty ("tidak ada antrean 🎉")/error.

### Verifikasi — detail (`/verifikasi/[id]`)
Server Component. Memuat profil bengkel + daftar `workshop_documents`, membuat **signed URL ≤ 60 dtk** via service role, menulis audit `VIEW_DOCUMENTS`. Render:
- Profil: nama, pemilik, alamat, pin peta, jam, layanan.
- `DocViewer`: KTP, selfie memegang KTP, foto lokasi — blur default, watermark email admin, tanpa unduh/menu konteks, jendela lihat 2 menit.
- Perbandingan koordinat foto lokasi vs pin (jarak meter vs `max_gps_distance_m`).
- `VerificationDecision`: checklist 4 item (KTP terbaca, selfie cocok, nama cocok, lokasi sesuai) + tombol Setujui (aktif saat semua tercentang) / Tolak (pilih kode alasan + catatan). POST `/api/verify`.

### Payout (`/payout`)
Tabel payout: periode, bengkel, bruto, komisi (8%), neto, status (`scheduled/processing/paid/failed`), tanggal. Finance dapat menandai batch. Integrasi disbursement final (Mayar) = pertanyaan terbuka PRD §7.

### Audit (`/audit`)
Tabel `audit_logs` hanya-baca untuk super_admin: waktu, aktor, aksi (`VIEW_DOCUMENTS/APPROVE_WORKSHOP/REJECT_WORKSHOP/...`), target, meta. Filter tanggal & aksi. Tidak dapat diubah/dihapus dari UI.

### Placeholder (bengkel, pengguna, transaksi, moderasi, konfigurasi, laporan, tim)
Kerangka dengan judul, deskripsi lingkup, dan hak akses peran. Siap diisi tanpa mengubah navigasi. Konfigurasi akan memuat: komisi (8%), tenggat bayar (60 mnt), `max_gps_distance_m` (300 m), preset interval oli, retensi dokumen. Tim memuat undangan invite-only + penetapan peran.

## State wajib tiap halaman data

Loading (skeleton), empty (pesan ramah), error (pesan + aksi coba lagi), sukses. Semua teks Bahasa Indonesia profesional. Aksi destruktif/keputusan selalu lewat konfirmasi.
