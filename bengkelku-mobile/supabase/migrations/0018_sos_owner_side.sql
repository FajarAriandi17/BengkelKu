-- 0018_sos_owner_side.sql — sisi bengkel Bantuan Darurat (PRD v1.3 Bagian 3.3, 3.4, 3.8)
--
-- Perbaikan & tambahan yang dibutuhkan layar ownerStandby / ownerSosOffer /
-- ownerSosRoute / ownerQuoteForm:
--   1) Tawaran baru dikirim SETELAH biaya panggilan dibayar (sebelumnya
--      sos_create sudah mengirim gelombang 1 saat MENUNGGU_PEMBAYARAN).
--   2) Pemilihan kandidat terpusat di sos_send_wave(): menghormati
--      radius_tier_max, jam buka / siaga di luar jam buka, satu panggilan aktif
--      per bengkel, dan urutan (tingkat penerimaan rendah turun urutan).
--   3) Privasi: bengkel yang hanya ditawari TIDAK bisa membaca lokasi tepat.
--      Detail tawaran lewat sos_offer_details() (lokasi dibulatkan ±300 m).
--   4) RPC baru: sos_skip_offer, sos_verify_arrival_code (mekanik memasukkan
--      kode 4 digit dari pengendara), sos_update_standby_settings.
--   5) quote_approve: penawaran yang disetujui saat TIBA juga → DIKERJAKAN.

-- ===========================================================================
-- Kolom tambahan
-- ===========================================================================

alter table public.sos_requests
  add column if not exists arrival_code_attempts int not null default 0;

-- ===========================================================================
-- Helper
-- ===========================================================================

-- Bengkel milik user saat ini (MVP: satu bengkel per pemilik).
create or replace function public.sos_my_workshop_id()
returns uuid language sql stable security definer set search_path = public, extensions as $$
  select id from public.workshops where owner_id = auth.uid() order by created_at limit 1
$$;

-- Apakah bengkel buka pada waktu `at` (zona waktu bengkel)?
-- Bengkel tanpa jadwal sama sekali dianggap buka (belum mengisi jam).
create or replace function public.workshop_is_open(p_workshop_id uuid, at timestamptz)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select case
    when not exists (select 1 from public.workshop_hours h where h.workshop_id = p_workshop_id)
      then true
    else exists (
      select 1
      from public.workshop_hours h
      join public.workshops w on w.id = h.workshop_id
      where h.workshop_id = p_workshop_id
        and h.weekday = extract(dow from at at time zone w.timezone)::int
        and not h.is_closed
        and h.open_time is not null and h.close_time is not null
        and (at at time zone w.timezone)::time >= h.open_time
        and (at at time zone w.timezone)::time < h.close_time
    )
  end
$$;

-- Status "sedang menangani panggilan" (setelah diterima, belum selesai).
create or replace function public.sos_active_job_statuses()
returns sos_status[] language sql immutable as $$
  select array['DITERIMA','MENUJU_LOKASI','TIBA','MEMERIKSA','DIKERJAKAN']::sos_status[]
$$;

-- ===========================================================================
-- Kirim satu gelombang tawaran. Mengembalikan jumlah tawaran yang dikirim.
-- ===========================================================================

create or replace function public.sos_send_wave(p_request_id uuid, p_wave int)
returns int
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_req public.sos_requests;
  v_wave_size int;
  v_wave_seconds int;
  v_eta_speed float;
  v_min_rate numeric;
  v_point geography;
  v_sent int := 0;
  v_c record;
begin
  select * into v_req from public.sos_requests where id = p_request_id;
  if v_req is null or v_req.status <> 'MENCARI_BENGKEL' then
    return 0;
  end if;

  v_wave_size := coalesce((public.app_config_value('sos_wave_size') #>> '{}')::int, 3);
  v_wave_seconds := coalesce((public.app_config_value('sos_offer_seconds') #>> '{}')::int,
                    coalesce((public.app_config_value('sos_wave_seconds') #>> '{}')::int, 60));
  v_eta_speed := coalesce((public.app_config_value('sos_eta_speed_kmh') #>> '{}')::float, 25.0);
  v_min_rate := coalesce((public.app_config_value('sos_min_accept_rate') #>> '{}')::numeric, 0.7);
  v_point := st_setsrid(st_makepoint(v_req.lng, v_req.lat), 4326)::geography;

  for v_c in
    select w.id,
           st_distance(w.location, v_point) as dist_m
    from public.workshops w
    join public.workshop_standby s on s.workshop_id = w.id
    where s.emergency_ready = true
      and w.status = 'verified'
      and w.location is not null
      and w.owner_id <> v_req.rider_id
      and s.last_seen_at > now() - interval '60 seconds'
      and public.sos_tier_for_distance(st_distance(w.location, v_point)) <= v_req.tier
      and public.sos_tier_for_distance(st_distance(w.location, v_point)) <= s.radius_tier_max
      and (s.after_hours or public.workshop_is_open(w.id, now()))
      and not exists (
        select 1 from public.sos_offers o
        where o.request_id = v_req.id and o.workshop_id = w.id
      )
      and not exists (
        select 1 from public.sos_requests r
        where r.accepted_workshop_id = w.id
          and r.status = any (public.sos_active_job_statuses())
      )
    order by (s.accept_rate < v_min_rate) asc,
             st_distance(w.location, v_point) asc,
             w.rating_avg desc,
             s.accept_rate desc
    limit v_wave_size
  loop
    insert into public.sos_offers (request_id, workshop_id, wave, distance_m, eta_min, expires_at)
    values (v_req.id, v_c.id, p_wave, v_c.dist_m::int,
            greatest(1, round(v_c.dist_m / 1000.0 / v_eta_speed * 60))::int,
            now() + (v_wave_seconds || ' seconds')::interval);
    v_sent := v_sent + 1;
  end loop;

  return v_sent;
end$$;

-- ===========================================================================
-- sos_create: tidak lagi mengirim tawaran (dikirim setelah bayar).
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
  v_fee jsonb;
  v_request public.sos_requests;
begin
  if v_rider is null then
    raise exception 'Belum login';
  end if;

  select count(*) into v_active
  from public.sos_requests r
  where r.rider_id = v_rider
    and r.status in ('MENUNGGU_PEMBAYARAN','MENCARI_BENGKEL','DITERIMA','MENUJU_LOKASI','TIBA','MEMERIKSA','DIKERJAKAN');
  if v_active > 0 then
    raise exception 'Kamu masih punya panggilan darurat yang aktif';
  end if;

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

  v_fee := public.sos_quote_fee(p_lat, p_lng);

  insert into public.sos_requests (
    code, rider_id, status, problem_code, problem_note, photos,
    lat, lng, accuracy_m, landmark, tier,
    call_fee, night_fee, service_fee, total,
    commission_rate, payment_expires_at, wave
  ) values (
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    v_rider, 'MENUNGGU_PEMBAYARAN', p_problem_code, p_problem_note, coalesce(p_photos, '{}'),
    p_lat, p_lng, p_accuracy_m, p_landmark, (v_fee->>'tier')::int,
    (v_fee->>'call_fee')::int, (v_fee->>'night_fee')::int, (v_fee->>'service_fee')::int, (v_fee->>'total')::int,
    coalesce((public.app_config_value('commission_rate') #>> '{}')::numeric, 0.08),
    now() + (coalesce((public.app_config_value('sos_payment_minutes') #>> '{}')::int, 10) || ' minutes')::interval,
    1
  )
  returning * into v_request;

  return jsonb_build_object(
    'request', to_jsonb(v_request),
    'offers', '[]'::jsonb
  );
end$$;

-- ===========================================================================
-- sos_mark_paid: setelah bayar → MENCARI_BENGKEL + gelombang 1.
-- ===========================================================================

create or replace function public.sos_mark_paid(p_request_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_request public.sos_requests;
begin
  select * into v_request
  from public.sos_requests
  where id = p_request_id
  for update;

  if v_request is null then
    raise exception 'Permintaan tidak ditemukan';
  end if;
  if v_request.rider_id <> auth.uid() then
    raise exception 'Tidak berhak';
  end if;

  if v_request.status <> 'MENUNGGU_PEMBAYARAN' then
    return to_jsonb(v_request);
  end if;

  if v_request.payment_expires_at is not null
     and v_request.payment_expires_at < now() then
    update public.sos_requests
    set status = 'KEDALUWARSA', ended_reason = 'payment_expired', updated_at = now()
    where id = p_request_id
    returning * into v_request;
    return to_jsonb(v_request);
  end if;

  update public.sos_requests
  set status = 'MENCARI_BENGKEL', wave = 1, updated_at = now()
  where id = p_request_id;

  perform public.sos_send_wave(p_request_id, 1);

  select * into v_request from public.sos_requests where id = p_request_id;
  return to_jsonb(v_request);
end$$;

-- ===========================================================================
-- sos_dispatch_wave: memakai sos_send_wave.
-- ===========================================================================

create or replace function public.sos_dispatch_wave()
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_req record;
  v_wave_count int;
  v_wave_seconds int;
begin
  v_wave_count := coalesce((public.app_config_value('sos_wave_count') #>> '{}')::int, 3);
  v_wave_seconds := coalesce((public.app_config_value('sos_wave_seconds') #>> '{}')::int, 60);

  -- Tawaran yang tidak dijawab sampai habis → expired, turunkan tingkat penerimaan.
  update public.workshop_standby s
  set accept_rate = greatest(0.0, s.accept_rate - 0.02), updated_at = now()
  where s.workshop_id in (
    select o.workshop_id from public.sos_offers o
    where o.state = 'sent' and o.expires_at < now()
  );
  update public.sos_offers
  set state = 'expired'
  where state = 'sent' and expires_at < now();

  for v_req in
    select id, wave
    from public.sos_requests
    where status = 'MENCARI_BENGKEL'
      and updated_at < now() - (v_wave_seconds || ' seconds')::interval
    for update skip locked
  loop
    if v_req.wave >= v_wave_count then
      update public.sos_requests
      set status = 'TIDAK_ADA_BENGKEL',
          ended_reason = 'no_workshop_all_waves',
          refund_percent = 100,
          updated_at = now()
      where id = v_req.id;
      continue;
    end if;

    update public.sos_requests
    set wave = v_req.wave + 1, updated_at = now()
    where id = v_req.id;

    perform public.sos_send_wave(v_req.id, v_req.wave + 1);
  end loop;

  perform public.quote_expire_stale();
end$$;

-- ===========================================================================
-- sos_accept: + cek tawaran belum lewat waktu & satu panggilan aktif per bengkel.
-- ===========================================================================

create or replace function public.sos_accept(p_offer_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_offer public.sos_offers;
  v_request public.sos_requests;
  v_workshop uuid := public.sos_my_workshop_id();
  v_name text;
begin
  if v_workshop is null then
    raise exception 'Kamu bukan pemilik bengkel';
  end if;

  if exists (
    select 1 from public.sos_requests r
    where r.accepted_workshop_id = v_workshop
      and r.status = any (public.sos_active_job_statuses())
  ) then
    raise exception 'Selesaikan dulu panggilan darurat yang sedang berjalan';
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

  if v_offer.expires_at < now() then
    raise exception 'Waktu tawaran sudah habis';
  end if;

  select * into v_request
  from public.sos_requests
  where id = v_offer.request_id
  for update;

  if v_request.status <> 'MENCARI_BENGKEL' then
    raise exception 'Panggilan sudah diambil bengkel lain';
  end if;

  update public.sos_offers set state = 'accepted' where id = p_offer_id;
  update public.sos_offers set state = 'taken'
  where request_id = v_offer.request_id and id <> p_offer_id and state = 'sent';

  update public.sos_requests
  set status = 'DITERIMA',
      accepted_workshop_id = v_workshop,
      accepted_at = now(),
      updated_at = now()
  where id = v_offer.request_id;

  update public.workshop_standby
  set accept_rate = least(1.0, accept_rate + 0.02), updated_at = now()
  where workshop_id = v_workshop;

  select w.name into v_name from public.workshops w where w.id = v_workshop;

  return jsonb_build_object(
    'request_id', v_offer.request_id,
    'workshop_id', v_workshop,
    'mechanic_name', v_name
  );
end$$;

-- ===========================================================================
-- RPC: lewati tawaran.
-- ===========================================================================

create or replace function public.sos_skip_offer(p_offer_id uuid)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_workshop uuid := public.sos_my_workshop_id();
begin
  update public.sos_offers
  set state = 'skipped'
  where id = p_offer_id and workshop_id = v_workshop and state = 'sent';

  if found then
    update public.workshop_standby
    set accept_rate = greatest(0.0, accept_rate - 0.02), updated_at = now()
    where workshop_id = v_workshop;
  end if;
end$$;

-- ===========================================================================
-- RPC: detail tawaran untuk layar ownerSosOffer (tanpa lokasi tepat).
-- ===========================================================================

create or replace function public.sos_offer_details(p_offer_id uuid)
returns jsonb
language plpgsql
stable
security definer set search_path = public, extensions
as $$
declare
  v_workshop uuid := public.sos_my_workshop_id();
  v_o public.sos_offers;
  v_r public.sos_requests;
  v_gross int;
begin
  select * into v_o from public.sos_offers where id = p_offer_id;
  if v_o is null or v_o.workshop_id is distinct from v_workshop then
    raise exception 'Tawaran tidak ditemukan';
  end if;

  select * into v_r from public.sos_requests where id = v_o.request_id;
  v_gross := v_r.call_fee + v_r.night_fee;

  return jsonb_build_object(
    'offer_id', v_o.id,
    'request_id', v_r.id,
    'request_code', v_r.code,
    'request_status', v_r.status,
    'state', v_o.state,
    'wave', v_o.wave,
    'distance_m', v_o.distance_m,
    'eta_min', v_o.eta_min,
    'sent_at', v_o.sent_at,
    'expires_at', v_o.expires_at,
    'problem_code', v_r.problem_code,
    'problem_note', v_r.problem_note,
    'photos', to_jsonb(v_r.photos),
    -- Area umum: dibulatkan ke kisi ±300 m (0,003°). PRD 3.8.
    'area_lat', round((v_r.lat / 0.003)::numeric) * 0.003,
    'area_lng', round((v_r.lng / 0.003)::numeric) * 0.003,
    'call_fee', v_r.call_fee,
    'night_fee', v_r.night_fee,
    'commission_rate', v_r.commission_rate,
    'net_earnings', round(v_gross * (1 - v_r.commission_rate))::int
  );
end$$;

-- ===========================================================================
-- RPC: mekanik memasukkan kode 4 digit dari pengendara → MEMERIKSA.
-- ===========================================================================

create or replace function public.sos_verify_arrival_code(
  p_request_id uuid,
  p_code text
)
returns boolean
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_workshop uuid := public.sos_my_workshop_id();
  v_r public.sos_requests;
begin
  select * into v_r
  from public.sos_requests
  where id = p_request_id and accepted_workshop_id = v_workshop
  for update;

  if v_r is null then
    raise exception 'Permintaan tidak ditemukan atau bukan milik bengkelmu';
  end if;

  if v_r.status = 'MEMERIKSA' then
    return true;  -- sudah dikonfirmasi (mis. oleh pengendara)
  end if;
  if v_r.status <> 'TIBA' then
    raise exception 'Kode hanya bisa dimasukkan setelah kamu tiba';
  end if;
  if v_r.arrival_code_attempts >= 5 then
    raise exception 'Terlalu banyak percobaan. Minta pengendara membacakan kode di aplikasinya';
  end if;

  if v_r.arrival_code is null or v_r.arrival_code <> trim(p_code) then
    update public.sos_requests
    set arrival_code_attempts = arrival_code_attempts + 1
    where id = p_request_id;
    return false;
  end if;

  update public.sos_requests
  set status = 'MEMERIKSA', updated_at = now()
  where id = p_request_id;
  return true;
end$$;

-- ===========================================================================
-- RPC: pengaturan siaga (ownerStandby). Syarat: bengkel DISETUJUI (PRD 3.3).
-- ===========================================================================

create or replace function public.sos_update_standby_settings(
  p_ready boolean,
  p_after_hours boolean,
  p_radius_tier_max int
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_w public.workshops;
  v_max_tier int;
  v_row public.workshop_standby;
begin
  select * into v_w from public.workshops
  where owner_id = auth.uid() order by created_at limit 1;
  if v_w is null then
    raise exception 'Kamu belum punya bengkel';
  end if;
  if p_ready and v_w.status <> 'verified' then
    raise exception 'Siaga darurat hanya untuk bengkel yang sudah disetujui';
  end if;
  if p_ready and v_w.location is null then
    raise exception 'Lengkapi lokasi bengkel dulu';
  end if;

  select max((elem->>'tier')::int) into v_max_tier
  from jsonb_array_elements(public.app_config_value('sos_tiers')) as elem;
  if p_radius_tier_max < 1 or p_radius_tier_max > coalesce(v_max_tier, 4) then
    raise exception 'Radius tidak valid';
  end if;

  insert into public.workshop_standby (workshop_id, emergency_ready, after_hours, radius_tier_max, updated_at)
  values (v_w.id, p_ready, p_after_hours, p_radius_tier_max, now())
  on conflict (workshop_id) do update
    set emergency_ready = excluded.emergency_ready,
        after_hours = excluded.after_hours,
        radius_tier_max = excluded.radius_tier_max,
        updated_at = now()
  returning * into v_row;

  return to_jsonb(v_row);
end$$;

-- ===========================================================================
-- quote_approve: penawaran yang disetujui saat TIBA/MEMERIKSA → DIKERJAKAN.
-- ===========================================================================

create or replace function public.quote_approve(p_quote_id uuid)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_quote public.quotes;
  v_booking public.bookings;
  v_sos public.sos_requests;
begin
  select * into v_quote from public.quotes where id = p_quote_id for update;
  if v_quote is null then
    raise exception 'Penawaran tidak ditemukan';
  end if;

  if v_quote.booking_id is not null then
    select * into v_booking from public.bookings where id = v_quote.booking_id;
    if v_booking is null or v_booking.rider_id <> auth.uid() then
      raise exception 'Tidak berhak menyetujui penawaran ini';
    end if;
  else
    select * into v_sos from public.sos_requests where id = v_quote.sos_request_id;
    if v_sos is null or v_sos.rider_id <> auth.uid() then
      raise exception 'Tidak berhak menyetujui penawaran ini';
    end if;
  end if;

  if v_quote.state <> 'sent' then
    raise exception 'Penawaran sudah ditangani';
  end if;

  if now() > v_quote.expires_at then
    -- Status 'expired' ditulis oleh quote_expire_stale (cron/dispatch).
    raise exception 'Penawaran sudah kedaluwarsa';
  end if;

  update public.quotes
  set state = 'approved', approved_at = now(), updated_at = now()
  where id = p_quote_id;

  if v_quote.sos_request_id is not null then
    update public.sos_requests
    set status = 'DIKERJAKAN', updated_at = now()
    where id = v_quote.sos_request_id and status in ('TIBA','MEMERIKSA');
  end if;
end$$;

-- ===========================================================================
-- RLS: bengkel yang hanya ditawari tidak membaca baris permintaan (lokasi tepat).
-- ===========================================================================

drop policy if exists sos_requests_workshop_read on public.sos_requests;
create policy sos_requests_workshop_read on public.sos_requests
  for select using (accepted_workshop_id = public.sos_my_workshop_id());

grant execute on function public.sos_skip_offer(uuid) to authenticated;
grant execute on function public.sos_offer_details(uuid) to authenticated;
grant execute on function public.sos_verify_arrival_code(uuid, text) to authenticated;
grant execute on function public.sos_update_standby_settings(boolean, boolean, int) to authenticated;
