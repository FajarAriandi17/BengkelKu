# DESIGN SYSTEM — BengkelKu Mobile

Token & komponen untuk UI Flutter. **Jangan hardcode** warna/ukuran; pakai `AppColors` (ThemeExtension) & konstanta di `lib/core/theme`.

## 1. Warna (token)

Tiap token punya nilai terang & gelap. Diimplementasikan sebagai `ThemeExtension<AppColors>`.

| Token | Terang | Gelap | Pakai |
|---|---|---|---|
| `panel` | `#FFFFFF` | `#121A30` | permukaan utama/kartu |
| `panel2` | `#F3F5FB` | `#0D1427` | latar belakang halaman |
| `ink` | `#0F172A` | `#E8ECF8` | teks utama |
| `blue` | `#1F4FD8` | `#3A66F2` | aksi primer/brand |
| `blueSoft` | `#E4EBFF` | `#18265A` | latar aksen lembut |
| `ok` / `okSoft` | `#15803D` / `#DCFCE7` | — | status sukses |
| `warn` / `warnSoft` | `#B45309` / `#FEF3C7` | — | status peringatan |
| `bad` / `badSoft` | `#B91C1C` / `#FEE2E2` | — | status error/telat |
| `star` | `#F59E0B` | — | rating |
| `heart` | `#E11D48` | — | favorit |

Status oli: `ok` → hijau, `soon` → warn, `late` → bad.

## 2. Tipografi

Font **Plus Jakarta Sans** (weights 400–800).

| Gaya | Ukuran | Weight |
|---|---|---|
| display | 28 | 800 |
| h1 | 22 | 700 |
| h2 | 18 | 700 |
| body | 15 | 400/500 |
| label | 13 | 600 |
| caption | 12 | 500 |

## 3. Spasi & radius

- Skala spasi: 4, 8, 12, 16, 20, 24, 32.
- Radius: `pill` 99, `sm` 10–13, `md` 14–16, `lg` 18–20, `xl` 22–26.
- Target sentuh minimum 44 px.

## 4. Komponen inti (katalog `lib/design/components`)

Setiap komponen wajib punya state: default, pressed, disabled, loading, error (bila relevan), + mode terang/gelap + label aksesibilitas.

- `AppButton` (primer/sekunder/teks), `AppTextField`, `AppChip`/filter.
- `WorkshopCard` (foto, nama, jarak, rating, buka/tutup).
- `ServiceRow` (nama, durasi, harga).
- `OilGauge` (CustomPainter busur; warna sesuai status).
- `BookingStatusBadge` (sesuai state machine).
- `RatingStars`, `FavoriteButton`.
- `SlotPicker` (tanggal + slot).
- `PriceSummary`, `EmptyState`, `ErrorState`, `SkeletonList`.
- `MediaPickerTile` (memanggil `MediaGuard`; menampilkan pesan 2 MB bila gagal).

## 5. State daftar

Semua daftar wajib punya: loading (skeleton), empty, error (dengan retry).

## 6. Peta

Gaya Google Maps kustom (lembut, aksen `blue` untuk pin). Pin bengkel memakai marker brand; lokasi pengguna titik biru standar.

## 7. Logo & ikon

Logo: pin lokasi biru (`blue`) berpadu siluet motor (lihat `assets/logo/logo.svg`). Ikon memakai set garis konsisten (mis. `lucide`/`phosphor` style) berwarna `ink`.
