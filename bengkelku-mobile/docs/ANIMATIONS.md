# ANIMATIONS — BengkelKu Mobile

Spesifikasi gerak. Konstanta di `lib/core/motion/motion.dart`. **Selalu hormati Reduce Motion** OS (ganti transisi dengan fade 100 ms atau instan).

## 1. Token gerak

| Token | Nilai |
|---|---|
| `easeOut` | `Cubic(0.22, 1, 0.36, 1)` |
| `spring` | `Cubic(0.34, 1.56, 0.64, 1)` |
| durasi micro | 150–250 ms |
| durasi screen | 420 ms |
| stagger list | 60 ms per item |

Target 60 fps. Hindari animasi yang memblok input.

## 2. Transisi layar

- Navigasi utama: **shared-axis** horizontal (go_router) dengan `easeOut`, 420 ms.
- Modal/bottom sheet: slide-up + fade, `easeOut`, 250 ms; backdrop fade 150 ms.
- Reduce Motion aktif → semua di atas menjadi fade 100 ms.

## 3. Micro-interaction

| Elemen | Gerak |
|---|---|
| Tombol tekan | scale 0.97, 150 ms `easeOut`. |
| Favorit (heart) | pop `spring` + warna `heart`. |
| Kartu masuk daftar | fade+translateY 8px, stagger 60 ms. |
| OilGauge | busur animasi dari 0 → nilai, 600 ms `easeOut`; perubahan status cross-fade warna. |
| Status booking berubah | badge cross-fade + pulse halus sekali. |
| Skeleton | shimmer lembut 1200 ms loop. |

## 4. Umpan balik

- Sukses pembayaran: ceklis bersprings + confetti ringan (opsional, nonaktif saat Reduce Motion).
- Error unggah 2 MB: shake kecil pada tile media (120 ms) + tampilkan pesan baku.

## 5. Aturan implementasi

- Semua durasi/kurva diambil dari `Motion` — jangan tulis angka ajaib di widget.
- Bungkus animasi dengan pengecekan `MediaQuery.disableAnimations` (Reduce Motion).
