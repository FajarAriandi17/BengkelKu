-- 0001_extensions.sql — ekstensi dasar
-- PostGIS untuk query geospasial "bengkel terdekat"; pgcrypto untuk UUID.

create extension if not exists postgis with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- Enum global dipakai lintas tabel.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type user_role as enum ('rider', 'owner');
  end if;

  if not exists (select 1 from pg_type where typname = 'workshop_status') then
    create type workshop_status as enum ('draft', 'pending', 'verified', 'rejected', 'suspended');
  end if;

  if not exists (select 1 from pg_type where typname = 'booking_status') then
    create type booking_status as enum (
      'MENUNGGU_PEMBAYARAN',
      'DIBAYAR_MENUNGGU_KONFIRMASI',
      'DIKONFIRMASI',
      'CHECK_IN',
      'DIKERJAKAN',
      'SELESAI',
      'PAYOUT',
      'KEDALUWARSA',
      'DITOLAK',
      'DIBATALKAN',
      'TIDAK_HADIR'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'payment_status') then
    create type payment_status as enum ('pending', 'paid', 'failed', 'expired', 'refunded');
  end if;

  if not exists (select 1 from pg_type where typname = 'payout_status') then
    create type payout_status as enum ('scheduled', 'processing', 'paid', 'failed');
  end if;

  if not exists (select 1 from pg_type where typname = 'oil_stage') then
    create type oil_stage as enum ('ok', 'soon', 'late');
  end if;

  if not exists (select 1 from pg_type where typname = 'doc_type') then
    create type doc_type as enum ('ktp', 'selfie', 'location');
  end if;

  if not exists (select 1 from pg_type where typname = 'doc_status') then
    create type doc_status as enum ('pending', 'approved', 'rejected');
  end if;
end$$;
