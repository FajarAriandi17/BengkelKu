-- 0014_support.sql — pusat bantuan & laporan masalah (Fitur F, PRD v1.3 Bagian 7)

do $$
begin
  if not exists (select 1 from pg_type where typname = 'support_state') then
    create type support_state as enum (
  'DITERIMA', 'DITINJAU', 'MENUNGGU_INFO', 'SELESAI'
);
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'support_category') then
    create type support_category as enum (
  'BENGKEL_TIDAK_DATANG',
  'HARGA_TIDAK_SESUAI',
  'KERUSAKAN_SETELAH_SERVIS',
  'REFUND_BELUM_MASUK',
  'PERILAKU_TIDAK_PANTAS',
  'LAINNYA'
);
  end if;
end $$;

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,                        -- kode tampilan, mis. TK-AB12CD
  user_id uuid not null references public.users (id) on delete cascade,
  category support_category not null,
  description text not null check (char_length(description) <= 1000),
  photos text[] not null default '{}',              -- path di bucket support-photos
  state support_state not null default 'DITERIMA',
  booking_id uuid references public.bookings (id) on delete set null,
  sos_request_id uuid references public.sos_requests (id) on delete set null,
  thread_id uuid references public.chat_threads (id) on delete set null,
  decision text,
  decision_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_support_tickets_user on public.support_tickets (user_id, created_at desc);
create index if not exists idx_support_tickets_state on public.support_tickets (state);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  from_admin boolean not null default false,
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_support_messages_ticket on public.support_messages (ticket_id, created_at);

-- ===========================================================================
-- FAQ statis dikelola admin di app_config.
-- ===========================================================================

insert into public.app_config (key, value, label) values
  ('support_faq', '[
    {"q":"Bagaimana cara memesan servis di BengkelKu?","a":"Pilih bengkel di Beranda atau Peta, tentukan jadwal, lalu bayar di aplikasi. Kamu akan menerima tiket booking."},
    {"q":"Berapa lama pemrosesan refund?","a":"Refund diproses 1×24 jam kerja setelah disetujui. Dana kembali ke metode pembayaran yang dipakai."},
    {"q":"Bagaimana jika bengkel tidak datang untuk panggilan darurat?","a":"Jika mekanik tidak muncul melebihi ETA, kamu dapat refund penuh secara otomatis. Hubungi kami bila belum masuk."},
    {"q":"Apakah perbaikan di tempat bisa dibayar tunai?","a":"Semua pembayaran di aplikasi demi keamanan harga. Tidak ada tunai di MVP."},
    {"q":"Bagaimana cara melaporkan masalah?","a":"Tekan tombol Laporkan masalah di detail booking, panggilan darurat, atau chat. Tim kami merespons ≤ 1×24 jam kerja."}
  ]'::jsonb, 'FAQ pusat bantuan'),
  ('support_sla_hours', '24'::jsonb, 'SLA balasan pertama (jam kerja)')
on conflict (key) do update set value = excluded.value, label = excluded.label;

-- ===========================================================================
-- RPC: buat tiket (validasi kepemilikan entitas terkait).
-- ===========================================================================

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
  v_ticket public.support_tickets;
begin
  if v_user is null then
    raise exception 'Belum login';
  end if;

  -- Entitas terkait harus milik user (cegah laporan atas nama orang lain).
  if p_booking_id is not null
     and not exists (select 1 from public.bookings where id = p_booking_id and rider_id = v_user) then
    raise exception 'Booking tidak ditemukan';
  end if;
  if p_sos_request_id is not null
     and not exists (select 1 from public.sos_requests where id = p_sos_request_id and rider_id = v_user) then
    raise exception 'Panggilan darurat tidak ditemukan';
  end if;
  if p_thread_id is not null
     and not exists (select 1 from public.chat_threads where id = p_thread_id and rider_id = v_user) then
    raise exception 'Chat tidak ditemukan';
  end if;

  insert into public.support_tickets (
    code, user_id, category, description, photos,
    booking_id, sos_request_id, thread_id
  ) values (
    'TK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    v_user, p_category, p_description, coalesce(p_photos, '{}'),
    p_booking_id, p_sos_request_id, p_thread_id
  )
  returning * into v_ticket;

  return to_jsonb(v_ticket);
end$$;

-- ===========================================================================
-- Trigger: updated_at.
-- ===========================================================================

create or replace function public.support_touch_updated()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end$$;

drop trigger if exists trg_support_tickets_touch on public.support_tickets;
create trigger trg_support_tickets_touch
  before update on public.support_tickets
  for each row execute function public.support_touch_updated();

-- ===========================================================================
-- RLS: user hanya melihat tiketnya sendiri.
-- ===========================================================================

alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;

create policy tickets_user_read on public.support_tickets
  for select using (user_id = auth.uid());

create policy tickets_user_insert on public.support_tickets
  for insert with check (user_id = auth.uid());

create policy messages_user_read on public.support_messages
  for select using (
    ticket_id in (select id from public.support_tickets where user_id = auth.uid())
  );

create policy messages_user_insert on public.support_messages
  for insert with check (
    sender_id = auth.uid()
    and ticket_id in (select id from public.support_tickets where user_id = auth.uid())
  );

alter publication supabase_realtime add table public.support_tickets;
alter publication supabase_realtime add table public.support_messages;
