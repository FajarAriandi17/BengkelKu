-- 0021_workshop_verification_flow.sql — alur verifikasi bengkel app ↔ admin web
--
-- Masalah sebelumnya:
--   * Aplikasi menyimpan bengkel baru dengan status 'draft'; antrean admin
--     memfilter 'pending' → pendaftaran TIDAK PERNAH muncul di admin.
--   * Pemilik bisa mengubah kolom status sendiri lewat policy
--     workshops_owner_write (mis. menyetel 'verified' tanpa admin).
--   * Tidak ada jalur ajukan ulang setelah ditolak.
--   * Rating ulasan tidak pernah tersimpan (trigger terkena RLS).
--
-- Perbaikan:
--   1) Trigger guard: hanya admin/service role yang mengubah status & rating.
--      Pemilik hanya draft|rejected → pending lewat workshop_submit_verification.
--   2) RPC pemilik: workshop_register, workshop_submit_verification, workshop_my_status.
--   3) RPC admin: admin_verify_workshop (atomik + audit + notifikasi + peran owner),
--      admin_set_workshop_status (tangguhkan / aktifkan kembali).
--   4) notifications_mark_all_read; notifikasi lewat Realtime.

alter table public.workshops
  add column if not exists submitted_at timestamptz,
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid,
  add column if not exists submission_count int not null default 0;

-- Fallback is_admin() bila migrasi admin web (0100) belum dipasang.
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'is_admin' and pronamespace = 'public'::regnamespace) then
    execute 'create function public.is_admin() returns boolean language sql stable as $b$ select false $b$';
  end if;
end $$;

-- ===========================================================================
-- 1) Guard kolom sensitif
-- ===========================================================================

create or replace function public.workshops_guard_status()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_privileged boolean :=
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    or coalesce(auth.uid()::text, '') = ''
    or public.is_admin()
    or coalesce(current_setting('bengkelku.allow_status_change', true), '') = 'on';
begin
  if v_privileged then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status not in ('draft', 'pending') then
      new.status := 'draft';
    end if;
    new.rejected_reason := null;
    new.rating_avg := 0;
    new.rating_count := 0;
    new.verified_at := null;
    new.verified_by := null;
    return new;
  end if;

  if new.status is distinct from old.status then
    raise exception 'Status bengkel hanya bisa diubah oleh admin';
  end if;
  new.rejected_reason := old.rejected_reason;
  new.rating_avg := old.rating_avg;
  new.rating_count := old.rating_count;
  new.verified_at := old.verified_at;
  new.verified_by := old.verified_by;
  new.submitted_at := old.submitted_at;
  new.submission_count := old.submission_count;
  return new;
end$$;

drop trigger if exists trg_workshops_guard on public.workshops;
create trigger trg_workshops_guard
  before insert or update on public.workshops
  for each row execute function public.workshops_guard_status();

-- ===========================================================================
-- 2) RPC pemilik
-- ===========================================================================

create or replace function public.workshop_register(
  p_name text,
  p_address text,
  p_phone text,
  p_lat double precision,
  p_lng double precision,
  p_description text default null
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_ws public.workshops;
begin
  if v_uid is null then
    raise exception 'Belum login';
  end if;
  if char_length(trim(coalesce(p_name, ''))) < 3 then
    raise exception 'Nama bengkel minimal 3 karakter';
  end if;
  if char_length(trim(coalesce(p_address, ''))) < 10 then
    raise exception 'Alamat terlalu pendek';
  end if;
  if p_lat is null or p_lng is null
     or p_lat not between -11.5 and 6.5 or p_lng not between 94.5 and 141.5 then
    raise exception 'Lokasi bengkel harus di Indonesia';
  end if;

  select * into v_ws from public.workshops
  where owner_id = v_uid order by created_at limit 1;

  if v_ws.id is null then
    insert into public.workshops (owner_id, name, address, phone, description, location, status)
    values (v_uid, trim(p_name), trim(p_address), nullif(trim(coalesce(p_phone, '')), ''),
            nullif(trim(coalesce(p_description, '')), ''),
            extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography, 'draft')
    returning * into v_ws;
  else
    if v_ws.status = 'pending' then
      raise exception 'Pendaftaran sedang ditinjau admin';
    end if;
    if v_ws.status = 'suspended' then
      raise exception 'Bengkel ditangguhkan. Hubungi pusat bantuan';
    end if;
    update public.workshops
    set name = trim(p_name), address = trim(p_address),
        phone = nullif(trim(coalesce(p_phone, '')), ''),
        description = coalesce(nullif(trim(coalesce(p_description, '')), ''), description),
        location = extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
        updated_at = now()
    where id = v_ws.id
    returning * into v_ws;
  end if;

  return jsonb_build_object('id', v_ws.id, 'status', v_ws.status);
end$$;

create or replace function public.workshop_submit_verification(p_workshop_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_ws public.workshops;
  v_missing text[];
begin
  select * into v_ws from public.workshops
  where id = p_workshop_id and owner_id = auth.uid()
  for update;
  if v_ws.id is null then
    raise exception 'Bengkel tidak ditemukan';
  end if;
  if v_ws.status not in ('draft', 'rejected') then
    raise exception 'Bengkel tidak bisa diajukan pada status ini';
  end if;

  select array_agg(t::text) into v_missing
  from unnest(array['ktp','selfie','location']::doc_type[]) as t
  where not exists (
    select 1 from public.workshop_documents d
    where d.workshop_id = p_workshop_id and d.type = t and d.status = 'pending'
  );
  if v_missing is not null then
    raise exception 'Dokumen belum lengkap: %', array_to_string(v_missing, ', ');
  end if;

  perform set_config('bengkelku.allow_status_change', 'on', true);
  update public.workshops
  set status = 'pending', rejected_reason = null,
      submitted_at = now(), submission_count = submission_count + 1,
      updated_at = now()
  where id = p_workshop_id
  returning * into v_ws;
  perform set_config('bengkelku.allow_status_change', '', true);

  return jsonb_build_object('id', v_ws.id, 'status', v_ws.status, 'submitted_at', v_ws.submitted_at);
end$$;

create or replace function public.workshop_my_status()
returns jsonb
language sql
stable
security definer set search_path = public, extensions
as $$
  select jsonb_build_object(
    'id', w.id,
    'name', w.name,
    'address', w.address,
    'phone', w.phone,
    'description', w.description,
    'status', w.status,
    'rejected_reason', w.rejected_reason,
    'submitted_at', w.submitted_at,
    'verified_at', w.verified_at,
    'submission_count', w.submission_count,
    'lat', extensions.st_y(w.location::extensions.geometry),
    'lng', extensions.st_x(w.location::extensions.geometry),
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object('type', d.type, 'status', d.status, 'created_at', d.created_at)
                       order by d.created_at desc)
      from public.workshop_documents d where d.workshop_id = w.id
    ), '[]'::jsonb)
  )
  from public.workshops w
  where w.owner_id = auth.uid()
  order by w.created_at
  limit 1
$$;

-- ===========================================================================
-- 3) RPC admin
-- ===========================================================================

create or replace function public.admin_verify_workshop(
  p_workshop_id uuid,
  p_decision text,
  p_reason_code text default null,
  p_note text default null,
  p_checklist jsonb default null
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_admin uuid := auth.uid();
  v_ws public.workshops;
  v_reason text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin';
  end if;
  if p_decision not in ('approve', 'reject') then
    raise exception 'Keputusan tidak valid';
  end if;

  select * into v_ws from public.workshops where id = p_workshop_id for update;
  if v_ws.id is null then
    raise exception 'Bengkel tidak ditemukan';
  end if;
  if v_ws.status <> 'pending' then
    raise exception 'Bengkel tidak dalam antrean verifikasi (status: %)', v_ws.status;
  end if;

  if p_decision = 'reject' then
    v_reason := coalesce(nullif(trim(coalesce(p_note, '')), ''), p_reason_code);
    if v_reason is null then
      raise exception 'Alasan penolakan wajib diisi';
    end if;
  end if;

  update public.workshops
  set status = (case when p_decision = 'approve' then 'verified' else 'rejected' end)::workshop_status,
      rejected_reason = case when p_decision = 'reject' then v_reason end,
      verified_at = case when p_decision = 'approve' then now() end,
      verified_by = case when p_decision = 'approve' then v_admin end,
      updated_at = now()
  where id = p_workshop_id
  returning * into v_ws;

  update public.workshop_documents
  set status = (case when p_decision = 'approve' then 'approved' else 'rejected' end)::doc_status
  where workshop_id = p_workshop_id and status = 'pending';

  if p_decision = 'approve' then
    update public.users
    set roles = (select array_agg(distinct r) from unnest(roles || array['owner']::user_role[]) r),
        updated_at = now()
    where id = v_ws.owner_id;
  end if;

  if to_regclass('public.audit_logs') is not null then
    execute 'insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
             values ($1, $2, ''workshop'', $3, $4)'
    using v_admin,
          case when p_decision = 'approve' then 'APPROVE_WORKSHOP' else 'REJECT_WORKSHOP' end,
          p_workshop_id,
          jsonb_build_object('checklist', p_checklist, 'reason_code', p_reason_code, 'note', p_note);
  end if;

  insert into public.notifications (user_id, kind, title, body, data)
  values (
    v_ws.owner_id, 'verification',
    case when p_decision = 'approve'
         then 'selamat! bengkel kamu sudah tayang di BengkelKu'
         else 'pendaftaran bengkel kamu belum disetujui' end,
    case when p_decision = 'approve'
         then 'pelanggan kini bisa menemukan dan memesan servis di bengkelmu.'
         else v_reason || '. perbaiki data lalu ajukan ulang dari aplikasi.' end,
    jsonb_build_object('workshop_id', p_workshop_id, 'route', '/owner/status')
  );

  return jsonb_build_object('id', v_ws.id, 'status', v_ws.status);
end$$;

create or replace function public.admin_set_workshop_status(
  p_workshop_id uuid,
  p_status workshop_status,
  p_reason text
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_ws public.workshops;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin';
  end if;
  if p_status not in ('verified', 'suspended') then
    raise exception 'Gunakan admin_verify_workshop untuk antrean verifikasi';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) < 5 then
    raise exception 'Alasan wajib diisi';
  end if;

  update public.workshops
  set status = p_status,
      rejected_reason = case when p_status = 'suspended' then trim(p_reason) end,
      updated_at = now()
  where id = p_workshop_id and status in ('verified', 'suspended')
  returning * into v_ws;
  if v_ws.id is null then
    raise exception 'Bengkel tidak ditemukan atau belum disetujui';
  end if;

  if p_status = 'suspended' then
    update public.workshop_standby set emergency_ready = false, updated_at = now()
    where workshop_id = p_workshop_id;
  end if;

  if to_regclass('public.audit_logs') is not null then
    execute 'insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
             values ($1, $2, ''workshop'', $3, $4)'
    using auth.uid(),
          case when p_status = 'suspended' then 'SUSPEND_WORKSHOP' else 'REACTIVATE_WORKSHOP' end,
          p_workshop_id, jsonb_build_object('reason', p_reason);
  end if;

  insert into public.notifications (user_id, kind, title, body, data)
  values (v_ws.owner_id, 'verification',
          case when p_status = 'suspended' then 'bengkel kamu ditangguhkan sementara'
               else 'bengkel kamu aktif kembali' end,
          trim(p_reason), jsonb_build_object('workshop_id', p_workshop_id));

  return jsonb_build_object('id', v_ws.id, 'status', v_ws.status);
end$$;

-- ===========================================================================
-- 4) Notifikasi & rating
-- ===========================================================================

create or replace function public.notifications_mark_all_read()
returns int
language sql
security definer set search_path = public, extensions
as $$
  with u as (
    update public.notifications set read_at = now()
    where user_id = auth.uid() and read_at is null
    returning 1
  ) select count(*)::int from u
$$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- Rating: trigger lama berjalan sebagai pengulas → UPDATE workshops diblokir RLS.
create or replace function public.refresh_workshop_rating()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_ws uuid := coalesce(new.workshop_id, old.workshop_id);
begin
  perform set_config('bengkelku.allow_status_change', 'on', true);
  update public.workshops w
  set rating_avg = coalesce((select round(avg(rating)::numeric, 1) from public.reviews r where r.workshop_id = w.id), 0),
      rating_count = (select count(*) from public.reviews r where r.workshop_id = w.id)
  where w.id = v_ws;
  perform set_config('bengkelku.allow_status_change', '', true);
  return coalesce(new, old);
end$$;

drop trigger if exists on_review_created on public.reviews;
create trigger on_review_created
  after insert or update or delete on public.reviews
  for each row execute function public.refresh_workshop_rating();

grant execute on function public.workshop_register(text, text, text, double precision, double precision, text) to authenticated;
grant execute on function public.workshop_submit_verification(uuid) to authenticated;
grant execute on function public.workshop_my_status() to authenticated;
grant execute on function public.admin_verify_workshop(uuid, text, text, text, jsonb) to authenticated;
grant execute on function public.admin_set_workshop_status(uuid, workshop_status, text) to authenticated;
grant execute on function public.notifications_mark_all_read() to authenticated;
