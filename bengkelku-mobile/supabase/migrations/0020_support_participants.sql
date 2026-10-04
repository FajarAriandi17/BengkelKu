-- 0020_support_participants.sql — Pusat Bantuan (Fitur F, PRD v1.3 Bagian 7)
--
-- 1) support_create_ticket: sebelumnya hanya pengendara yang bisa melapor
--    atas booking/panggilan darurat/chat. PRD menaruh tombol "Laporkan
--    masalah" di chat untuk kedua pihak, jadi pemilik bengkel peserta juga
--    boleh melapor. Validasi panjang deskripsi dan jumlah foto di server.
-- 2) support_reply: balasan pengguna lewat RPC (cek status tiket & panjang).

create or replace function public.support_create_ticket(
  p_category support_category,
  p_description text,
  p_photos text[],
  p_booking_id uuid,
  p_sos_request_id uuid,
  p_thread_id uuid
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_user uuid := auth.uid();
  v_desc text := trim(coalesce(p_description, ''));
  v_ticket public.support_tickets;
begin
  if v_user is null then
    raise exception 'Belum login';
  end if;
  if char_length(v_desc) < 10 then
    raise exception 'Ceritakan masalahnya minimal 10 karakter';
  end if;
  if char_length(v_desc) > 1000 then
    raise exception 'Deskripsi maksimal 1.000 karakter';
  end if;
  if coalesce(array_length(p_photos, 1), 0) > 3 then
    raise exception 'Maksimal 3 foto';
  end if;

  -- Entitas terkait harus melibatkan pelapor (pengendara atau bengkel).
  if p_booking_id is not null and not exists (
    select 1 from public.bookings b
    where b.id = p_booking_id
      and (b.rider_id = v_user or public.is_workshop_owner(b.workshop_id))
  ) then
    raise exception 'Booking tidak ditemukan';
  end if;
  if p_sos_request_id is not null and not exists (
    select 1 from public.sos_requests r
    where r.id = p_sos_request_id
      and (r.rider_id = v_user
           or (r.accepted_workshop_id is not null and public.is_workshop_owner(r.accepted_workshop_id)))
  ) then
    raise exception 'Panggilan darurat tidak ditemukan';
  end if;
  if p_thread_id is not null and not public.is_chat_participant(p_thread_id) then
    raise exception 'Chat tidak ditemukan';
  end if;

  insert into public.support_tickets (
    code, user_id, category, description, photos,
    booking_id, sos_request_id, thread_id
  ) values (
    'TK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    v_user, p_category, v_desc, coalesce(p_photos, '{}'),
    p_booking_id, p_sos_request_id, p_thread_id
  )
  returning * into v_ticket;

  return to_jsonb(v_ticket);
end$$;

create or replace function public.support_reply(p_ticket_id uuid, p_body text)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_t public.support_tickets;
  v_body text := trim(coalesce(p_body, ''));
  v_msg public.support_messages;
begin
  select * into v_t from public.support_tickets
  where id = p_ticket_id and user_id = auth.uid();
  if v_t is null then
    raise exception 'Tiket tidak ditemukan';
  end if;
  if v_t.state = 'SELESAI' then
    raise exception 'Tiket sudah selesai. Buat laporan baru bila masih ada masalah';
  end if;
  if char_length(v_body) = 0 then
    raise exception 'Pesan tidak boleh kosong';
  end if;
  if char_length(v_body) > 1000 then
    raise exception 'Pesan maksimal 1.000 karakter';
  end if;

  insert into public.support_messages (ticket_id, sender_id, from_admin, body)
  values (p_ticket_id, auth.uid(), false, v_body)
  returning * into v_msg;   -- trigger 0019: MENUNGGU_INFO → DITINJAU

  return to_jsonb(v_msg);
end$$;

grant execute on function public.support_reply(uuid, text) to authenticated;
