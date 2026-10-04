-- 0017_sos_route.sql — RPC sisi bengkel yang belum ada di v1.3:
-- mekanik mulai bergerak (DITERIMA → MENUJU_LOKASI) dan simpan jejak lokasi
-- berkala (tiap 30 dtk; broadcast 5 dtk tetap lewat Realtime Broadcast).

create or replace function public.sos_start_route(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_workshop uuid;
begin
  select id into v_workshop
  from public.workshops where owner_id = auth.uid()
  order by created_at limit 1;

  update public.sos_requests
  set status = 'MENUJU_LOKASI', updated_at = now()
  where id = p_request_id
    and accepted_workshop_id = v_workshop
    and status = 'DITERIMA';

  if not found then
    raise exception 'Permintaan tidak bisa dimulai';
  end if;
end$$;

create or replace function public.sos_record_tracking(
  p_request_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_speed double precision default null,
  p_heading double precision default null
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_workshop uuid;
begin
  select id into v_workshop
  from public.workshops where owner_id = auth.uid()
  order by created_at limit 1;

  -- Lokasi mekanik hanya dicatat saat MENUJU_LOKASI/TIBA (PRD 3.8).
  if not exists (
    select 1 from public.sos_requests
    where id = p_request_id and accepted_workshop_id = v_workshop
      and status in ('MENUJU_LOKASI','TIBA')
  ) then
    raise exception 'Pelacakan tidak aktif';
  end if;

  insert into public.sos_tracking (request_id, workshop_id, lat, lng, speed, heading)
  values (p_request_id, v_workshop, p_lat, p_lng, p_speed, p_heading);
end$$;
