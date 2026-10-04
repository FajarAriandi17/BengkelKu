-- 0023_booking_rpcs.sql — alur booking pengendara lewat RPC (harga & slot dihitung server)
--
-- Sebelumnya klien menulis langsung ke bookings/booking_items (harga & status
-- bisa dimanipulasi), slot tidak dicek, dan pembatalan tanpa refund.
-- Sekarang:
--   booking_available_slots(workshop, date)  → slot + sisa kuota
--   booking_create(workshop, vehicle, services[], scheduled_at, note) → harga server
--   booking_detail(booking) → detail lengkap (pengendara / pemilik)
--   booking_cancel(booking, reason) → refund 100% / 50% / 0% (PRD Bagian 7)
--   booking_sandbox_pay(booking) → HANYA bila app_config.payments_sandbox = true
--   booking_expire_unpaid() → cron: kedaluwarsakan booking belum dibayar

insert into public.app_config (key, value, label) values
  ('booking_payment_minutes', '60'::jsonb, 'Batas bayar booking (menit)'),
  ('booking_min_lead_minutes', '60'::jsonb, 'Minimal jarak pemesanan sebelum slot (menit)'),
  ('booking_max_days_ahead', '14'::jsonb, 'Maksimal hari ke depan untuk booking'),
  ('booking_default_open', '"08:00"'::jsonb, 'Jam buka bawaan bila bengkel belum atur jam'),
  ('booking_default_close', '"17:00"'::jsonb, 'Jam tutup bawaan bila bengkel belum atur jam'),
  ('payments_sandbox', 'true'::jsonb, 'Mode pembayaran sandbox (MATIKAN saat gateway produksi aktif)')
on conflict (key) do nothing;

drop policy if exists bookings_rider_insert on public.bookings;
drop policy if exists bookings_update on public.bookings;
drop policy if exists items_write on public.booking_items;

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
    if v_at >= now() + make_interval(mins => v_lead) then
      select count(*)::int into v_used from public.bookings b
      where b.workshop_id = p_workshop_id and b.scheduled_at = v_at
        and b.status not in ('KEDALUWARSA', 'DITOLAK', 'DIBATALKAN');
      slot_at := v_at;
      label := to_char(v_t, 'HH24:MI');
      remaining := greatest(v_capacity - v_used, 0);
      return next;
    end if;
    v_t := v_t + make_interval(mins => v_minutes);
    exit when v_t < v_open;
  end loop;
end$$;

create or replace function public.booking_create(
  p_workshop_id uuid, p_vehicle_id uuid, p_service_ids uuid[], p_scheduled_at timestamptz, p_note text default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_slot record;
  v_subtotal int;
  v_count int;
  v_fee int := coalesce((public.app_config_value('user_service_fee') #>> '{}')::int, 0);
  v_rate numeric := coalesce((public.app_config_value('commission_rate') #>> '{}')::numeric, 0.08);
  v_pay_min int := coalesce((public.app_config_value('booking_payment_minutes') #>> '{}')::int, 60);
  v_tz text;
  v_b public.bookings;
begin
  if v_uid is null then raise exception 'Silakan masuk terlebih dahulu'; end if;
  if p_service_ids is null or cardinality(p_service_ids) = 0 then raise exception 'Pilih minimal satu layanan'; end if;
  if p_vehicle_id is not null and not exists (
    select 1 from public.vehicles v where v.id = p_vehicle_id and v.user_id = v_uid) then
    raise exception 'Kendaraan tidak ditemukan';
  end if;
  if exists (select 1 from public.workshops w where w.id = p_workshop_id and w.owner_id = v_uid) then
    raise exception 'Tidak bisa memesan di bengkel sendiri';
  end if;
  select timezone into v_tz from public.workshops where id = p_workshop_id and status = 'verified';
  if v_tz is null then raise exception 'Bengkel tidak tersedia'; end if;

  perform pg_advisory_xact_lock(hashtext(p_workshop_id::text || p_scheduled_at::text));

  select * into v_slot
  from public.booking_available_slots(p_workshop_id, (p_scheduled_at at time zone v_tz)::date) s
  where s.slot_at = p_scheduled_at;
  if v_slot.slot_at is null then raise exception 'Slot tidak tersedia, pilih jadwal lain'; end if;
  if v_slot.remaining <= 0 then raise exception 'Slot sudah penuh, pilih jadwal lain'; end if;

  if exists (
    select 1 from public.bookings b
    where b.rider_id = v_uid and b.scheduled_at = p_scheduled_at
      and b.status in ('MENUNGGU_PEMBAYARAN','DIBAYAR_MENUNGGU_KONFIRMASI','DIKONFIRMASI','CHECK_IN','DIKERJAKAN')) then
    raise exception 'Kamu sudah punya booking di jam yang sama';
  end if;

  select count(*), coalesce(sum(s.price_idr), 0)::int into v_count, v_subtotal
  from public.services s where s.id = any(p_service_ids) and s.workshop_id = p_workshop_id and s.is_active;
  if v_count <> cardinality(array(select distinct unnest(p_service_ids))) then
    raise exception 'Ada layanan yang sudah tidak tersedia';
  end if;

  insert into public.bookings (rider_id, workshop_id, vehicle_id, status, scheduled_at,
    subtotal_idr, total_idr, commission_rate, payment_deadline)
  values (v_uid, p_workshop_id, p_vehicle_id, 'MENUNGGU_PEMBAYARAN', p_scheduled_at,
    v_subtotal, v_subtotal + v_fee, v_rate, now() + make_interval(mins => v_pay_min))
  returning * into v_b;

  insert into public.booking_items (booking_id, service_id, name, price_idr, is_addon)
  select v_b.id, s.id, s.name, s.price_idr, false
  from public.services s where s.id = any(p_service_ids) and s.workshop_id = p_workshop_id;

  return to_jsonb(v_b) || jsonb_build_object('service_fee', v_fee, 'note', nullif(trim(coalesce(p_note, '')), ''));
end$$;

create or replace function public.booking_detail(p_booking_id uuid)
returns jsonb
language sql stable security definer set search_path = public, extensions
as $$
  select to_jsonb(b) || jsonb_build_object(
    'workshop', jsonb_build_object('id', w.id, 'name', w.name, 'address', w.address, 'phone', w.phone),
    'vehicle', case when v.id is null then null else
      jsonb_build_object('id', v.id, 'brand', v.brand, 'model', v.model, 'plate', v.plate) end,
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'id', i.id, 'name', i.name, 'price_idr', i.price_idr, 'is_addon', i.is_addon,
        'addon_approved', i.addon_approved) order by i.created_at)
      from public.booking_items i where i.booking_id = b.id), '[]'::jsonb),
    'refund', (select jsonb_build_object('amount_idr', r.amount_idr, 'status', r.status, 'reason', r.reason)
      from public.refunds r where r.booking_id = b.id order by r.created_at desc limit 1),
    'is_rider', b.rider_id = auth.uid()
  )
  from public.bookings b
  join public.workshops w on w.id = b.workshop_id
  left join public.vehicles v on v.id = b.vehicle_id
  where b.id = p_booking_id and (b.rider_id = auth.uid() or public.is_workshop_owner(b.workshop_id))
$$;

create or replace function public.booking_cancel(p_booking_id uuid, p_reason text)
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_b public.bookings;
  v_pct numeric := 0;
  v_amount int := 0;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_owner uuid;
begin
  select * into v_b from public.bookings where id = p_booking_id for update;
  if v_b.id is null or v_b.rider_id <> auth.uid() then raise exception 'Booking tidak ditemukan'; end if;
  if v_reason is null or char_length(v_reason) < 3 then raise exception 'Alasan pembatalan wajib diisi'; end if;

  if v_b.status = 'MENUNGGU_PEMBAYARAN' then
    v_pct := 0;
  elsif v_b.status in ('DIBAYAR_MENUNGGU_KONFIRMASI', 'DIKONFIRMASI') then
    v_pct := case
      when v_b.status = 'DIBAYAR_MENUNGGU_KONFIRMASI' then 1
      when v_b.scheduled_at - now() >= interval '2 hours' then 1
      when v_b.scheduled_at > now() then 0.5
      else 0 end;
  else
    raise exception 'Booking dengan status % tidak bisa dibatalkan', v_b.status;
  end if;
  v_amount := round(v_b.total_idr * v_pct);

  update public.bookings set status = 'DIBATALKAN', cancel_reason = public.mask_sensitive(v_reason), updated_at = now()
  where id = p_booking_id returning * into v_b;

  if v_amount > 0 then
    insert into public.refunds (booking_id, amount_idr, reason, status)
    values (p_booking_id, v_amount, 'dibatalkan pengendara (' || (v_pct * 100)::int || '%)', 'processing');
  end if;

  select owner_id into v_owner from public.workshops where id = v_b.workshop_id;
  insert into public.notifications (user_id, kind, title, body, data)
  values (v_owner, 'booking', 'booking dibatalkan pengendara',
          to_char(v_b.scheduled_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI') || ' — ' || public.mask_sensitive(v_reason),
          jsonb_build_object('booking_id', p_booking_id, 'route', '/owner'));

  return jsonb_build_object('id', p_booking_id, 'status', v_b.status, 'refund_pct', v_pct, 'refund_idr', v_amount);
end$$;

create or replace function public.booking_sandbox_pay(p_booking_id uuid, p_method text default 'qris')
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_b public.bookings;
  v_owner uuid;
begin
  if coalesce((public.app_config_value('payments_sandbox') #>> '{}')::boolean, false) is not true then
    raise exception 'Pembayaran sandbox dinonaktifkan';
  end if;
  select * into v_b from public.bookings where id = p_booking_id for update;
  if v_b.id is null or v_b.rider_id <> auth.uid() then raise exception 'Booking tidak ditemukan'; end if;
  if v_b.status <> 'MENUNGGU_PEMBAYARAN' then return to_jsonb(v_b); end if;
  if v_b.payment_deadline is not null and v_b.payment_deadline < now() then
    update public.bookings set status = 'KEDALUWARSA', updated_at = now() where id = p_booking_id returning * into v_b;
    return to_jsonb(v_b);
  end if;

  insert into public.payments (booking_id, provider, provider_ref, method, amount_idr, status, paid_at)
  values (p_booking_id, 'sandbox', 'SBX-' || replace(gen_random_uuid()::text, '-', ''),
          coalesce(nullif(p_method, ''), 'qris'), v_b.total_idr, 'paid', now());

  update public.bookings set status = 'DIBAYAR_MENUNGGU_KONFIRMASI', updated_at = now()
  where id = p_booking_id returning * into v_b;

  select owner_id into v_owner from public.workshops where id = v_b.workshop_id;
  insert into public.notifications (user_id, kind, title, body, data)
  values (v_owner, 'booking', 'booking baru menunggu konfirmasi',
          to_char(v_b.scheduled_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI') || ' · Rp' || to_char(v_b.total_idr, 'FM999G999G999'),
          jsonb_build_object('booking_id', p_booking_id, 'route', '/owner'));
  return to_jsonb(v_b);
end$$;

create or replace function public.booking_expire_unpaid()
returns int
language sql security definer set search_path = public, extensions
as $$
  with x as (
    update public.bookings set status = 'KEDALUWARSA', updated_at = now()
    where status = 'MENUNGGU_PEMBAYARAN' and payment_deadline < now()
    returning 1
  ) select count(*)::int from x
$$;

grant execute on function public.booking_available_slots(uuid, date) to authenticated, anon;
grant execute on function public.booking_create(uuid, uuid, uuid[], timestamptz, text) to authenticated;
grant execute on function public.booking_detail(uuid) to authenticated;
grant execute on function public.booking_cancel(uuid, text) to authenticated;
grant execute on function public.booking_sandbox_pay(uuid, text) to authenticated;
revoke execute on function public.booking_expire_unpaid() from public, anon, authenticated;
