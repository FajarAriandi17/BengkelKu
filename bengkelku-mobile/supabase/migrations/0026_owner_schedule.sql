-- ===========================================================================
-- 0026_owner_schedule.sql — pemilik bengkel mengatur sendiri jadwal buka/tutup
--
-- 1. Jam mingguan (workshop_hours, satu baris per hari) + durasi slot & kapasitas.
-- 2. Libur khusus per tanggal (workshop_closures), mis. hari raya / cuti.
-- 3. Tutup sementara sekarang juga (workshops.temp_closed_until + alasan), mis. hujan
--    deras / mekanik sakit. Otomatis buka lagi saat waktunya lewat.
--
-- Semua tulis lewat RPC SECURITY DEFINER milik pemilik; klien hanya baca.
-- workshop_is_open, booking_available_slots, dan nearby_workshops ikut menghormati
-- libur khusus & tutup sementara, sehingga pengendara tidak bisa booking di jam tutup.
-- ===========================================================================

alter table public.workshops
  add column if not exists temp_closed_until timestamptz,
  add column if not exists temp_closed_reason text;

create table if not exists public.workshop_closures (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  closed_on date not null,
  reason text,
  created_at timestamptz not null default now(),
  unique (workshop_id, closed_on)
);
create index if not exists idx_closures_workshop_date on public.workshop_closures (workshop_id, closed_on);

alter table public.workshop_closures enable row level security;
drop policy if exists closures_read on public.workshop_closures;
create policy closures_read on public.workshop_closures for select using (true);

-- Satu baris jam per hari per bengkel (hapus duplikat lama sebelum unique index).
delete from public.workshop_hours a
using public.workshop_hours b
where a.workshop_id = b.workshop_id and a.weekday = b.weekday and a.ctid > b.ctid;
create unique index if not exists uq_hours_workshop_weekday on public.workshop_hours (workshop_id, weekday);

-- Satu konfigurasi slot per bengkel.
delete from public.workshop_slots_config a
using public.workshop_slots_config b
where a.workshop_id = b.workshop_id and a.ctid > b.ctid;
create unique index if not exists uq_slots_config_workshop on public.workshop_slots_config (workshop_id);

-- Tulis langsung dari klien ditutup; pakai RPC di bawah.
drop policy if exists hours_write on public.workshop_hours;
drop policy if exists slots_write on public.workshop_slots_config;

-- ---------------------------------------------------------------------------
-- Status buka
-- ---------------------------------------------------------------------------

create or replace function public.workshop_is_open(p_workshop_id uuid, at timestamptz)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select case
    when w.id is null then false
    when w.temp_closed_until is not null and w.temp_closed_until > at then false
    when exists (select 1 from public.workshop_closures c
                 where c.workshop_id = w.id and c.closed_on = (at at time zone w.timezone)::date) then false
    when not exists (select 1 from public.workshop_hours h where h.workshop_id = w.id) then true
    else exists (
      select 1 from public.workshop_hours h
      where h.workshop_id = w.id
        and h.weekday = extract(dow from at at time zone w.timezone)::int
        and not h.is_closed
        and h.open_time is not null and h.close_time is not null
        and (at at time zone w.timezone)::time >= h.open_time
        and (at at time zone w.timezone)::time < h.close_time)
  end
  from (select 1) one
  left join public.workshops w on w.id = p_workshop_id
$$;

-- Status publik untuk layar detail bengkel / kartu.
create or replace function public.workshop_open_status(p_workshop_id uuid)
returns jsonb language sql stable security definer set search_path = public, extensions as $$
  select jsonb_build_object(
    'is_open', public.workshop_is_open(w.id, now()),
    'temp_closed_until', case when w.temp_closed_until > now() then w.temp_closed_until end,
    'temp_closed_reason', case when w.temp_closed_until > now() then w.temp_closed_reason end,
    'closures', coalesce((
      select jsonb_agg(jsonb_build_object('date', c.closed_on, 'reason', c.reason) order by c.closed_on)
      from public.workshop_closures c
      where c.workshop_id = w.id
        and c.closed_on between (now() at time zone w.timezone)::date
                            and (now() at time zone w.timezone)::date + 30), '[]'::jsonb)
  )
  from public.workshops w
  where w.id = p_workshop_id and (w.status = 'verified' or w.owner_id = auth.uid())
$$;

-- ---------------------------------------------------------------------------
-- Slot booking: hormati libur khusus & tutup sementara
-- ---------------------------------------------------------------------------

create or replace function public.booking_available_slots(p_workshop_id uuid, p_date date)
returns table (slot_at timestamptz, label text, remaining int)
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_w public.workshops;
  v_tz text;
  v_open time;
  v_close time;
  v_closed boolean := false;
  v_minutes int := 60;
  v_capacity int := 1;
  v_lead int := coalesce((public.app_config_value('booking_min_lead_minutes') #>> '{}')::int, 60);
  v_ahead int := coalesce((public.app_config_value('booking_max_days_ahead') #>> '{}')::int, 14);
  v_t time;
  v_at timestamptz;
  v_used int;
begin
  select * into v_w from public.workshops where id = p_workshop_id and status = 'verified';
  if v_w.id is null then return; end if;
  v_tz := coalesce(v_w.timezone, 'Asia/Jakarta');
  if p_date < (now() at time zone v_tz)::date or p_date > (now() at time zone v_tz)::date + v_ahead then return; end if;
  if exists (select 1 from public.workshop_closures c where c.workshop_id = p_workshop_id and c.closed_on = p_date) then
    return;
  end if;

  select coalesce(c.slot_minutes, 60), coalesce(c.capacity_per_slot, 1) into v_minutes, v_capacity
  from public.workshop_slots_config c where c.workshop_id = p_workshop_id limit 1;
  v_minutes := greatest(coalesce(v_minutes, 60), 15);
  v_capacity := greatest(coalesce(v_capacity, 1), 1);

  if exists (select 1 from public.workshop_hours h where h.workshop_id = p_workshop_id) then
    select h.open_time, h.close_time, h.is_closed into v_open, v_close, v_closed
    from public.workshop_hours h
    where h.workshop_id = p_workshop_id and h.weekday = extract(dow from p_date)::int limit 1;
    if not found or v_closed or v_open is null or v_close is null then return; end if;
  else
    v_open := coalesce((public.app_config_value('booking_default_open') #>> '{}')::time, '08:00');
    v_close := coalesce((public.app_config_value('booking_default_close') #>> '{}')::time, '17:00');
  end if;

  v_t := v_open;
  while v_t + make_interval(mins => v_minutes) <= v_close loop
    v_at := (p_date + v_t) at time zone v_tz;
    if v_at >= now() + make_interval(mins => v_lead)
       and (v_w.temp_closed_until is null or v_at >= v_w.temp_closed_until) then
      select count(*)::int into v_used from public.bookings b
      where b.workshop_id = p_workshop_id and b.scheduled_at = v_at
        and b.status not in ('KEDALUWARSA', 'DITOLAK', 'DIBATALKAN')
        and not (b.status = 'MENUNGGU_PEMBAYARAN' and b.payment_deadline < now());
      slot_at := v_at;
      label := to_char(v_t, 'HH24:MI');
      remaining := greatest(v_capacity - v_used, 0);
      return next;
    end if;
    v_t := v_t + make_interval(mins => v_minutes);
    exit when v_t < v_open;
  end loop;
end$$;

-- nearby_workshops kini ikut mengembalikan is_open (kartu "Buka/Tutup").
drop function if exists public.nearby_workshops(double precision, double precision, double precision, int);
create function public.nearby_workshops(
  lat double precision,
  lng double precision,
  radius_m double precision default 10000,
  limit_n int default 50
)
returns table (
  id uuid, name text, address text, rating_avg numeric, rating_count int,
  distance_m double precision, is_open boolean
)
language sql stable security definer set search_path = public, extensions
as $$
  select w.id, w.name, w.address, w.rating_avg, w.rating_count,
    extensions.st_distance(w.location, extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography),
    public.workshop_is_open(w.id, now())
  from public.workshops w
  where w.status = 'verified' and w.location is not null
    and extensions.st_dwithin(w.location,
      extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography, radius_m)
  order by 6 asc
  limit limit_n;
$$;

-- ---------------------------------------------------------------------------
-- RPC pemilik
-- ---------------------------------------------------------------------------

create or replace function public.owner_my_workshop()
returns public.workshops language plpgsql stable security definer set search_path = public, extensions as $$
declare v_w public.workshops;
begin
  if auth.uid() is null then raise exception 'Silakan masuk terlebih dahulu'; end if;
  select * into v_w from public.workshops where owner_id = auth.uid() order by created_at limit 1;
  if v_w.id is null then raise exception 'Kamu belum punya bengkel'; end if;
  return v_w;
end$$;

create or replace function public.owner_schedule_get()
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_w public.workshops := public.owner_my_workshop();
  v_today date := (now() at time zone v_w.timezone)::date;
begin
  return jsonb_build_object(
    'workshop_id', v_w.id,
    'timezone', v_w.timezone,
    'is_open', public.workshop_is_open(v_w.id, now()),
    'temp_closed_until', case when v_w.temp_closed_until > now() then v_w.temp_closed_until end,
    'temp_closed_reason', case when v_w.temp_closed_until > now() then v_w.temp_closed_reason end,
    'has_hours', exists (select 1 from public.workshop_hours h where h.workshop_id = v_w.id),
    'hours', coalesce((
      select jsonb_agg(jsonb_build_object(
        'weekday', d.wd,
        'open_time', to_char(coalesce(h.open_time, '08:00'), 'HH24:MI'),
        'close_time', to_char(coalesce(h.close_time, '17:00'), 'HH24:MI'),
        'is_closed', coalesce(h.is_closed, false)) order by d.wd)
      from generate_series(0, 6) d(wd)
      left join public.workshop_hours h on h.workshop_id = v_w.id and h.weekday = d.wd), '[]'::jsonb),
    'slot_minutes', coalesce((select slot_minutes from public.workshop_slots_config where workshop_id = v_w.id), 60),
    'capacity_per_slot', coalesce((select capacity_per_slot from public.workshop_slots_config where workshop_id = v_w.id), 1),
    'closures', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', c.closed_on, 'reason', c.reason,
        'active_bookings', (select count(*) from public.bookings b
          where b.workshop_id = v_w.id and (b.scheduled_at at time zone v_w.timezone)::date = c.closed_on
            and b.status in ('MENUNGGU_PEMBAYARAN','DIBAYAR_MENUNGGU_KONFIRMASI','DIKONFIRMASI')))
        order by c.closed_on)
      from public.workshop_closures c
      where c.workshop_id = v_w.id and c.closed_on >= v_today), '[]'::jsonb)
  );
end$$;

-- p_hours: [{weekday, open_time "HH:MM", close_time "HH:MM", is_closed}] (boleh sebagian hari).
create or replace function public.owner_schedule_set_hours(
  p_hours jsonb, p_slot_minutes int default null, p_capacity int default null
)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_w public.workshops := public.owner_my_workshop();
  v_row jsonb;
  v_wd int;
  v_open time;
  v_close time;
  v_closed boolean;
  v_open_days int := 0;
begin
  if p_hours is null or jsonb_typeof(p_hours) <> 'array' or jsonb_array_length(p_hours) = 0 then
    raise exception 'Jadwal kosong';
  end if;
  if p_slot_minutes is not null and p_slot_minutes not in (15, 30, 45, 60, 90, 120) then
    raise exception 'Durasi slot harus 15, 30, 45, 60, 90, atau 120 menit';
  end if;
  if p_capacity is not null and (p_capacity < 1 or p_capacity > 20) then
    raise exception 'Kapasitas per slot 1–20 motor';
  end if;

  for v_row in select * from jsonb_array_elements(p_hours) loop
    v_wd := (v_row->>'weekday')::int;
    if v_wd is null or v_wd < 0 or v_wd > 6 then raise exception 'Hari tidak valid'; end if;
    v_closed := coalesce((v_row->>'is_closed')::boolean, false);
    v_open := nullif(v_row->>'open_time', '')::time;
    v_close := nullif(v_row->>'close_time', '')::time;
    if not v_closed then
      if v_open is null or v_close is null then raise exception 'Jam buka & tutup wajib diisi'; end if;
      if v_close <= v_open then
        raise exception 'Jam tutup harus setelah jam buka (%)', (array['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'])[v_wd + 1];
      end if;
    end if;
    insert into public.workshop_hours (workshop_id, weekday, open_time, close_time, is_closed)
    values (v_w.id, v_wd, v_open, v_close, v_closed)
    on conflict (workshop_id, weekday) do update
      set open_time = excluded.open_time, close_time = excluded.close_time, is_closed = excluded.is_closed;
  end loop;

  select count(*) into v_open_days from public.workshop_hours where workshop_id = v_w.id and not is_closed;
  if v_open_days = 0 then
    raise exception 'Minimal satu hari buka. Untuk libur panjang pakai "Libur khusus" atau "Tutup sementara"';
  end if;

  if p_slot_minutes is not null or p_capacity is not null then
    insert into public.workshop_slots_config (workshop_id, slot_minutes, capacity_per_slot)
    values (v_w.id, coalesce(p_slot_minutes, 60), coalesce(p_capacity, 1))
    on conflict (workshop_id) do update
      set slot_minutes = coalesce(p_slot_minutes, public.workshop_slots_config.slot_minutes),
          capacity_per_slot = coalesce(p_capacity, public.workshop_slots_config.capacity_per_slot);
  end if;

  return public.owner_schedule_get();
end$$;

create or replace function public.owner_closure_add(p_date date, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_w public.workshops := public.owner_my_workshop();
  v_today date := (now() at time zone v_w.timezone)::date;
  v_affected int;
begin
  if p_date is null or p_date < v_today then raise exception 'Tanggal libur tidak boleh di masa lalu'; end if;
  if p_date > v_today + 365 then raise exception 'Tanggal libur maksimal 1 tahun ke depan'; end if;
  insert into public.workshop_closures (workshop_id, closed_on, reason)
  values (v_w.id, p_date, nullif(trim(coalesce(p_reason, '')), ''))
  on conflict (workshop_id, closed_on) do update set reason = excluded.reason;

  select count(*) into v_affected from public.bookings b
  where b.workshop_id = v_w.id and (b.scheduled_at at time zone v_w.timezone)::date = p_date
    and b.status in ('MENUNGGU_PEMBAYARAN','DIBAYAR_MENUNGGU_KONFIRMASI','DIKONFIRMASI');
  return jsonb_build_object('date', p_date, 'active_bookings', v_affected);
end$$;

create or replace function public.owner_closure_remove(p_date date)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare v_w public.workshops := public.owner_my_workshop();
begin
  delete from public.workshop_closures where workshop_id = v_w.id and closed_on = p_date;
end$$;

-- p_until null = buka kembali sekarang.
create or replace function public.owner_set_temp_closed(p_until timestamptz, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v_w public.workshops := public.owner_my_workshop();
begin
  if p_until is not null and p_until <= now() then raise exception 'Waktu buka kembali harus di masa depan'; end if;
  if p_until is not null and p_until > now() + interval '30 days' then
    raise exception 'Tutup sementara maksimal 30 hari. Untuk lebih lama pakai "Libur khusus"';
  end if;
  update public.workshops
  set temp_closed_until = p_until,
      temp_closed_reason = case when p_until is null then null else nullif(trim(coalesce(p_reason, '')), '') end,
      updated_at = now()
  where id = v_w.id;
  return public.owner_schedule_get();
end$$;

revoke all on function public.owner_my_workshop() from public, anon;
grant execute on function public.workshop_open_status(uuid) to anon, authenticated;
grant execute on function public.workshop_is_open(uuid, timestamptz) to anon, authenticated;
grant execute on function public.nearby_workshops(double precision, double precision, double precision, int) to anon, authenticated;
grant execute on function public.booking_available_slots(uuid, date) to anon, authenticated;
grant execute on function public.owner_schedule_get() to authenticated;
grant execute on function public.owner_schedule_set_hours(jsonb, int, int) to authenticated;
grant execute on function public.owner_closure_add(date, text) to authenticated;
grant execute on function public.owner_closure_remove(date) to authenticated;
grant execute on function public.owner_set_temp_closed(timestamptz, text) to authenticated;
