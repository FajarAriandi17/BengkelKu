-- 0002_core_tables.sql — pengguna, kendaraan, odometer

-- Profil pengguna (tertaut auth.users). Dibuat otomatis via trigger di bawah.
create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  timezone text not null default 'Asia/Jakarta',
  roles user_role[] not null default array['rider']::user_role[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Kendaraan milik pengguna.
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  brand text not null,
  model text not null,
  year int,
  plate text,
  odometer int not null default 0,            -- km terkini
  oil_interval_km int not null default 4000,  -- interval ganti oli (km)
  oil_interval_days int not null default 90,  -- interval ganti oli (hari)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_vehicles_user on public.vehicles (user_id);

-- Histori pembacaan odometer (sumber: service/manual).
create table if not exists public.odometer_logs (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  reading_km int not null,
  source text not null default 'manual',       -- 'service' | 'manual'
  recorded_at timestamptz not null default now()
);
create index if not exists idx_odo_vehicle on public.odometer_logs (vehicle_id);

-- Buat baris public.users otomatis saat sign up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  insert into public.users (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  return new;
end$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
