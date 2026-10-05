# PRD — Landing Page BengkelKu

| | |
|---|---|
| **Versi** | 1.1 (lihat Riwayat Perubahan di akhir dokumen) |
| **Tanggal** | 5 Oktober 2026 |
| **Pratinjau** | https://claude.ai/artifact/EcpMKan3J74iD73bT4zFT7 |
| **Desain acuan** | `index.html` (satu berkas, tanpa dependensi selain Google Fonts). Gaya mengacu pada referensi landing page aplikasi: hero dengan mockup ponsel dan kartu melayang, pita gradien bersudut membulat, statistik, kumpulan fitur, banner ajakan unduh, testimoni, footer dengan newsletter |
| **Produk** | BengkelKu (aplikasi Android dan iOS) — lihat `01-bengkelku-mobile/PRD.md` dan `docs/PRD_UPDATE_v1.3.md` |

## 1. Tujuan dan metrik

| Tujuan | Metrik (usulan, 3 bulan) |
|---|---|
| Mendorong unduhan aplikasi | Klik tombol toko ≥ 8% dari pengunjung |
| Merekrut bengkel | ≥ 2% pengunjung membuka bagian "Untuk bengkel" lalu mengeklik daftar |
| Mengumpulkan email prarilis | Konversi newsletter ≥ 1,5% |
| Performa | LCP ≤ 2,5 dtk di 4G; CLS ≤ 0,1; Lighthouse Performance ≥ 90 di mobile |

## 2. Audiens

1. **Pengendara motor** (utama): 18–45 tahun, membuka dari ponsel (perkiraan > 85% lewat seluler).
2. **Pemilik bengkel** (kedua): mencari kanal pelanggan baru dan pembayaran rapi.

## 3. Struktur halaman

| # | Bagian | Isi | CTA |
|---|---|---|---|
| 1 | Navigasi lengket | Logo, Fitur, Cara kerja, Untuk bengkel, FAQ, tombol Unduh | Unduh |
| 2 | Hero | Judul "Servis motor tanpa ribet, oli tak pernah telat", subteks, mockup ponsel (gauge oli, bengkel terdekat), 3 kartu melayang (booking, pengingat, mekanik tiba) | Unduh gratis, Lihat cara kerja |
| 3 | Pita 3 keunggulan | Pengingat pintar, bengkel terverifikasi, bantuan motor mogok. Berada **di bawah** hero dengan jarak 34 px; tidak boleh menimpa mockup ponsel atau kartu melayang | — |
| 4 | Fitur (6 kartu) | Cari bengkel, booking dan bayar, bantuan mogok (Baru), chat (Baru), penawaran transparan, buku servis | — |
| 5 | Cara kerja + statistik | 4 langkah; 2 angka (hitung naik) | — |
| 6 | Untuk bengkel | Syarat daftar (KTP, selfie, foto lokasi), tinjauan, pencairan H+1 | Daftarkan bengkel |
| 7 | Testimoni | 2 kutipan | — |
| 8 | FAQ | 4 pertanyaan (akordeon `<details>`) | — |
| 9 | Banner unduh | Tombol Google Play, App Store, kode QR | Unduh |
| 10 | Footer | Tautan, kebijakan privasi, S&K, newsletter | Kirim email |

## 4. Konten

- Bahasa: Indonesia, nada ramah dan lugas; hindari janji yang tidak bisa dipenuhi (mis. "bengkel pasti datang").
- **Placeholder yang wajib diganti sebelum rilis:** angka statistik (12K+ bengkel, 100K+ servis), testimoni, tautan Google Play dan App Store, kode QR, tautan Kebijakan Privasi dan Syarat & Ketentuan, nama dan logo final. Jangan menayangkan angka atau testimoni yang tidak nyata.
- Klaim fitur "Bantuan motor mogok" dan "Chat" mengikuti status rilis aplikasi; sembunyikan kartu bertanda **Baru** bila belum dirilis.
- Teks biaya darurat hanya menyebut "tetap dan jelas sebelum bayar"; jangan menampilkan tarif sebelum disetujui bisnis.

## 5. Desain

| Aspek | Ketentuan |
|---|---|
| Warna | Biru merek `#1F4FD8` (sama dengan aplikasi), gradien pita `#2B5BF0 → #6F8CFF`, aksen amber untuk darurat, hijau untuk status baik. Referensi gambar berwarna ungu; seluruh warna ada di variabel CSS `:root` sehingga bisa diganti satu tempat |
| Tipografi | Plus Jakarta Sans 400–800; judul `clamp(34px, 5.4vw, 56px)` |
| Bentuk | Kartu radius 22–36 px, bayangan lembut, mockup ponsel berbingkai tebal |
| Mode | Terang dan gelap otomatis (`prefers-color-scheme`), bisa dipaksa lewat `data-theme` |
| Responsif | 3 titik henti: > 900 px (desktop), ≤ 900 px (tablet, grid 2 kolom), ≤ 560 px (1 kolom). Tidak ada gulir horizontal |
| Tata letak antarbagian | Tidak ada margin negatif antar bagian besar. Hero memberi ruang bawah 24 px (latar miring di belakang ponsel tidak boleh keluar dari hero). Satu-satunya tumpang tindih yang disengaja: kartu melayang di atas mockup ponsel |
| Area aman | `viewport-fit=cover` + `env(safe-area-inset-*)` pada navigasi dan badan halaman |

## 6. Animasi

| Elemen | Gerak |
|---|---|
| Kartu melayang di hero | Naik-turun 10 px, 5 dtk, loop, fase berbeda per kartu |
| Bilah gauge di mockup | Terisi 1,6 dtk saat halaman dimuat |
| Bagian saat digulir | Muncul naik 24 px + fade 700 ms, jeda bertingkat 90 ms (IntersectionObserver, sekali saja) |
| Kartu fitur | Hover naik 6 px dengan bayangan membesar |
| Tombol | Hover naik 2 px; tekan scale 0,97 |
| Angka statistik | Hitung naik 1,2 dtk, easeOut, saat terlihat |
| Reduce motion | Semua animasi dan transisi dimatikan, konten langsung tampil |

## 7. Kebutuhan teknis

| Hal | Keputusan |
|---|---|
| Bentuk | Situs statis. Awal: `index.html` apa adanya. Bila situs bertambah (blog, halaman hukum), pindahkan ke **Astro** (statis, cepat, mudah SEO) tanpa mengubah desain |
| Hosting | Cloudflare Pages atau Vercel (paket gratis cukup). Domain dan HTTPS wajib |
| Newsletter | Form kirim ke Edge Function Supabase `landing-subscribe` yang menulis ke tabel `landing_leads(email, source, created_at)`. RLS: tolak semua baca/tulis dari klien; hanya fungsi (service role) yang menulis. Validasi email, batas 5 permintaan per IP per jam, honeypot. Konfirmasi lewat email (double opt-in) |
| Tautan unduh | Satu tautan pintar `/unduh` yang mengarahkan berdasarkan perangkat (Android → Play Store, iOS → App Store, desktop → halaman dengan QR). Sertakan parameter UTM |
| Deep link | Android App Links dan iOS Universal Links untuk `/b/{kode}` (undangan bengkel) dan `/r/{kode}` (referral), sesuai PRD v1.3 Fitur E |
| Analitik | Plausible atau GA4 dengan persetujuan; event: `cta_download_click{store,section}`, `cta_register_workshop`, `newsletter_submit`, `faq_open{q}`, `scroll_75` |
| SEO | Judul dan deskripsi (sudah ada), Open Graph + Twitter Card (gambar 1200×630), `sitemap.xml`, `robots.txt`, data terstruktur `MobileApplication` dan `FAQPage`, `lang="id"` |
| Aksesibilitas | Kontras WCAG AA, fokus terlihat, urutan tab logis, `aria-label` pada mockup, FAQ memakai elemen native |
| Privasi | Banner persetujuan cookie hanya bila analitik memakai cookie; halaman Kebijakan Privasi sesuai UU PDP (draf hukum dibuat bersama penasihat hukum) |

## 8. Kriteria selesai

- [ ] Semua placeholder di Bagian 4 diganti atau disembunyikan
- [ ] Tombol Play Store dan App Store mengarah ke URL asli; QR memuat tautan `/unduh`
- [ ] Form newsletter berfungsi end-to-end dan tidak bisa dipakai membaca daftar email
- [ ] Lighthouse mobile: Performance ≥ 90, Accessibility ≥ 95, SEO ≥ 95
- [ ] Diuji di Chrome Android, Safari iOS, dan satu browser desktop; tidak ada gulir horizontal pada lebar 360 px
- [ ] Mode gelap dan Reduce motion berfungsi
- [ ] Tidak ada bagian yang saling menimpa pada lebar 360, 768, 1024, dan 1440 px (kecuali kartu melayang di atas mockup ponsel)
- [ ] Halaman Kebijakan Privasi dan Syarat & Ketentuan tersedia sebelum iklan atau peluncuran

## 9. Keputusan terbuka

| # | Pertanyaan | Nilai bawaan |
|---|---|---|
| 1 | Warna merek: tetap biru aplikasi atau ungu seperti referensi | Biru (konsisten dengan aplikasi) |
| 2 | Nama final dan domain | "BengkelKu" (working title); domain belum ditentukan |
| 3 | Menampilkan harga bantuan darurat di halaman | Tidak sampai tarif disetujui |
| 4 | Bagian blog/tips perawatan (ada di referensi) | Ditunda; tambahkan setelah ada konten nyata |
| 5 | Logo dan ilustrasi final | Logo teks sementara; menunggu desain logo |

## 10. Riwayat Perubahan

| Versi | Tanggal | Perubahan |
|---|---|---|
| 1.0 | 5 Okt 2026 | Versi awal: tujuan, struktur 10 bagian, desain, animasi, kebutuhan teknis |
| 1.1 | 5 Okt 2026 | Perbaikan tata letak: pita 3 keunggulan tidak lagi menimpa mockup ponsel dan kartu melayang di hero (margin negatif dihapus, jarak 34 px); padding atas pita disamakan di semua lebar layar; hero diberi ruang bawah 24 px. Ditambahkan aturan "Tata letak antarbagian" (Bagian 5), kriteria uji tanpa tumpang tindih di 4 lebar layar (Bagian 8), dan tautan pratinjau. Salah ketik pada Bagian 2 diperbaiki |
