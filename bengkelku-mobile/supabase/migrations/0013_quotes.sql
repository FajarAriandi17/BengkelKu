-- 0013_quotes.sql — penawaran biaya perbaikan (Fitur C, PRD v1.3 Bagian 4)
--
-- Bengkel mengajukan setelah status TIBA (darurat) atau DIKERJAKAN (booking).
-- Pengendara Setujui+bayar atau Tolak. Tanpa persetujuan bengkel tidak boleh
-- mengerjakan tambahan; total tidak bisa naik tanpa penawaran baru.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'quote_state') then
    create type quote_state as enum (
  'sent', 'approved', 'rejected', 'expired', 'superseded'
);
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'quote_item_type') then
    create type quote_item_type as enum ('jasa', 'sparepart');
  end if;
end $$;

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings (id) on delete cascade,
  sos_request_id uuid references public.sos_requests (id) on delete cascade,
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  items jsonb not null default '[]',              -- [{name, type, price}]
  note text,
  photos text[] not null default '{}',            -- path di bucket quote-photos
  total int not null default 0,
  state quote_state not null default 'sent',
  expires_at timestamptz not null,
  revision int not null default 0,
  approved_at timestamptz,
  rejected_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((booking_id is not null) or (sos_request_id is not null)),
  check (total >= 0),
  check (jsonb_array_length(items) between
         coalesce((public.app_config_value('quote_min_items') #>> '{}')::int, 1)
         and coalesce((public.app_config_value('quote_max_items') #>> '{}')::int, 10))
);
create index if not exists idx_quotes_booking on public.quotes (booking_id, created_at desc);
create index if not exists idx_quotes_sos on public.quotes (sos_request_id, created_at desc);
create index if not exists idx_quotes_workshop on public.quotes (workshop_id, state);

-- ===========================================================================
-- Helper: total dari items jsonb (validasi server, jangan percaya klien).
-- ===========================================================================

create or replace function public.quote_items_total(items jsonb)
returns int language sql immutable as $$
  select coalesce(sum((elem->>'price')::int), 0)
  from jsonb_array_elements(items) as elem
$$;

-- ===========================================================================
-- RPC: buat penawaran (sisi bengkel).
-- ===========================================================================

create or replace function public.quote_create(
  p_booking_id uuid,
  p_sos_request_id uuid,
  p_items jsonb,
  p_note text,
  p_photos text[]
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_workshop uuid;
  v_max_total int;
  v_max_items int;
  v_min_items int;
  v_max_revisions int;
  v_emergency_min int;
  v_booking_min int;
  v_total int;
  v_expires timestamptz;
  v_booking public.bookings;
  v_sos public.sos_requests;
  v_active int;
  v_quote public.quotes;
begin
  select id into v_workshop
  from public.workshops where owner_id = auth.uid()
  order by created_at limit 1;
  if v_workshop is null then
    raise exception 'Kamu bukan pemilik bengkel';
  end if;

  if (p_booking_id is null and p_sos_request_id is null)
     or (p_booking_id is not null and p_sos_request_id is not null) then
    raise exception 'Penawaran harus untuk satu booking ATAU satu panggilan darurat';
  end if;

  v_max_total := coalesce((public.app_config_value('quote_max_total') #>> '{}')::int, 2000000);
  v_max_items := coalesce((public.app_config_value('quote_max_items') #>> '{}')::int, 10);
  v_min_items := coalesce((public.app_config_value('quote_min_items') #>> '{}')::int, 1);
  v_max_revisions := coalesce((public.app_config_value('quote_max_revisions') #>> '{}')::int, 2);
  v_emergency_min := coalesce((public.app_config_value('quote_emergency_minutes') #>> '{}')::int, 10);
  v_booking_min := coalesce((public.app_config_value('quote_booking_minutes') #>> '{}')::int, 30);

  -- Validasi items.
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < v_min_items then
    raise exception 'Minimal % butir penawaran', v_min_items;
  end if;
  if jsonb_array_length(p_items) > v_max_items then
    raise exception 'Maksimal % butir penawaran', v_max_items;
  end if;

  v_total := public.quote_items_total(p_items);
  if v_total <= 0 then
    raise exception 'Total penawaran harus lebih dari 0';
  end if;
  if v_total > v_max_total then
    raise exception 'Total melebihi batas Rp % — gunakan booking biasa', v_max_total;
  end if;

  if p_booking_id is not null then
    select * into v_booking from public.bookings where id = p_booking_id;
    if v_booking is null or v_booking.workshop_id <> v_workshop then
      raise exception 'Booking tidak ditemukan atau bukan milik bengkelmu';
    end if;
    -- Harus sudah DIKERJAKAN (menggantikan FR-P8 tambahan pekerjaan).
    if v_booking.status not in ('DIKERJAKAN') then
      raise exception 'Penawaran hanya bisa diajukan saat pekerjaan sedang dikerjakan';
    end if;
    v_expires := now() + (v_booking_min || ' minutes')::interval;
  else
    select * into v_sos from public.sos_requests where id = p_sos_request_id;
    if v_sos is null or v_sos.accepted_workshop_id <> v_workshop then
      raise exception 'Panggilan darurat tidak ditemukan atau bukan milik bengkelmu';
    end if;
    -- Harus sudah TIBA.
    if v_sos.status not in ('TIBA','MEMERIKSA') then
      raise exception 'Penawaran darurat hanya bisa diajukan setelah mekanik tiba';
    end if;
    v_expires := now() + (v_emergency_min || ' minutes')::interval;
  end if;

  -- Maksimal revisi: penawaran aktif sebelumnya di-superseded.
  select count(*) into v_active
  from public.quotes
  where (booking_id = p_booking_id or sos_request_id = p_sos_request_id)
    and state in ('sent','approved');
  if v_active >= v_max_revisions + 1 then
    raise exception 'Batas revisi penawaran tercapai';
  end if;

  -- Penawaran lama yang masih sent menjadi superseded.
  update public.quotes
  set state = 'superseded', updated_at = now()
  where (booking_id = p_booking_id or sos_request_id = p_sos_request_id)
    and state = 'sent';

  insert into public.quotes (
    booking_id, sos_request_id, workshop_id, items, note, photos,
    total, state, expires_at, revision
  ) values (
    p_booking_id, p_sos_request_id, v_workshop, p_items, p_note, coalesce(p_photos, '{}'),
    v_total, 'sent', v_expires, v_active + 1
  )
  returning * into v_quote;

  return to_jsonb(v_quote);
end$$;

-- ===========================================================================
-- RPC: pengendara menyetujui + membayar.
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
  select * into v_quote
  from public.quotes
  where id = p_quote_id
  for update;

  if v_quote is null then
    raise exception 'Penawaran tidak ditemukan';
  end if;

  -- Pengendara adalah rider dari booking/sos terkait.
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
    update public.quotes set state = 'expired', updated_at = now() where id = p_quote_id;
    raise exception 'Penawaran sudah kedaluwarsa';
  end if;

  update public.quotes
  set state = 'approved', approved_at = now(), updated_at = now()
  where id = p_quote_id;

  -- Status lanjutan: booking tetap DIKERJAKAN; sos → DIKERJAKAN.
  if v_quote.sos_request_id is not null then
    update public.sos_requests
    set status = 'DIKERJAKAN', updated_at = now()
    where id = v_quote.sos_request_id and status = 'MEMERIKSA';
  end if;
end$$;

-- ===========================================================================
-- RPC: pengendara menolak.
-- ===========================================================================

create or replace function public.quote_reject(
  p_quote_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_quote public.quotes;
  v_booking public.bookings;
  v_sos public.sos_requests;
begin
  select * into v_quote
  from public.quotes
  where id = p_quote_id
  for update;

  if v_quote is null then
    raise exception 'Penawaran tidak ditemukan';
  end if;

  if v_quote.booking_id is not null then
    select * into v_booking from public.bookings where id = v_quote.booking_id;
    if v_booking is null or v_booking.rider_id <> auth.uid() then
      raise exception 'Tidak berhak menolak penawaran ini';
    end if;
  else
    select * into v_sos from public.sos_requests where id = v_quote.sos_request_id;
    if v_sos is null or v_sos.rider_id <> auth.uid() then
      raise exception 'Tidak berhak menolak penawaran ini';
    end if;
  end if;

  if v_quote.state <> 'sent' then
    raise exception 'Penawaran sudah ditangani';
  end if;

  update public.quotes
  set state = 'rejected', rejected_reason = p_reason, updated_at = now()
  where id = p_quote_id;

  -- SOS: selesai tanpa perbaikan (biaya panggilan tetap berlaku).
  if v_quote.sos_request_id is not null then
    update public.sos_requests
    set status = 'SELESAI_TANPA_PERBAIKAN',
        ended_reason = 'quote_rejected',
        updated_at = now()
    where id = v_quote.sos_request_id and status in ('TIBA','MEMERIKSA');
  end if;
end$$;

-- ===========================================================================
-- Kedaluwarsaan otomatis (dipanggil cron / dispatch wave).
-- ===========================================================================

create or replace function public.quote_expire_stale()
returns void language sql security definer set search_path = public, extensions as $$
  update public.quotes
  set state = 'expired', updated_at = now()
  where state = 'sent' and expires_at < now();
$$;

-- ===========================================================================
-- Trigger: updated_at + FK ke chat.
-- ===========================================================================

create or replace function public.quote_touch_updated()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end$$;

drop trigger if exists trg_quotes_touch on public.quotes;
create trigger trg_quotes_touch
  before update on public.quotes
  for each row execute function public.quote_touch_updated();

-- FK yang ditunda dari 0011_chat.sql (circular-safe).
alter table public.chat_threads
  add constraint fk_chat_threads_sos foreign key (sos_request_id)
  references public.sos_requests (id) on delete cascade;

alter table public.chat_messages
  add constraint fk_chat_messages_quote foreign key (quote_id)
  references public.quotes (id) on delete set null;

-- ===========================================================================
-- RLS
-- ===========================================================================

alter table public.quotes enable row level security;

-- Rider membaca penawaran untuk booking/sos miliknya.
create policy quotes_rider_read on public.quotes
  for select using (
    booking_id in (select id from public.bookings where rider_id = auth.uid())
    or sos_request_id in (select id from public.sos_requests where rider_id = auth.uid())
  );

-- Bengkel membaca penawaran miliknya.
create policy quotes_workshop_read on public.quotes
  for select using (
    workshop_id = (select id from public.workshops where owner_id = auth.uid())
  );

-- Tidak ada insert/update langsung dari klien — semua lewat RPC.

alter publication supabase_realtime add table public.quotes;
