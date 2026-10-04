-- 0022_owner_bookings.sql — aksi booking sisi bengkel lewat RPC (dasbor owner)
--
-- Sebelumnya dasbor bengkel memakai data contoh dan policy bookings_update
-- mengizinkan pemilik mengubah status/total booking apa pun secara langsung.
-- Sekarang transisi status divalidasi server; penolakan memicu refund 100%
-- (dicatat di refunds; eksekusi dana oleh payment service) + notifikasi.

create or replace function public.owner_booking_action(
  p_booking_id uuid,
  p_action text,              -- confirm | reject | check_in | start | complete | no_show
  p_reason text default null
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_b public.bookings;
  v_next booking_status;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  select * into v_b from public.bookings where id = p_booking_id for update;
  if v_b.id is null or not public.is_workshop_owner(v_b.workshop_id) then
    raise exception 'Booking tidak ditemukan';
  end if;

  v_next := case
    when p_action = 'confirm'  and v_b.status = 'DIBAYAR_MENUNGGU_KONFIRMASI' then 'DIKONFIRMASI'
    when p_action = 'reject'   and v_b.status = 'DIBAYAR_MENUNGGU_KONFIRMASI' then 'DITOLAK'
    when p_action = 'check_in' and v_b.status = 'DIKONFIRMASI' then 'CHECK_IN'
    when p_action = 'start'    and v_b.status in ('DIKONFIRMASI','CHECK_IN') then 'DIKERJAKAN'
    when p_action = 'complete' and v_b.status in ('CHECK_IN','DIKERJAKAN') then 'SELESAI'
    when p_action = 'no_show'  and v_b.status = 'DIKONFIRMASI' and now() > v_b.scheduled_at + interval '30 minutes' then 'TIDAK_HADIR'
    else null
  end::booking_status;

  if v_next is null then
    raise exception 'Aksi % tidak bisa dilakukan pada status %', p_action, v_b.status;
  end if;
  if p_action = 'reject' and (v_reason is null or char_length(v_reason) < 5) then
    raise exception 'Alasan penolakan minimal 5 karakter';
  end if;

  update public.bookings
  set status = v_next,
      cancel_reason = case when p_action = 'reject' then public.mask_sensitive(v_reason) else cancel_reason end,
      updated_at = now()
  where id = p_booking_id
  returning * into v_b;

  if p_action = 'reject' then
    insert into public.refunds (booking_id, amount_idr, reason, status)
    values (p_booking_id, v_b.total_idr, 'ditolak bengkel: ' || public.mask_sensitive(v_reason), 'processing');
  end if;

  insert into public.notifications (user_id, kind, title, body, data)
  values (
    v_b.rider_id, 'booking',
    case v_next
      when 'DIKONFIRMASI' then 'booking kamu dikonfirmasi bengkel'
      when 'DITOLAK' then 'booking kamu ditolak bengkel'
      when 'CHECK_IN' then 'check-in berhasil'
      when 'DIKERJAKAN' then 'motor kamu sedang dikerjakan'
      when 'TIDAK_HADIR' then 'booking ditandai tidak hadir'
      when 'SELESAI' then 'servis selesai'
    end,
    case v_next
      when 'DITOLAK' then public.mask_sensitive(v_reason) || '. dana dikembalikan 100%.'
      when 'DIKONFIRMASI' then 'sampai jumpa sesuai jadwal. tunjukkan tiket saat tiba.'
      when 'SELESAI' then 'terima kasih! beri ulasan untuk bengkel ini.'
      else null
    end,
    jsonb_build_object('booking_id', p_booking_id, 'route', '/ticket?bookingId=' || p_booking_id)
  );

  return jsonb_build_object('id', v_b.id, 'status', v_b.status);
end$$;

-- Ringkasan dasbor bengkel (hari ini, zona waktu bengkel).
create or replace function public.owner_dashboard()
returns jsonb
language sql
stable
security definer set search_path = public, extensions
as $$
  with w as (
    select * from public.workshops where owner_id = auth.uid() order by created_at limit 1
  ), day as (
    select w.id, (now() at time zone w.timezone)::date as d, w.timezone as tz from w
  )
  select case when (select id from w) is null then null else jsonb_build_object(
    'workshop', (select jsonb_build_object('id', id, 'name', name, 'status', status,
                         'rating_avg', rating_avg, 'rating_count', rating_count) from w),
    'today_revenue', coalesce((
      select sum(round(b.total_idr * (1 - b.commission_rate)))::int
      from public.bookings b, day
      where b.workshop_id = day.id and b.status in ('SELESAI','PAYOUT')
        and (b.updated_at at time zone day.tz)::date = day.d
    ), 0),
    'waiting_confirmation', (
      select count(*) from public.bookings b, w
      where b.workshop_id = w.id and b.status = 'DIBAYAR_MENUNGGU_KONFIRMASI'),
    'today_count', (
      select count(*) from public.bookings b, day
      where b.workshop_id = day.id and (b.scheduled_at at time zone day.tz)::date = day.d
        and b.status not in ('MENUNGGU_PEMBAYARAN','KEDALUWARSA','DIBATALKAN','DITOLAK')),
    'queue', coalesce((
      select jsonb_agg(q order by q.scheduled_at) from (
        select b.id, b.status, b.scheduled_at, b.total_idr,
               u.full_name as rider_name,
               nullif(trim(coalesce(v.brand,'') || ' ' || coalesce(v.model,'')), '') as vehicle,
               (select string_agg(i.name, ', ') from public.booking_items i where i.booking_id = b.id) as services
        from public.bookings b
        join w on w.id = b.workshop_id
        left join public.users u on u.id = b.rider_id
        left join public.vehicles v on v.id = b.vehicle_id
        where b.status in ('DIBAYAR_MENUNGGU_KONFIRMASI','DIKONFIRMASI','CHECK_IN','DIKERJAKAN')
        order by b.scheduled_at
        limit 30
      ) q
    ), '[]'::jsonb)
  ) end
$$;

-- Pemilik tidak lagi mengubah booking langsung (status/total) — hanya via RPC.
drop policy if exists bookings_update on public.bookings;
create policy bookings_update on public.bookings
  for update using (rider_id = auth.uid())
  with check (rider_id = auth.uid());

grant execute on function public.owner_booking_action(uuid, text, text) to authenticated;
grant execute on function public.owner_dashboard() to authenticated;
