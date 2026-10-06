-- 0012_sos.sql — Bantuan Darurat motor mogok (Fitur B, PRD v1.3 Bagian 3)
--
-- Alur: MENUNGGU_PEMBAYARAN → MENCARI_BENGKEL → DITERIMA → MENUJU_LOKASI
--       → TIBA → MEMERIKSA → (DIKERJAKAN|SELESAI_TANPA_PERBAIKAN) → SELESAI
--
-- Semua tulisan dari klien lewat RPC (security definer) agar validasi
-- (tier, gelombang, atomitas penerimaan, refund) dilakukan di server.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'sos_status') then
    create type sos_status as enum (
  'MENUNGGU_PEMBAYARAN',
  'MENCARI_BENGKEL',
  'DITERIMA',
  'MENUJU_LOKASI',
  'TIBA',
  'MEMERIKSA',
  'DIKERJAKAN',
  'SELESAI',
  'SELESAI_TANPA_PERBAIKAN',
  'DIBATALKAN',
  'KEDALUWARSA',
  'TIDAK_ADA_BENGKEL'
);
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'sos_offer_state') then
    create type sos_offer_state as enum (
  'sent', 'accepted', 'skipped', 'expired', 'taken'
);
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'sos_problem') then
    create type sos_problem as enum (
  'ENGINE_DEAD', 'FLAT_TIRE', 'DEAD_BATTERY', 'OUT_OF_FUEL',
  'BRAKE_ISSUE', 'OTHER'
);
  end if;
end $$;

-- ===========================================================================
-- Tabel
-- ===========================================================================

create table if not exists public.sos_requests (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,                       -- kode 6 huruf untuk tampilan
  rider_id uuid not null references public.users (id) on delete cascade,
  status sos_status not null default 'MENUNGGU_PEMBAYARAN',
  problem_code sos_problem not null,
  problem_note text,
  photos text[] not null default '{}',             -- path di bucket sos-photos
  lat double precision not null,
  lng double precision not null,
  accuracy_m double precision not null,
  landmark text,                                    -- patokan dari pengendara
  tier int not null,                                -- tier tarif saat dibuat
  call_fee int not null default 0,
  night_fee int not null default 0,
  service_fee int not null default 0,
  total int not null default 0,                     -- call_fee + night_fee + service_fee
  commission_rate numeric(4,3) not null default 0.080,
  payment_expires_at timestamptz,                   -- batas bayar (sos_payment_minutes)
  accepted_workshop_id uuid references public.workshops (id) on delete set null,
  accepted_at timestamptz,
  arrived_at timestamptz,
  arrival_code text,                                -- 4 digit, dibuat saat TIBA
  wave int not null default 1,                      -- gelombang dispatch terkini
  ended_reason text,
  refund_percent int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (call_fee >= 0 and night_fee >= 0 and service_fee >= 0 and total >= 0),
  check (refund_percent between 0 and 100)
);
create index if not exists idx_sos_requests_rider on public.sos_requests (rider_id, created_at desc);
create index if not exists idx_sos_requests_status on public.sos_requests (status);
create index if not exists idx_sos_requests_workshop on public.sos_requests (accepted_workshop_id);

create table if not exists public.sos_offers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.sos_requests (id) on delete cascade,
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  wave int not null default 1,
  distance_m int not null,
  eta_min int not null,
  state sos_offer_state not null default 'sent',
  sent_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (request_id, workshop_id)                  -- satu tawaran per bengkel per request
);
create index if not exists idx_sos_offers_request on public.sos_offers (request_id, state);
create index if not exists idx_sos_offers_workshop on public.sos_offers (workshop_id, state);

-- Jejak lokasi mekanik: hanya baris terbaru dipakai penuh; sisia untuk audit 24 jam.
create table if not exists public.sos_tracking (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.sos_requests (id) on delete cascade,
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  speed double precision,
  heading double precision,
  recorded_at timestamptz not null default now()
);
create index if not exists idx_sos_tracking_request on public.sos_tracking (request_id, recorded_at desc);

-- Siaga darurat per bengkel (PRD 3.3).
create table if not exists public.workshop_standby (
  workshop_id uuid primary key references public.workshops (id) on delete cascade,
  emergency_ready boolean not null default false,
  after_hours boolean not null default false,       -- siaga di luar jam buka
  radius_tier_max int not null default 4,
  last_lat double precision,
  last_lng double precision,
  last_seen_at timestamptz,
  accept_rate numeric(3,2) not null default 1.0,    -- tingkat penerimaan
  updated_at timestamptz not null default now()
);
create index if not exists idx_workshop_standby_ready on public.workshop_standby (emergency_ready) where emergency_ready;

-- ===========================================================================
-- Helper: baca app_config sebagai jsonb.
-- ===========================================================================

create or replace function public.app_config_value(k text)
returns jsonb language sql stable security definer set search_path = public, extensions as $$
  select value from public.app_config where key = k;
$$;

-- Hitung tier berdasarkan jarak (meter) ke bengkel terdekat yang siaga.
create or replace function public.sos_tier_for_distance(dist_m double precision)
returns int language sql stable security definer set search_path = public, extensions as $$
  with tiers as (
    select (elem->>'tier')::int as tier, (elem->>'max_km')::int as max_km, (elem->>'fee')::int as fee
    from jsonb_array_elements(public.app_config_value('sos_tiers')) as elem
  )
  select coalesce(
    (select tier from tiers where (dist_m / 1000.0) <= max_km order by max_km asc limit 1),
    -- Lebih dari tier terakhir → null (di luar radius, penelusuran gagal).
    null
  )
$$;

-- Biaya panggilan untuk sebuah tier.
create or replace function public.sos_fee_for_tier(t int)
returns int language sql stable security definer set search_path = public, extensions as $$
  with tiers as (
    select (elem->>'tier')::int as tier, (elem->>'fee')::int as fee
    from jsonb_array_elements(public.app_config_value('sos_tiers')) as elem
  )
  select fee from tiers where tier = t
$$;

-- Label tier untuk tampilan ("≤ 3 km", "> 3 sampai 6 km", dst). PRD 3.5.
create or replace function public.sos_tier_label(t int)
returns text language sql stable security definer set search_path = public, extensions as $$
  with tiers as (
    select (elem->>'tier')::int as tier, (elem->>'max_km')::int as max_km,
           lag((elem->>'max_km')::int) over (order by (elem->>'tier')::int) as prev_km
    from jsonb_array_elements(public.app_config_value('sos_tiers')) as elem
  )
  select case
    when prev_km is null then '≤ ' || max_km || ' km'
    else '> ' || prev_km || ' sampai ' || max_km || ' km'
  end
  from tiers where tier = t
$$;

-- Apakah jam malam berlaku di waktu lokal pengendara? (21.00–05.00)
create or replace function public.sos_is_night(at timestamptz)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  with cfg as (
    select
      (public.app_config_value('sos_night_start_hour') #>> '{}')::int as start_h,
      (public.app_config_value('sos_night_end_hour') #>> '{}')::int as end_h
  )
  select case
    when start_h < end_h then
      extract(hour from at at time zone 'Asia/Jakarta')::int >= start_h
      and extract(hour from at at time zone 'Asia/Jakarta')::int < end_h
    else
      -- rentang melintasi tengah malam (mis. 21→5)
      extract(hour from at at time zone 'Asia/Jakarta')::int >= start_h
      or extract(hour from at at time zone 'Asia/Jakarta')::int < end_h
  end
  from cfg
$$;

-- ===========================================================================
-- RPC: quote biaya sebelum bayar. Harga TIDAK bisa naik setelah ini
-- karena tier dicatat ke permintaan. (PRD 3.5)
-- ===========================================================================

create or replace function public.sos_quote_fee(
  p_lat double precision,
  p_lng double precision
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_nearest record;
  v_tier int;
  v_call_fee int;
  v_night_fee int := 0;
  v_service_fee int := 0;
  v_max_radius int;
begin
  -- Bengkel siaga darurat terdekat.
  select w.id,
         extensions.st_distance(w.location, extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography) as dist_m
  into v_nearest
  from public.workshops w
  join public.workshop_standby s on s.workshop_id = w.id
  where s.emergency_ready = true
    and w.status = 'verified'
    and w.location is not null
    and s.last_seen_at > now() - interval '60 seconds'
  order by dist_m asc
  limit 1;

  v_max_radius := coalesce((public.app_config_value('sos_max_radius_m') #>> '{}')::int, 15000);

  if v_nearest.id is null then
    -- Tidak ada bengkel siaga sama sekali → kembalikan tier 1 default
    -- (biaya tetap ditampilkan; pencarian akan menawarkan perluas tier).
    v_tier := 1;
  else
    v_tier := public.sos_tier_for_distance(v_nearest.dist_m);
    if v_tier is null or v_nearest.dist_m > v_max_radius then
      v_tier := public.sos_tier_for_distance(v_max_radius::float);
    end if;
  end if;

  v_call_fee := public.sos_fee_for_tier(v_tier);

  if public.sos_is_night(now()) then
    v_night_fee := coalesce((public.app_config_value('sos_night_fee') #>> '{}')::int, 10000);
  end if;

  return jsonb_build_object(
    'tier', v_tier,
    'call_fee', v_call_fee,
    'night_fee', v_night_fee,
    'service_fee', v_service_fee,
    'total', v_call_fee + v_night_fee + v_service_fee,
    'tier_label', public.sos_tier_label(v_tier)
  );
end$$;

-- ===========================================================================
-- RPC: buat permintaan darurat + gelombang 1.
-- ===========================================================================

create or replace function public.sos_create(
  p_problem_code sos_problem,
  p_problem_note text,
  p_photos text[],
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_landmark text
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_rider uuid := auth.uid();
  v_active int;
  v_abuse_limit int;
  v_abuse_count int;
  v_hold_until timestamptz;
  v_fee jsonb;
  v_tier int;
  v_request public.sos_requests;
  v_wave_size int;
  v_wave_seconds int;
  v_eta_speed float;
  v_candidates record;
  v_offer_id uuid;
  v_offers jsonb[] := '{}';
  v_max_radius int;
begin
  if v_rider is null then
    raise exception 'Belum login';
  end if;

  -- Satu panggilan aktif per pengendara (PRD 3.4).
  select count(*) into v_active
  from public.sos_requests r
  where r.rider_id = v_rider
    and r.status in ('MENUNGGU_PEMBAYARAN','MENCARI_BENGKEL','DITERIMA','MENUJU_LOKASI','TIBA','MEMERIKSA','DIKERJAKAN');
  if v_active > 0 then
    raise exception 'Kamu masih punya panggilan darurat yang aktif';
  end if;

  -- Penyalahgunaan: pembatalan tanpa alasan (PRD 3.8).
  v_abuse_limit := coalesce((public.app_config_value('sos_abuse_limit') #>> '{}')::int, 5);
  select count(*) into v_abuse_count
  from public.sos_requests r
  where r.rider_id = v_rider
    and r.status = 'DIBATALKAN'
    and r.ended_reason = 'rider_cancel_no_reason'
    and r.created_at > now() - interval '30 days';
  if v_abuse_count >= v_abuse_limit then
    raise exception 'Fitur darurat ditahan sementara karena terlalu banyak pembatalan';
  end if;

  -- Biaya berdasarkan lokasi saat ini.
  v_fee := public.sos_quote_fee(p_lat, p_lng);
  v_tier := (v_fee->>'tier')::int;

  v_max_radius := coalesce((public.app_config_value('sos_max_radius_m') #>> '{}')::int, 15000);
  v_wave_size := coalesce((public.app_config_value('sos_wave_size') #>> '{}')::int, 3);
  v_wave_seconds := coalesce((public.app_config_value('sos_wave_seconds') #>> '{}')::int, 60);
  v_eta_speed := coalesce((public.app_config_value('sos_eta_speed_kmh') #>> '{}')::float, 25.0);

  insert into public.sos_requests (
    code, rider_id, status, problem_code, problem_note, photos,
    lat, lng, accuracy_m, landmark, tier,
    call_fee, night_fee, service_fee, total,
    payment_expires_at, wave
  ) values (
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    v_rider, 'MENUNGGU_PEMBAYARAN', p_problem_code, p_problem_note, coalesce(p_photos, '{}'),
    p_lat, p_lng, p_accuracy_m, p_landmark, v_tier,
    (v_fee->>'call_fee')::int, (v_fee->>'night_fee')::int, (v_fee->>'service_fee')::int, (v_fee->>'total')::int,
    now() + (coalesce((public.app_config_value('sos_payment_minutes') #>> '{}')::int, 10) || ' minutes')::interval,
    1
  )
  returning * into v_request;

  -- Gelombang 1: kirim ke bengkel siaga dalam radius tier.
  for v_candidates in
    select w.id, w.location,
           extensions.st_distance(w.location, extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography) as dist_m
    from public.workshops w
    join public.workshop_standby s on s.workshop_id = w.id
    where s.emergency_ready = true
      and w.status = 'verified'
      and w.location is not null
      and s.last_seen_at > now() - interval '60 seconds'
      and public.sos_tier_for_distance(
            extensions.st_distance(w.location, extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography)
          ) <= v_tier
      and w.id not in (
        select workshop_id from public.sos_offers where request_id = v_request.id
      )
    order by dist_m asc
    limit v_wave_size
  loop
    insert into public.sos_offers (request_id, workshop_id, wave, distance_m, eta_min, expires_at)
    values (v_request.id, v_candidates.id, 1, v_candidates.dist_m::int,
            greatest(1, round(v_candidates.dist_m / 1000.0 / v_eta_speed * 60))::int,
            now() + (v_wave_seconds || ' seconds')::interval)
    returning id into v_offer_id;

    v_offers := v_offers || jsonb_build_object(
      'offer_id', v_offer_id,
      'workshop_id', v_candidates.id,
      'distance_m', v_candidates.dist_m::int
    );
  end loop;

  return jsonb_build_object(
    'request', to_jsonb(v_request),
    'offers', to_jsonb(v_offers)
  );
end$$;

-- ===========================================================================
-- RPC: lanjutkan ke gelombang berikutnya (dipanggil cron / klien tiap 10 dtk).
-- ===========================================================================

create or replace function public.sos_dispatch_wave()
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_req record;
  v_wave_size int;
  v_wave_count int;
  v_wave_seconds int;
  v_eta_speed float;
  v_max_radius int;
  v_candidates record;
  v_offer_id uuid;
begin
  v_wave_size := coalesce((public.app_config_value('sos_wave_size') #>> '{}')::int, 3);
  v_wave_count := coalesce((public.app_config_value('sos_wave_count') #>> '{}')::int, 3);
  v_wave_seconds := coalesce((public.app_config_value('sos_wave_seconds') #>> '{}')::int, 60);
  v_eta_speed := coalesce((public.app_config_value('sos_eta_speed_kmh') #>> '{}')::float, 25.0);
  v_max_radius := coalesce((public.app_config_value('sos_max_radius_m') #>> '{}')::int, 15000);

  for v_req in
    select id, rider_id, lat, lng, tier, wave
    from public.sos_requests
    where status = 'MENCARI_BENGKEL'
      and updated_at < now() - (v_wave_seconds || ' seconds')::interval
  loop
    -- Gelombang terakhir lewat → tidak ada bengkel.
    if v_req.wave >= v_wave_count then
      update public.sos_requests
      set status = 'TIDAK_ADA_BENGKEL',
          ended_reason = 'no_workshop_all_waves',
          updated_at = now()
      where id = v_req.id;
      -- Refund penuh otomatis ditangani lapis pembayaran (hook/service).
      continue;
    end if;

    -- Kirim gelombang berikutnya.
    for v_candidates in
      select w.id, w.location,
             extensions.st_distance(w.location, extensions.st_setsrid(extensions.st_makepoint(v_req.lng, v_req.lat), 4326)::extensions.geography) as dist_m
      from public.workshops w
      join public.workshop_standby s on s.workshop_id = w.id
      where s.emergency_ready = true
        and w.status = 'verified'
        and w.location is not null
        and s.last_seen_at > now() - interval '60 seconds'
        and public.sos_tier_for_distance(
              extensions.st_distance(w.location, extensions.st_setsrid(extensions.st_makepoint(v_req.lng, v_req.lat), 4326)::extensions.geography)
            ) <= v_req.tier
        and w.id not in (select workshop_id from public.sos_offers where request_id = v_req.id)
      order by dist_m asc
      limit v_wave_size
    loop
      insert into public.sos_offers (request_id, workshop_id, wave, distance_m, eta_min, expires_at)
      values (v_req.id, v_candidates.id, v_req.wave + 1, v_candidates.dist_m::int,
              greatest(1, round(v_candidates.dist_m / 1000.0 / v_eta_speed * 60))::int,
              now() + (v_wave_seconds || ' seconds')::interval)
      returning id into v_offer_id;
    end loop;

    update public.sos_requests
    set wave = v_req.wave + 1, updated_at = now()
    where id = v_req.id;
  end loop;

  -- Tawaran kedaluwarsa yang tidak dijawab → skipped, turunkan accept_rate.
  update public.workshop_standby s
  set accept_rate = greatest(0.0, s.accept_rate - 0.02),
      updated_at = now()
  where s.workshop_id in (
    select o.workshop_id from public.sos_offers o
    join public.sos_requests r on r.id = o.request_id
    where o.state = 'sent' and o.expires_at < now()
      and r.status in ('MENCARI_BENGKEL','TIDAK_ADA_BENGKEL','DIBATALKAN')
  );

  update public.sos_offers
  set state = 'expired'
  where state = 'sent' and expires_at < now();
end$$;

-- ===========================================================================
-- RPC: bengkel menerima tawaran. Atomik: FOR UPDATE SKIP LOCKED.
-- Yang pertama menerima menang; penerima lain dapat "sudah diambil". (PRD 3.4)
-- ===========================================================================

create or replace function public.sos_accept(p_offer_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_offer public.sos_offers;
  v_request public.sos_requests;
  v_workshop uuid;
  v_mechanic_name text;
begin
  select id into v_workshop
  from public.workshops where owner_id = auth.uid()
  order by created_at limit 1;
  if v_workshop is null then
    raise exception 'Kamu bukan pemilik bengkel';
  end if;

  select * into v_offer
  from public.sos_offers
  where id = p_offer_id
  for update skip locked;

  if v_offer is null or v_offer.workshop_id <> v_workshop then
    raise exception 'Tawaran tidak ditemukan';
  end if;

  if v_offer.state <> 'sent' then
    raise exception 'Panggilan sudah diambil';
  end if;

  select * into v_request
  from public.sos_requests
  where id = v_offer.request_id
  for update;

  if v_request.status <> 'MENCARI_BENGKEL' then
    -- Permintaan sudah diambil bengkel lain.
    update public.sos_offers set state = 'taken' where id = p_offer_id;
    raise exception 'Panggilan sudah diambil bengkel lain';
  end if;

  -- Menang.
  update public.sos_offers set state = 'accepted' where id = p_offer_id;
  -- Tawaran lain untuk request yang sama → taken.
  update public.sos_offers set state = 'taken'
  where request_id = v_offer.request_id and id <> p_offer_id and state = 'sent';

  update public.sos_requests
  set status = 'DITERIMA',
      accepted_workshop_id = v_workshop,
      accepted_at = now(),
      updated_at = now()
  where id = v_offer.request_id;

  -- Naikkan tingkat penerimaan bengkel.
  update public.workshop_standby
  set accept_rate = least(1.0, accept_rate + 0.02),
      updated_at = now()
  where workshop_id = v_workshop;

  -- Data mekanik untuk ditampilkan ke pengendara.
  select w.name into v_mechanic_name
  from public.workshops w where w.id = v_workshop;

  return jsonb_build_object(
    'request_id', v_offer.request_id,
    'workshop_id', v_workshop,
    'mechanic_name', v_mechanic_name
  );
end$$;

-- ===========================================================================
-- RPC: mekanik sampai di lokasi → generate kode 4 digit.
-- ===========================================================================

create or replace function public.sos_mark_arrived(p_request_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_request public.sos_requests;
  v_code text;
  v_workshop uuid;
begin
  select id into v_workshop
  from public.workshops where owner_id = auth.uid()
  order by created_at limit 1;

  select * into v_request
  from public.sos_requests
  where id = p_request_id and accepted_workshop_id = v_workshop
  for update;

  if v_request is null then
    raise exception 'Permintaan tidak ditemukan atau bukan milik bengkelmu';
  end if;

  if v_request.status not in ('DITERIMA','MENUJU_LOKASI') then
    raise exception 'Permintaan tidak dalam status yang bisa ditandai tiba';
  end if;

  v_code := lpad((random() * 9999)::int::text, 4, '0');

  update public.sos_requests
  set status = 'TIBA', arrived_at = now(), arrival_code = v_code, updated_at = now()
  where id = p_request_id;

  return jsonb_build_object('arrival_code', v_code);
end$$;

-- Pengendara memasukkan kode untuk konfirmasi kehadiran (opsional, validasi sisi klien).
create or replace function public.sos_confirm_arrival(
  p_request_id uuid,
  p_code text
)
returns boolean
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_request public.sos_requests;
begin
  select * into v_request
  from public.sos_requests
  where id = p_request_id and rider_id = auth.uid()
  for update;

  if v_request is null then
    raise exception 'Permintaan tidak ditemukan';
  end if;

  if v_request.arrival_code is null or v_request.arrival_code <> p_code then
    return false;
  end if;

  if v_request.status = 'TIBA' then
    update public.sos_requests
    set status = 'MEMERIKSA', updated_at = now()
    where id = p_request_id;
  end if;

  return true;
end$$;

-- ===========================================================================
-- RPC: batalkan. Refund 100/50/0% sesuai tahap. (PRD 3.6)
-- ===========================================================================

create or replace function public.sos_cancel(
  p_request_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_request public.sos_requests;
  v_refund int := 0;
  v_free_seconds int;
  v_free_radius int;
  v_moved_m float := 0;
  v_last record;
begin
  select * into v_request
  from public.sos_requests
  where id = p_request_id
  for update;

  if v_request is null then
    raise exception 'Permintaan tidak ditemukan';
  end if;

  -- Hanya rider pemilik atau bengkel penerima.
  if v_request.rider_id <> auth.uid()
     and v_request.accepted_workshop_id is distinct from (
       select id from public.workshops where owner_id = auth.uid()
     ) then
    raise exception 'Tidak berhak membatalkan';
  end if;

  v_free_seconds := coalesce((public.app_config_value('sos_cancel_free_seconds') #>> '{}')::int, 120);
  v_free_radius := coalesce((public.app_config_value('sos_cancel_free_radius_m') #>> '{}')::int, 300);

  if v_request.status in ('MENUNGGU_PEMBAYARAN','MENCARI_BENGKEL','TIDAK_ADA_BENGKEL') then
    -- Belum ada yang menerima: refund 100%.
    v_refund := 100;
  elsif v_request.status = 'DITERIMA' then
    -- ≤ 2 menit setelah diterima & mekanik belum bergerak > 300 m: 100%.
    select lat, lng into v_last
    from public.sos_tracking
    where request_id = p_request_id
    order by recorded_at desc limit 1;

    if v_last.lat is not null then
      v_moved_m := extensions.st_distance(
        extensions.st_setsrid(extensions.st_makepoint(v_last.lng, v_last.lat), 4326)::extensions.geography,
        extensions.st_setsrid(extensions.st_makepoint(v_request.lng, v_request.lat), 4326)::extensions.geography
      );
    end if;

    if now() - v_request.accepted_at < (v_free_seconds || ' seconds')::interval
       and v_moved_m <= v_free_radius then
      v_refund := 100;
    else
      v_refund := 50;  -- 50% ke bengkel (PRD 3.6)
    end if;
  elsif v_request.status = 'MENUJU_LOKASI' then
    v_refund := 50;
  else
    raise exception 'Tidak bisa membatalkan di tahap ini';
  end if;

  update public.sos_requests
  set status = 'DIBATALKAN',
      ended_reason = p_reason,
      refund_percent = v_refund,
      updated_at = now()
  where id = p_request_id;

  return jsonb_build_object(
    'refund_percent', v_refund,
    'refund_amount', round(v_request.total * v_refund / 100.0)::int,
    'message', case when v_refund = 100 then 'Refund penuh' else 'Refund sebagian' end
  );
end$$;

-- ===========================================================================
-- RPC: selesai (dengan atau tanpa perbaikan).
-- ===========================================================================

create or replace function public.sos_complete(
  p_request_id uuid,
  p_with_repair boolean
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_workshop uuid;
begin
  select id into v_workshop
  from public.workshops where owner_id = auth.uid()
  order by created_at limit 1;

  update public.sos_requests
  set status = (case when p_with_repair then 'SELESAI' else 'SELESAI_TANPA_PERBAIKAN' end)::sos_status,
      ended_reason = case when p_with_repair then 'repair_done' else 'no_repair_needed' end,
      updated_at = now()
  where id = p_request_id
    and accepted_workshop_id = v_workshop
    and status in ('MEMERIKSA','DIKERJAKAN');
end$$;

-- ===========================================================================
-- RPC: toggle siaga darurat (bengkel).
-- ===========================================================================

create or replace function public.sos_toggle_standby(
  p_workshop_id uuid,
  p_ready boolean,
  p_radius_tier_max int default 4
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_owner uuid;
begin
  select owner_id into v_owner from public.workshops where id = p_workshop_id;
  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'Bukan bengkelmu';
  end if;

  insert into public.workshop_standby (workshop_id, emergency_ready, radius_tier_max, updated_at)
  values (p_workshop_id, p_ready, p_radius_tier_max, now())
  on conflict (workshop_id) do update
    set emergency_ready = excluded.emergency_ready,
        radius_tier_max = excluded.radius_tier_max,
        updated_at = now();
end$$;

-- Perbarui posisi siaga bengkel (dipanggil berkala aplikasi owner).
create or replace function public.sos_update_standby_position(
  p_workshop_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_owner uuid;
begin
  select owner_id into v_owner from public.workshops where id = p_workshop_id;
  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'Bukan bengkelmu';
  end if;

  update public.workshop_standby
  set last_lat = p_lat, last_lng = p_lng, last_seen_at = now(), updated_at = now()
  where workshop_id = p_workshop_id and emergency_ready = true;
end$$;

-- ===========================================================================
-- Trigger: updated_at otomatis.
-- ===========================================================================

create or replace function public.sos_touch_updated()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end$$;

drop trigger if exists trg_sos_requests_touch on public.sos_requests;
create trigger trg_sos_requests_touch
  before update on public.sos_requests
  for each row execute function public.sos_touch_updated();

-- ===========================================================================
-- RLS
-- ===========================================================================

alter table public.sos_requests enable row level security;
alter table public.sos_offers enable row level security;
alter table public.sos_tracking enable row level security;
alter table public.workshop_standby enable row level security;

-- Pengendara hanya melihat permintaannya sendiri.
create policy sos_requests_rider_read on public.sos_requests
  for select using (rider_id = auth.uid());

-- Bengkel hanya melihat permintaan yang ditawarkan/diterimanya.
create policy sos_requests_workshop_read on public.sos_requests
  for select using (
    accepted_workshop_id = (select id from public.workshops where owner_id = auth.uid())
    or id in (
      select request_id from public.sos_offers
      where workshop_id = (select id from public.workshops where owner_id = auth.uid())
    )
  );

-- Bengkel melihat tawaran untuk workshop-nya.
create policy sos_offers_workshop_read on public.sos_offers
  for select using (
    workshop_id = (select id from public.workshops where owner_id = auth.uid())
  );

-- Pengendara melihat tracking permintaannya.
create policy sos_tracking_rider_read on public.sos_tracking
  for select using (
    request_id in (select id from public.sos_requests where rider_id = auth.uid())
  );

-- Bengkel melihat + menulis tracking permintaan yang diterimanya.
create policy sos_tracking_workshop_read on public.sos_tracking
  for select using (
    request_id in (
      select id from public.sos_requests
      where accepted_workshop_id = (select id from public.workshops where owner_id = auth.uid())
    )
  );

create policy sos_tracking_workshop_write on public.sos_tracking
  for insert with check (
    request_id in (
      select id from public.sos_requests
      where accepted_workshop_id = (select id from public.workshops where owner_id = auth.uid())
    )
  );

-- Standby: hanya bengkel pemilik (baca + tulis via RPC).
create policy standby_owner_read on public.workshop_standby
  for select using (
    workshop_id = (select id from public.workshops where owner_id = auth.uid())
  );

-- Semua tulisan ke sos_* lewat RPC (security definer) — tidak ada policy insert
-- langsung pada sos_requests/sos_offers dari klien.

-- ===========================================================================
-- Realtime: publikasikan perubahan status permintaan & tawaran baru.
-- ===========================================================================

alter publication supabase_realtime add table public.sos_requests;
alter publication supabase_realtime add table public.sos_offers;

-- ===========================================================================
-- Pembersihan berkala jejak lokasi (retensi 24 jam).
-- ===========================================================================

create or replace function public.sos_prune_tracking()
returns void language sql security definer set search_path = public, extensions as $$
  delete from public.sos_tracking
  where recorded_at < now() - (
    (coalesce((public.app_config_value('sos_tracking_retention_hours') #>> '{}')::int, 24) || ' hours')::interval
  );
$$;
