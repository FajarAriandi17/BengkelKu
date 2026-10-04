-- 0009_functions_rpc.sql — RPC bengkel terdekat + trigger odometer→oli

-- Bengkel terdekat (PostGIS). Hanya status 'verified'. Diurut jarak.
-- Dipanggil klien: supabase.rpc('nearby_workshops', {lat, lng, radius_m, limit_n})
create or replace function public.nearby_workshops(
  lat double precision,
  lng double precision,
  radius_m double precision default 10000,
  limit_n int default 50
)
returns table (
  id uuid,
  name text,
  address text,
  rating_avg numeric,
  rating_count int,
  distance_m double precision
)
language sql
stable
as $$
  select
    w.id,
    w.name,
    w.address,
    w.rating_avg,
    w.rating_count,
    st_distance(w.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography) as distance_m
  from public.workshops w
  where w.status = 'verified'
    and w.location is not null
    and st_dwithin(
      w.location,
      st_setsrid(st_makepoint(lng, lat), 4326)::geography,
      radius_m
    )
  order by distance_m asc
  limit limit_n;
$$;

-- Saat service_record masuk: update odometer kendaraan, catat log,
-- dan (bila ganti oli) hitung ulang pengingat oli.
create or replace function public.on_service_record()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v record;
  new_target_km int;
  new_target_date date;
begin
  select * into v from public.vehicles where id = new.vehicle_id;

  -- Update odometer bila lebih tinggi.
  if new.odometer_km > v.odometer then
    update public.vehicles set odometer = new.odometer_km, updated_at = now()
    where id = new.vehicle_id;
  end if;

  insert into public.odometer_logs (vehicle_id, reading_km, source, recorded_at)
  values (new.vehicle_id, new.odometer_km, 'service', new.serviced_at);

  -- Hitung target oli bila oli diganti.
  if new.oil_changed then
    new_target_km := new.odometer_km + v.oil_interval_km;
    new_target_date := (new.serviced_at::date) + (v.oil_interval_days || ' days')::interval;

    insert into public.oil_reminders (vehicle_id, target_km, target_date, stage, updated_at)
    values (new.vehicle_id, new_target_km, new_target_date, 'ok', now())
    on conflict (vehicle_id) do update
      set target_km = excluded.target_km,
          target_date = excluded.target_date,
          stage = 'ok',
          snoozed_until = null,
          updated_at = now();
  end if;

  return new;
end$$;

drop trigger if exists trg_service_record on public.service_records;
create trigger trg_service_record
  after insert on public.service_records
  for each row execute function public.on_service_record();
