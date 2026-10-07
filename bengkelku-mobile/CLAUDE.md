# CLAUDE.md — Panduan untuk Claude Code (BengkelKu Mobile)

Repo ini adalah aplikasi **Flutter** (Android & iOS) untuk BengkelKu. Backend & database = **Supabase**. Baca file ini sebelum mengerjakan tugas apa pun.

## Sumber kebenaran
1. `docs/PRD.md` — apa yang dibangun & kenapa.
2. `docs/ARCHITECTURE.md` — bagaimana (Supabase, keamanan, aturan 2 MB).
3. `docs/PAYMENTS_MAYAR.md` — alur & setup gateway pembayaran Mayar.
4. `docs/DESIGN_SYSTEM.md` + `docs/ANIMATIONS.md` + `docs/SCREENS.md` — UI/UX.
5. `supabase/migrations/*` — skema database nyata. Jangan menebak kolom; baca migrasi.

Jika dokumen & kode berbeda, **dokumen menang** kecuali migrasi SQL (SQL = kebenaran struktur DB).

## Aturan kerja
- **Bahasa UI & microcopy: Bahasa Indonesia**, sapaan "kamu", huruf kecil biasa. Istilah baku: bengkel, servis, booking, tiket, Garasi, odometer, pengingat oli.
- **Token desain**: jangan hardcode warna/ukuran. Pakai `AppColors` ThemeExtension & konstanta di `lib/core/theme`. Konstanta gerak di `lib/core/motion/motion.dart`.
- **Animasi**: hormati *Reduce Motion* OS (ganti dengan fade 100 ms / instan).
- **Supabase**: akses lewat `lib/core/network/supabase_client.dart`. Terapkan Row Level Security di sisi DB, jangan andalkan filter klien untuk keamanan.
- **PostGIS harus schema-qualified**: `db push` menjalankan migrasi dengan `search_path` yang hanya memuat `public`, jadi tipe/fungsi PostGIS (postgis ter-install di schema `extensions`) harus ditulis `extensions.geography`, `extensions.st_distance`, `extensions.st_setsrid`, `extensions.st_makepoint`, `extensions.st_x/st_y`, dst. Tanpa prefix, migrasi gagal dengan `type "geography" does not exist (SQLSTATE 42704)`.
- **Upload media ≤ 2 MB**: selalu lewati `MediaGuard.ensureUnderLimit()` sebelum upload. Pesan baku bila gagal (persis): *"ukuran media anda terlalu besar segera kompres file media untuk melanjutkan"*.
- **Logika oli**: `lib/features/oil/domain/oil_calculator.dart` adalah fungsi murni; selalu update unit test di `test/oil_calculator_test.dart`.
- **Jangan** menambahkan kode, route, string, atau endpoint admin ke aplikasi ini.
- **Waktu**: simpan UTC; tampilkan zona waktu bengkel.

## Perintah
```bash
flutter pub get
flutter analyze
flutter test
dart format .
flutter run --dart-define-from-file=.env
supabase db reset            # terapkan ulang migrasi + seed (butuh Supabase CLI)
```

## Definition of Done per task
1. `flutter analyze` bersih (0 error, 0 warning baru).
2. `flutter test` lulus (tambah test untuk logika baru).
3. Komponen baru punya state: default, pressed, disabled, loading, error (bila relevan), + mode terang/gelap + label aksesibilitas.
4. Daftar punya state loading (skeleton), empty, error.
5. Tidak ada string/route admin yang bocor ke build.
