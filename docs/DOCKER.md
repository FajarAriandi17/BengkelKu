# Docker — BengkelKu

Menjalankan stack BengkelKu di Docker secara lokal.

## Prasyarat

- Docker Desktop 4.94+ dengan **backend WSL2** (sudah default di Windows).
- Docker daemon hidup: `docker info` harus menampilkan Server version tanpa error.

## Konfigurasi env

Salin template env dan isi nilai Supabase Anda:

```bash
cp .env.example .env
```

Isi tiga variabel wajib (dari dashboard Supabase → Settings → API):

| Variabel | Kapan dibaca | Wajib? |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | saat **build** (disisipkan ke client bundle) | wajib |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | saat **build** | wajib |
| `SUPABASE_SERVICE_ROLE_KEY` | saat **runtime** (server-only, rahasia) | wajib |

> **Penting**: `NEXT_PUBLIC_*` harus ada **sebelum** `docker compose build` karena
> Next.js menyisipkannya ke client bundle saat build. Mengubahnya lalu restart saja
> **tidak** akan mengubahnya — Anda harus `--build` lagi.

## Menjalankan

```bash
# Panel admin saja (default)
docker compose up -d --build

# Panel admin + landing page
docker compose --profile full up -d --build
```

Hasilnya:

| Layanan | URL |
|---|---|
| Admin Web | http://localhost:3000 |
| Landing Page | http://localhost:8080 (hanya dengan `--profile full`) |

## Operasi umum

```bash
docker compose logs -f          # lihat log
docker compose ps               # status kontainer
docker compose down             # hentikan
docker compose build            # rebuild setelah ganti NEXT_PUBLIC_* atau kode
```

## Catatan

- **Database**: BengkelKu memakai Supabase cloud (PostgreSQL terkelola), jadi tidak
  ada service database lokal di compose. Semua koneksi langsung ke
  `NEXT_PUBLIC_SUPABASE_URL`.
- **Mobile (Flutter)** tidak di-container-kan — build APK/AAB/IPA ditangani
  GitHub Actions (lihat `.github/workflows/`).
- **Landing page** dilayankan nginx:alpine langsung dari folder statis.
