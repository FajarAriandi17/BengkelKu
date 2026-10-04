-- 0011_chat.sql — chat pengendara ↔ bengkel (Fitur A, PRD v1.3 Bagian 2)
-- Thread per booking & per panggilan darurat. Peserta tepat 2.
-- Penyaringan nomor telepon / tautan / email dilakukan trigger DB.

create type if not exists chat_thread_type as enum ('booking', 'sos');
create type if not exists chat_message_kind as enum ('text', 'image', 'system', 'quote', 'location');
create type if not exists chat_thread_state as enum ('open', 'readonly');
create type if not exists chat_report_state as enum ('open', 'reviewing', 'actioned', 'dismissed');

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  type chat_thread_type not null,
  booking_id uuid references public.bookings (id) on delete cascade,
  sos_request_id uuid,                                    -- FK ditambahkan di 0012 (circular-safe)
  rider_id uuid not null references public.users (id) on delete cascade,
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  state chat_thread_state not null default 'open',
  last_message_at timestamptz not null default now(),
  rider_unread int not null default 0,
  workshop_unread int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((type = 'booking' and booking_id is not null) or (type = 'sos' and sos_request_id is not null))
);
create index if not exists idx_chat_threads_rider on public.chat_threads (rider_id);
create index if not exists idx_chat_threads_workshop on public.chat_threads (workshop_id);
create index if not exists idx_chat_threads_last_msg on public.chat_threads (last_message_at desc);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  kind chat_message_kind not null default 'text',
  body text,                                              -- sudah disaring (nomor/tautan/email)
  media_paths text[] not null default '{}',               -- path di bucket chat-media (maks 3)
  quote_id uuid,                                          -- FK ke quotes ditambahkan di 0013
  client_id text not null,                                -- idempotensi pengiriman offline
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique (thread_id, client_id)
);
create index if not exists idx_chat_messages_thread on public.chat_messages (thread_id, created_at);
create index if not exists idx_chat_messages_sender on public.chat_messages (sender_id);

create table if not exists public.chat_reports (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  reporter_id uuid not null references public.users (id) on delete cascade,
  reason text not null,
  state chat_report_state not null default 'open',
  resolved_by uuid references public.users (id),
  created_at timestamptz not null default now()
);
create index if not exists idx_chat_reports_thread on public.chat_reports (thread_id);

-- ===========================================================================
-- Penyaringan: nomor telepon, tautan, alamat email → [disembunyikan]
-- (PRD 2.1; sama dengan catatan penolakan booking — mencegah transaksi luar).
-- ===========================================================================
create or replace function public.mask_sensitive(input text)
returns text language sql immutable as $$
  select
    regexp_replace(
      regexp_replace(
        regexp_replace(
          coalesce(input, ''),
          -- Alamat email.
          '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
          '[disembunyikan]', 'gi'),
        -- Tautan http/https dan www.
        '(https?://\S+|www\.[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\S*)',
        '[disembunyikan]', 'gi'),
      -- Nomor telepon Indonesia: 08..., +62..., 62..., 021/022 dll.
      '((\+62|62|08|02)[0-9]{1,13}([\s.\-]?[0-9]{1,13}){0,4})',
      '[disembunyikan]', 'gi')
$$;

create or replace function public.on_chat_message_insert()
returns trigger language plpgsql as $$
begin
  -- Pesan sistem/lokasi/penawaran tidak disaring (konten platform).
  if new.kind in ('text', 'image') and new.body is not null then
    new.body := public.mask_sensitive(new.body);
  end if;
  return new;
end$$;

drop trigger if exists trg_chat_message_mask on public.chat_messages;
create trigger trg_chat_message_mask
  before insert on public.chat_messages
  for each row execute function public.on_chat_message_insert();

-- Sentuh thread: perbarui last_message_at & penghitung belum dibaca.
create or replace function public.on_chat_message_touch()
returns trigger language plpgsql as $$
begin
  update public.chat_threads t
  set last_message_at = new.created_at,
      updated_at = now(),
      rider_unread = case when new.sender_id = t.rider_id then t.rider_unread else t.rider_unread + 1 end,
      workshop_unread = case when new.sender_id = t.workshop_id then t.workshop_unread else t.workshop_unread + 1 end
  where t.id = new.thread_id;
  return new;
end$$;

drop trigger if exists trg_chat_message_touch on public.chat_messages;
create trigger trg_chat_message_touch
  after insert on public.chat_messages
  for each row execute function public.on_chat_message_touch();

-- ===========================================================================
-- RLS: thread & pesan hanya peserta. Sisipkan pesan hanya bila state = open.
-- ===========================================================================
alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_reports enable row level security;

-- Helper: apakah auth.uid() peserta thread.
create or replace function public.is_chat_participant(thread uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.chat_threads t
    where t.id = thread
      and (t.rider_id = auth.uid()
           or public.is_workshop_owner(t.workshop_id))
  );
$$;

create policy chat_threads_read on public.chat_threads
  for select using (auth.uid() = rider_id or public.is_workshop_owner(workshop_id));

create policy chat_threads_update on public.chat_threads
  for update using (auth.uid() = rider_id or public.is_workshop_owner(workshop_id));

create policy chat_messages_read on public.chat_messages
  for select using (public.is_chat_participant(thread_id));

create policy chat_messages_insert on public.chat_messages
  for insert with check (
    public.is_chat_participant(thread_id)
    and sender_id = auth.uid()
    and exists (
      select 1 from public.chat_threads t
      where t.id = thread_id and t.state = 'open'
    )
  );

create policy chat_messages_update_read on public.chat_messages
  for update using (public.is_chat_participant(thread_id));

create policy chat_reports_write on public.chat_reports
  for insert with check (reporter_id = auth.uid() and public.is_chat_participant(thread_id));
create policy chat_reports_read on public.chat_reports
  for select using (reporter_id = auth.uid());

-- Realtime: publikasikan perubahan pesan (difilter thread_id di klien).
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.chat_threads;
