-- 0005_oil_reminders.sql — preset oli, riwayat servis, pengingat oli

-- Preset interval oli umum.
create table if not exists public.oil_interval_presets (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  interval_km int not null,
  interval_days int not null
);

-- Riwayat servis (input bengkel/manual). Memicu update odometer & pengingat oli.
create table if not exists public.service_records (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings (id) on delete set null,
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  workshop_id uuid references public.workshops (id) on delete set null,
  odometer_km int not null,
  oil_changed boolean not null default false,
  notes text,
  serviced_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists idx_records_vehicle on public.service_records (vehicle_id);

-- Pengingat oli per kendaraan (target km + tanggal + status).
create table if not exists public.oil_reminders (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  target_km int not null,
  target_date date not null,
  stage oil_stage not null default 'ok',
  snoozed_until timestamptz,
  updated_at timestamptz not null default now(),
  unique (vehicle_id)
);
