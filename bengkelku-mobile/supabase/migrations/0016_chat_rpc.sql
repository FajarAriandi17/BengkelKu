-- 0016_chat_rpc.sql — melengkapi backend v1.3 yang belum ada:
--   1) Kolom lokasi pada chat_messages (kartu lokasi di thread darurat, PRD 2.1).
--   2) RPC `chat_send`   — kirim pesan (peserta + state open, idempoten, menyaring isi).
--   3) RPC `chat_mark_read` — reset penghitung belum dibaca + tandai read_at.
--   4) RPC `sos_mark_paid`  — MENUNGGU_PEMBAYARAN → MENCARI_BENGKEL setelah bayar
--                             (PRD 3.5; di produksi dipicu webhook gateway).
--   5) Trigger pembuatan thread chat otomatis:
--      - sos_requests → DITERIMA  : buat thread type 'sos' (PRD 2.1).
--      - bookings → DIBAYAR_MENUNGGU_KONFIRMASI : buat thread type 'booking' (PRD 2.1).

-- ===========================================================================
-- 1) Kolom lokasi pada chat_messages (kind = 'location').
-- ===========================================================================

alter table public.chat_messages
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

-- ===========================================================================
-- 2) RPC: chat_send — kirim satu pesan.
--    Validasi peserta + state open di server; idempoten via (thread_id, client_id).
--    Trigger DB (0011) tetap menyaring isi & memperbarui unread.
-- ===========================================================================

create or replace function public.chat_send(
  p_thread_id uuid,
  p_sender_id uuid,
  p_kind chat_message_kind,
  p_body text,
  p_media_paths text[],
  p_quote_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_client_id text
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_thread public.chat_threads;
  v_msg public.chat_messages;
begin
  if p_sender_id is null or p_sender_id <> auth.uid() then
    raise exception 'Pengirim tidak sesuai';
  end if;

  select * into v_thread from public.chat_threads where id = p_thread_id;
  if v_thread is null then
    raise exception 'Thread tidak ditemukan';
  end if;

  if not (v_thread.rider_id = p_sender_id
          or public.is_workshop_owner(v_thread.workshop_id)) then
    raise exception 'Bukan peserta chat';
  end if;

  if v_thread.state <> 'open' then
    raise exception 'Chat sudah ditutup';
  end if;

  insert into public.chat_messages (
    thread_id, sender_id, kind, body, media_paths, quote_id,
    latitude, longitude, client_id
  ) values (
    p_thread_id, p_sender_id, p_kind, p_body, coalesce(p_media_paths, '{}'),
    p_quote_id, p_latitude, p_longitude, p_client_id
  )
  on conflict (thread_id, client_id) do nothing
  returning * into v_msg;

  -- Idempotensi: bila sudah ada (retry offline), kembalikan baris yang ada.
  if v_msg is null then
    select * into v_msg
    from public.chat_messages
    where thread_id = p_thread_id and client_id = p_client_id;
  end if;

  return to_jsonb(v_msg);
end$$;

-- ===========================================================================
-- 3) RPC: chat_mark_read — tandai thread dibaca untuk pengguna tertentu.
-- ===========================================================================

create or replace function public.chat_mark_read(
  p_thread_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_thread public.chat_threads;
begin
  select * into v_thread from public.chat_threads where id = p_thread_id;
  if v_thread is null then
    return;
  end if;

  if v_thread.rider_id = p_user_id then
    update public.chat_threads
    set rider_unread = 0, updated_at = now()
    where id = p_thread_id;
  elsif public.is_workshop_owner(v_thread.workshop_id) then
    update public.chat_threads
    set workshop_unread = 0, updated_at = now()
    where id = p_thread_id;
  else
    return;  -- bukan peserta
  end if;

  update public.chat_messages
  set read_at = now()
  where thread_id = p_thread_id
    and sender_id <> p_user_id
    and read_at is null;
end$$;

-- ===========================================================================
-- 4) RPC: sos_mark_paid — setelah pembayaran biaya panggilan diterima.
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
    return to_jsonb(v_request);  -- sudah diproses / kedaluwarsa
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
  set status = 'MENCARI_BENGKEL', updated_at = now()
  where id = p_request_id
  returning * into v_request;

  return to_jsonb(v_request);
end$$;

-- ===========================================================================
-- 5) Trigger: buat thread chat otomatis.
-- ===========================================================================

-- 5a) Darurat: saat bengkel menerima (status → DITERIMA).
create or replace function public.sos_on_accepted_chat()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  if new.status = 'DITERIMA'
     and (old.status is distinct from 'DITERIMA')
     and new.accepted_workshop_id is not null then
    insert into public.chat_threads (type, sos_request_id, rider_id, workshop_id, state)
    select 'sos', new.id, new.rider_id, new.accepted_workshop_id, 'open'
    where not exists (
      select 1 from public.chat_threads t where t.sos_request_id = new.id
    );
  end if;
  return new;
end$$;

drop trigger if exists trg_sos_accepted_chat on public.sos_requests;
create trigger trg_sos_accepted_chat
  after update on public.sos_requests
  for each row execute function public.sos_on_accepted_chat();

-- 5b) Booking: saat pembayaran berhasil (status → DIBAYAR_MENUNGGU_KONFIRMASI).
create or replace function public.booking_on_paid_chat()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  if new.status = 'DIBAYAR_MENUNGGU_KONFIRMASI'
     and (old.status is distinct from 'DIBAYAR_MENUNGGU_KONFIRMASI') then
    insert into public.chat_threads (type, booking_id, rider_id, workshop_id, state)
    select 'booking', new.id, new.rider_id, new.workshop_id, 'open'
    where not exists (
      select 1 from public.chat_threads t where t.booking_id = new.id
    );
  end if;
  return new;
end$$;

drop trigger if exists trg_booking_paid_chat on public.bookings;
create trigger trg_booking_paid_chat
  after update on public.bookings
  for each row execute function public.booking_on_paid_chat();

-- Selesai: 0016_chat_rpc.sql
