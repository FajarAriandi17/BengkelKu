# PRD — BengkelKu Admin Web

**Panel admin internal untuk verifikasi bengkel & operasi marketplace BengkelKu.**

| | |
|---|---|
| **Versi** | 1.0 |
| **Tanggal** | 2 Oktober 2026 |
| **Platform** | Web (Next.js), desktop-first (min 1024px) |
| **Backend & Database** | Supabase (project sama dengan mobile) |
| **Akses** | Internal, login username+kata sandi, invite-only, 2FA |

---

## 1. Tujuan

Memberi tim internal alat untuk **memverifikasi dan menyetujui/menolak** pendaftaran bengkel sebelum tayang di aplikasi, serta mengelola moderasi, keuangan (payout/komisi), pengguna, dan konfigurasi platform — dengan keamanan & audit yang kuat karena menangani dokumen identitas (KTP/selfie).

### Kenapa terpisah dari mobile
Keamanan & pemisahan hak: aplikasi mobile tidak boleh memuat kode/akses admin. Admin memakai domain, login, dan JWT (`aud=admin`) sendiri. Dokumen sensitif hanya diakses di lingkungan admin yang terkontrol.

---

## 2. Peran & Hak Akses

| Peran | Verifikasi | Keuangan | Moderasi | Pengguna | Konfigurasi | Tim/undang |
|---|---|---|---|---|---|---|
| **Super Admin** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Verifikator** | ✓ | – | – | lihat | – | – |
| **Finance** | – | ✓ | – | lihat | sebagian | – |
| **CS** | – | – | ✓ | ✓ | – | – |

Diterapkan via tabel `admin_users.role` + helper `has_admin_role()` di RLS (lihat `docs/SUPABASE_ADMIN.md`).

---

## 3. Alur Verifikasi

1. Bengkel mendaftar di mobile → status `pending` + unggah KTP + selfie memegang KTP + foto lokasi (≤ 2 MB).
2. Verifikator membuka antrean `/verifikasi` → memilih bengkel.
3. Tinjau profil + dokumen (blur default; tampilkan via signed URL ≤ 60 dtk; watermark; tanpa unduh; jendela lihat 2 menit).
4. Isi **checklist 4 item**: KTP terbaca, selfie cocok, nama cocok, foto lokasi sesuai pin (bandingkan koordinat foto vs pin, ambang `max_gps_distance_m` default 300 m).
5. **Setujui** (semua tercentang) → status `verified`, bengkel tayang, owner dinotifikasi.
6. **Tolak** → pilih kode alasan baku (`DOC_BLUR`, `SELFIE_MISMATCH`, `NAME_MISMATCH`, `LOCATION_MISMATCH`, `DUPLICATE`, `INCOMPLETE`, `OTHER`) + catatan → owner dinotifikasi & bisa ajukan ulang.
7. Semua aksi + akses dokumen tercatat di `audit_logs`.

---

## 4. Fitur (halaman)

Login, Dashboard, Verifikasi (list + detail), Bengkel, Pengguna, Transaksi, Payout, Moderasi, Konfigurasi, Laporan, Audit Log, Tim Admin. Detail di `docs/PAGES.md`.

### Konfigurasi penting
Komisi platform (default 8%), tenggat pembayaran (default 60 menit), `max_gps_distance_m` (default 300 m), preset interval oli, retensi dokumen (menunggu kebijakan legal).

---

## 5. Kebutuhan Non-Fungsional

- **Keamanan**: invite-only, 2FA TOTP wajib, sesi idle 30 mnt / absolut 12 jam, cookie `HttpOnly; Secure; SameSite=Strict`, IP allowlist opsional, header keamanan (lihat `next.config.mjs`).
- **Privasi dokumen**: blur default, watermark email admin, tanpa unduh, signed URL ≤ 60 dtk, jendela lihat 2 menit, audit akses.
- **Audit**: setiap keputusan & akses dokumen tercatat.
- **Aksesibilitas**: kontras AA, label, navigasi keyboard; hormati reduce motion.
- **Lokalisasi**: Bahasa Indonesia (profesional).

---

## 6. Metrik

Waktu verifikasi median ≤ 48 jam; backlog antrean terkelola; 0 insiden kebocoran dokumen; akurasi keputusan (sedikit banding/komplain).

---

## 7. Pertanyaan Terbuka

1. Retensi dokumen KTP/selfie setelah verifikasi (legal).
2. Perlukah IP allowlist diwajibkan untuk produksi.
3. Integrasi disbursement final (Mayar) untuk halaman Payout.
