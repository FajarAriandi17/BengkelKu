-- 0004_bookings_payments.sql — booking, item, pembayaran, refund, payout

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references public.users (id) on delete cascade,
  workshop_id uuid not null references public.workshops (id) on delete restrict,
  vehicle_id uuid references public.vehicles (id) on delete set null,
  status booking_status not null default 'MENUNGGU_PEMBAYARAN',
  scheduled_at timestamptz not null,            -- slot (UTC)
  subtotal_idr int not null default 0,
  total_idr int not null default 0,             -- yang dibayar rider
  commission_rate numeric(4,3) not null default 0.080, -- 8%
  cancel_reason text,
  payment_deadline timestamptz,                 -- kedaluwarsa pembayaran
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_bookings_rider on public.bookings (rider_id);
create index if not exists idx_bookings_workshop on public.bookings (workshop_id);
create index if not exists idx_bookings_status on public.bookings (status);

-- Item layanan + pekerjaan tambahan.
create table if not exists public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  service_id uuid references public.services (id) on delete set null,
  name text not null,                           -- snapshot nama layanan
  price_idr int not null,
  is_addon boolean not null default false,      -- pekerjaan tambahan
  addon_approved boolean,                       -- persetujuan rider utk addon
  created_at timestamptz not null default now()
);
create index if not exists idx_items_booking on public.booking_items (booking_id);

-- Transaksi gateway.
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  provider text not null default 'midtrans',    -- midtrans | xendit
  provider_ref text unique,                     -- idempotency key webhook
  method text,                                  -- qris | ewallet | va
  amount_idr int not null,
  status payment_status not null default 'pending',
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_payments_booking on public.payments (booking_id);

-- Pengembalian dana (penuh/50%/0%).
create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  amount_idr int not null,
  reason text,
  status text not null default 'processing',    -- processing | done | failed
  created_at timestamptz not null default now()
);

-- Pencairan ke bengkel (batch H+1).
create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  booking_id uuid references public.bookings (id) on delete set null,
  gross_idr int not null,
  commission_idr int not null,                  -- 8%
  net_idr int not null,
  status payout_status not null default 'scheduled',
  bank_account text,
  scheduled_for date not null,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_payouts_workshop on public.payouts (workshop_id);
