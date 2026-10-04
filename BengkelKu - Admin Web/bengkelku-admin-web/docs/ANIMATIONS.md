# ANIMATIONS — BengkelKu Admin Web

Prinsip: gerak halus & fungsional. Panel admin memprioritaskan kecepatan dan kejelasan di atas spektakel. Semua animasi menghormati `prefers-reduced-motion`.

## 1. Token gerak

Selaras dengan mobile tetapi lebih tenang:
- Durasi mikro: 120–180ms (hover, fokus, badge).
- Durasi transisi konten: 200–260ms (buka panel, ganti tab).
- Easing standar: `cubic-bezier(0.22, 1, 0.36, 1)` (easeOut).
- Easing masuk-keluar lembut: `cubic-bezier(0.4, 0, 0.2, 1)`.
- Tidak ada efek "spring" berlebihan di admin.

Didefinisikan sebagai utilitas/kelas di `src/app/globals.css`.

## 2. Prefers-reduced-motion

`globals.css` memuat blok:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.001ms !important;
    scroll-behavior: auto !important;
  }
}
```

Dengan ini seluruh transisi menjadi instan bagi pengguna yang meminta pengurangan gerak.

## 3. Pola animasi per interaksi

- **Hover tombol/baris tabel**: perubahan warna latar 120ms, tanpa pergeseran layout.
- **Fokus keyboard**: ring fokus muncul instan (aksesibilitas), tidak dianimasikan menghilang.
- **Modal/konfirmasi**: fade + translateY 8px→0 selama 200ms; overlay fade 160ms. Keluar lebih cepat (140ms).
- **Toast/notifikasi**: slide-in dari kanan-atas 220ms easeOut, auto-dismiss, slide-out 160ms.
- **Badge status**: transisi warna 150ms saat status berubah (mis. setelah keputusan verifikasi).
- **DocViewer**: blur→jelas memakai transisi `filter` 180ms saat admin menekan "Lihat"; menutup kembali ke blur instan ketika jendela 2 menit habis (keamanan di atas estetika).
- **Skeleton loading**: pulse lembut 1.2s pada placeholder tabel/kartu saat memuat.

## 4. Yang dihindari

- Animasi masuk halaman penuh yang memperlambat kerja berulang verifikator.
- Parallax, bounce besar, atau gerak yang menarik perhatian dari data.
- Animasi pada aksi destruktif — konfirmasi harus terasa stabil dan serius.

## 5. Implementasi

Admin memakai CSS transitions/`@keyframes` sederhana via Tailwind + `globals.css`. Tidak diperlukan pustaka animasi berat. Komponen klien (`"use client"`) seperti `DocViewer` dan modal mengatur state untuk memicu kelas transisi.
