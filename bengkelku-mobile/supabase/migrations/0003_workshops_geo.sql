-- 0003_workshops_geo.sql — bengkel (geospasial), jam, slot, layanan, dokumen

create table if not exists public.workshops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  description text,
  phone text,
  address text,
  location geography(Point, 4326),            -- lng/lat untuk ST_DWithin
  timezone text not null default 'Asia/Jakarta',
  status workshop_status not null default 'draft',
  rejected_reason text,
  rating_avg numeric(2,1) not null default 0,
  rating_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Index geospasial untuk query terdekat.
create index if not exists idx_workshops_location on public.workshops using gist (location);
create index if not exists idx_workshops_status on public.workshops (status);

-- Dokumen verifikasi (bucket privat verification-docs).
create table if not exists public.workshop_documents (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  type doc_type not null,
  storage_path text not null,                 -- path di bucket privat
  gps_lat double precision,                   -- koordinat EXIF/kamera (untuk foto lokasi)
  gps_lng double precision,
  status doc_status not null default 'pending',
  created_at timestamptz not null default now()
);
create index if not exists idx_docs_workshop on public.workshop_documents (workshop_id);

-- Jam buka per hari (0=Minggu .. 6=Sabtu).
create table if not exists public.workshop_hours (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  open_time time,
  close_time time,
  is_closed boolean not null default false
);
create index if not exists idx_hours_workshop on public.workshop_hours (workshop_id);

-- Konfigurasi slot/kapasitas.
create table if not exists public.workshop_slots_config (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  slot_minutes int not null default 60,
  capacity_per_slot int not null default 1
);

-- Layanan + harga.
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  name text not null,
  price_idr int not null,
  duration_minutes int not null default 60,
  is_active boolean not null default true
);
create index if not exists idx_services_workshop on public.services (workshop_id);
