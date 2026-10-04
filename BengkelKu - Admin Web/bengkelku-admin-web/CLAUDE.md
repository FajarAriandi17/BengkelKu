# CLAUDE.md — Panduan untuk Claude Code (BengkelKu Admin Web)

Repo ini adalah **panel admin web Next.js (App Router) + TypeScript** untuk memverifikasi bengkel BengkelKu. Backend & database = **Supabase** (project sama dengan mobile). Baca file ini sebelum mengerjakan tugas apa pun.

## Sumber kebenaran
1. `docs/PRD.md` — apa yang dibangun & kenapa.
2. `docs/ARCHITECTURE.md` — keamanan, sesi, akses dokumen.
3. `docs/DESIGN_SYSTEM.md` + `docs/ANIMATIONS.md` + `docs/PAGES.md` — UI/UX.
4. Skema DB kanonik ada di `../bengkelku-mobile/supabase/migrations/*`. Repo ini hanya menambah `supabase/migrations/0100_*`+.

Jika dokumen & kode berbeda, **dokumen menang** kecuali migrasi SQL (SQL = kebenaran struktur DB).

## Aturan kerja
- **Keamanan dulu**: tanpa signup publik; semua rute (kecuali `/login`) dijaga `middleware.ts` (sesi valid + `aud=admin`). Jangan membuat endpoint tanpa auth.
- **Service role key hanya di server** (`src/lib/supabase/server.ts`, Edge Functions). JANGAN pernah mengeksposnya ke klien.
- **Dokumen sensitif**: tampilkan via signed URL ≤ 60 dtk, blur default, watermark, tanpa unduh. Jangan membuat bucket publik untuk KTP/selfie.
- **Audit**: setiap keputusan verifikasi & akses dokumen menulis ke `audit_logs`.
- **Token desain**: pakai `src/lib/theme/tokens.ts`, jangan hardcode warna. Selaras dengan tokens mobile.
- **Bahasa UI: Bahasa Indonesia** (profesional, untuk admin internal — boleh lebih formal dari app).
- **Animasi**: halus & cepat; hormati `prefers-reduced-motion`.
- Desktop-first (min 1024px).

## Perintah
```bash
npm install
npm run dev            # dev server
npm run build          # build produksi
npm run lint           # eslint
npm run typecheck      # tsc --noEmit
```

## Definition of Done per task
1. `npm run typecheck` & `npm run lint` bersih.
2. Rute baru dijaga auth (kecuali publik yang disengaja) & peran sesuai matriks (`docs/PRD.md`).
3. Komponen baru punya state: default, loading, empty, error + mode terang/gelap + label a11y.
4. Aksi sensitif menulis `audit_logs`.
5. Tidak ada service role key / rahasia yang bocor ke bundel klien.
