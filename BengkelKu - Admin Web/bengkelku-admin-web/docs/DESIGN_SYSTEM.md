# DESIGN SYSTEM — BengkelKu Admin Web

Token selaras dengan mobile (lihat `../bengkelku-mobile/docs/DESIGN_SYSTEM.md`). Nilai Tailwind di `tailwind.config.ts`, nilai JS di `src/lib/theme/tokens.ts`.

## 1. Warna

Sama dengan mobile: `panel`, `panel2`, `ink`, `blue`, `blueSoft`, status `ok/warn/bad` (+ soft), `star`, `heart`. Mode gelap via `class` (`darkMode: "class"`).

Pemetaan status umum admin:
- bengkel: pending → warn, verified → ok, rejected/suspended → bad, draft → blueSoft.
- payout: scheduled → blueSoft, processing → warn, paid → ok, failed → bad.

## 2. Tipografi

Plus Jakarta Sans. Skala mirip mobile: judul halaman 22–24/bold, section 18/semibold, body 14–15, caption 12. Antarmuka admin boleh sedikit lebih padat (data table).

## 3. Layout

- **AdminShell**: sidebar kiri (navigasi) + topbar (konteks + logout) + area konten. Desktop-first, lebar sidebar 256px.
- Konten memakai kartu `rounded-lg bg-panel shadow-sm`.
- Tabel: header `bg-panel2`, baris dengan garis `blueSoft/50`.

## 4. Komponen

- `AdminShell` — kerangka halaman.
- `DocViewer` — penampil dokumen aman (blur, watermark, tanpa unduh, jendela lihat).
- `VerificationDecision` — checklist 4 item + setujui/tolak + form alasan.
- `StatusBadge` — badge status berwarna token.
- `DataTable` (pola) — tabel data dengan state loading/empty/error.
- `ConfirmModal`, `ReasonForm`, `ConfigRow`, `PayoutStatusBadge` — menyusul sesuai `docs/PAGES.md`.

Setiap komponen: state default, loading, empty, error; mode terang/gelap; label a11y; target sentuh/area klik memadai.

## 5. Prinsip

Jelas, padat, dan aman. Tidak ada aksi destruktif tanpa konfirmasi. Dokumen sensitif tidak pernah tampil tanpa aksi sadar dari admin.
