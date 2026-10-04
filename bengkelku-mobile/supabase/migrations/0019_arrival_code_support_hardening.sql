-- 0019_arrival_code_support_hardening.sql
--
-- 1) Kode kedatangan 4 digit (PRD 3.8 "Orang lain mengaku mekanik"):
--    sebelumnya kode disimpan di sos_requests.arrival_code — kolom itu bisa
--    dibaca bengkel penerima lewat RLS, dan sos_mark_arrived mengembalikan
--    kode ke mekanik. Artinya mekanik tidak perlu bertanya ke pengendara dan
--    kode tidak membuktikan apa pun.
--    Sekarang kode disimpan di tabel terpisah yang HANYA bisa dibaca
--    pengendara pemilik permintaan. Mekanik memasukkan kode yang dibacakan
--    pengendara lewat sos_verify_arrival_code().
--
-- 2) Pusat bantuan (PRD 7): klien tidak boleh menyisipkan pesan sebagai admin
--    (from_admin = true) atau membuat tiket tanpa validasi RPC.
--    Balasan pengguna saat MENUNGGU_INFO mengembalikan tiket ke DITINJAU.

-- ===========================================================================
-- 1) Kode kedatangan
-- ===========================================================================

create table if not exists public.sos_arrival_codes (
  request_id uuid primary key references public.sos_requests (id) on delete cascade,
  code text not null check (code ~ '^[0-9]{4}$'),
  created_at timestamptz not null default now()
);

alter table public.sos_arrival_codes enable row level security;

drop policy if exists sos_arrival_codes_rider_read on public.sos_arrival_codes;
create policy sos_arrival_codes_rider_read on public.sos_arrival_codes
  for select using (
    request_id in (select id from public.sos_requests where rider_id = auth.uid())
  );

-- Pindahkan kode lama (bila ada) lalu kosongkan kolom yang terbaca bengkel.
insert into public.sos_arrival_codes (request_id, code)
select id, arrival_code from public.sos_requests
where arrival_code ~ '^[0-9]{4}$'
on conflict (request_id) do nothing;

update public.sos_requests set arrival_code = null where arrival_code is not null;

comment on column public.sos_requests.arrival_code is
  'TIDAK DIPAKAI sejak 0019 — kode ada di sos_arrival_codes (hanya pengendara).';

-- Mekanik tiba: buat kode, JANGAN kembalikan ke mekanik.
create or replace function public.sos_mark_arrived(p_request_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_request public.sos_requests;
  v_workshop uuid := public.sos_my_workshop_id();
begin
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

  insert into public.sos_arrival_codes (request_id, code)
  values (p_request_id, lpad(floor(random() * 10000)::int::text, 4, '0'))
  on conflict (request_id) do update set code = excluded.code, created_at = now();

  update public.sos_requests
  set status = 'TIBA', arrived_at = now(), arrival_code = null,
      arrival_code_attempts = 0, updated_at = now()
  where id = p_request_id
  returning * into v_request;

  return jsonb_build_object('status', v_request.status, 'arrived_at', v_request.arrived_at);
end$$;

-- Pengendara membaca kodenya sendiri (ditampilkan di ArrivalCodeCard).
create or replace function public.sos_rider_arrival_code(p_request_id uuid)
returns text
language sql
stable
security definer set search_path = public, extensions
as $$
  select c.code
  from public.sos_arrival_codes c
  join public.sos_requests r on r.id = c.request_id
  where c.request_id = p_request_id and r.rider_id = auth.uid()
$$;

-- Mekanik memasukkan kode yang dibacakan pengendara → MEMERIKSA.
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
  v_code text;
begin
  select * into v_r
  from public.sos_requests
  where id = p_request_id and accepted_workshop_id = v_workshop
  for update;

  if v_r is null then
    raise exception 'Permintaan tidak ditemukan atau bukan milik bengkelmu';
  end if;

  if v_r.status = 'MEMERIKSA' then
    return true;
  end if;
  if v_r.status <> 'TIBA' then
    raise exception 'Kode hanya bisa dimasukkan setelah kamu tiba';
  end if;
  if v_r.arrival_code_attempts >= 5 then
    raise exception 'Terlalu banyak percobaan. Minta pengendara membacakan kode di aplikasinya';
  end if;

  select code into v_code from public.sos_arrival_codes where request_id = p_request_id;

  if v_code is null or v_code <> trim(coalesce(p_code, '')) then
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

-- Konfirmasi dari sisi pengendara (cadangan): pakai tabel kode yang sama.
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
  v_code text;
begin
  select * into v_request
  from public.sos_requests
  where id = p_request_id and rider_id = auth.uid()
  for update;

  if v_request is null then
    raise exception 'Permintaan tidak ditemukan';
  end if;

  select code into v_code from public.sos_arrival_codes where request_id = p_request_id;
  if v_code is null or v_code <> trim(coalesce(p_code, '')) then
    return false;
  end if;

  if v_request.status = 'TIBA' then
    update public.sos_requests
    set status = 'MEMERIKSA', updated_at = now()
    where id = p_request_id;
  end if;

  return true;
end$$;

grant execute on function public.sos_rider_arrival_code(uuid) to authenticated;

-- ===========================================================================
-- Bengkel: daftar tawaran aktif miliknya (layar ownerStandby / dasbor).
-- ===========================================================================

create or replace function public.sos_my_open_offers()
returns setof public.sos_offers
language sql
stable
security definer set search_path = public, extensions
as $$
  select o.*
  from public.sos_offers o
  join public.sos_requests r on r.id = o.request_id
  where o.workshop_id = public.sos_my_workshop_id()
    and o.state = 'sent'
    and o.expires_at > now()
    and r.status = 'MENCARI_BENGKEL'
  order by o.sent_at desc
$$;

grant execute on function public.sos_my_open_offers() to authenticated;

-- ===========================================================================
-- 2) Pusat bantuan
-- ===========================================================================

-- Tiket hanya dibuat lewat support_create_ticket (validasi kepemilikan).
drop policy if exists tickets_user_insert on public.support_tickets;

-- Pesan pengguna tidak boleh mengaku admin & tiket harus belum SELESAI.
drop policy if exists messages_user_insert on public.support_messages;
create policy messages_user_insert on public.support_messages
  for insert with check (
    sender_id = auth.uid()
    and from_admin = false
    and ticket_id in (
      select id from public.support_tickets
      where user_id = auth.uid() and state <> 'SELESAI'
    )
  );

-- Balasan pengguna saat MENUNGGU_INFO → kembali DITINJAU.
create or replace function public.support_on_user_message()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  if not new.from_admin then
    update public.support_tickets
    set state = 'DITINJAU', updated_at = now()
    where id = new.ticket_id and state = 'MENUNGGU_INFO';
  end if;
  return new;
end$$;

drop trigger if exists trg_support_user_message on public.support_messages;
create trigger trg_support_user_message
  after insert on public.support_messages
  for each row execute function public.support_on_user_message();
