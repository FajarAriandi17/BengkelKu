-- 0104_admin_v13_ops.sql — operasi admin v1.3 (PRD v1.3 Bagian 10)
-- Semua aksi admin lewat RPC security definer: cek peran + audit_logs.

-- ---------------------------------------------------------------------------
-- Tiket bantuan (Fitur F)
-- ---------------------------------------------------------------------------

create or replace function public.admin_ticket_reply(
  p_ticket_id uuid,
  p_body text,
  p_new_state support_state default null
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_t public.support_tickets;
  v_state support_state;
begin
  if not public.has_admin_role('cs') then raise exception 'Hanya admin CS'; end if;
  if char_length(trim(coalesce(p_body, ''))) = 0 then raise exception 'Pesan kosong'; end if;

  select * into v_t from public.support_tickets where id = p_ticket_id for update;
  if v_t.id is null then raise exception 'Tiket tidak ditemukan'; end if;
  if v_t.state = 'SELESAI' then raise exception 'Tiket sudah selesai'; end if;
  if p_new_state = 'SELESAI' then raise exception 'Gunakan admin_ticket_resolve'; end if;

  v_state := coalesce(p_new_state,
    case when v_t.state = 'DITERIMA' then 'DITINJAU'::support_state else v_t.state end);

  insert into public.support_messages (ticket_id, sender_id, from_admin, body)
  values (p_ticket_id, auth.uid(), true, trim(p_body));

  update public.support_tickets set state = v_state, updated_at = now() where id = p_ticket_id;

  insert into public.notifications (user_id, kind, title, body, data)
  values (v_t.user_id, 'support',
          case when v_state = 'MENUNGGU_INFO' then 'tim bantuan butuh info tambahan'
               else 'balasan baru untuk laporanmu' end,
          left(trim(p_body), 140),
          jsonb_build_object('ticket_id', p_ticket_id, 'route', '/help/tickets/' || p_ticket_id));

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), 'TICKET_REPLY', 'support_ticket', p_ticket_id, jsonb_build_object('state', v_state));

  return jsonb_build_object('id', p_ticket_id, 'state', v_state);
end$$;

create or replace function public.admin_ticket_resolve(
  p_ticket_id uuid,
  p_decision text,
  p_reason text
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_t public.support_tickets;
begin
  if not public.has_admin_role('cs') then raise exception 'Hanya admin CS'; end if;
  if char_length(trim(coalesce(p_decision, ''))) = 0
     or char_length(trim(coalesce(p_reason, ''))) < 5 then
    raise exception 'Keputusan dan alasan wajib diisi';
  end if;

  update public.support_tickets
  set state = 'SELESAI', decision = trim(p_decision), decision_reason = trim(p_reason), updated_at = now()
  where id = p_ticket_id and state <> 'SELESAI'
  returning * into v_t;
  if v_t.id is null then raise exception 'Tiket tidak ditemukan atau sudah selesai'; end if;

  insert into public.notifications (user_id, kind, title, body, data)
  values (v_t.user_id, 'support', 'laporan ' || v_t.code || ' selesai',
          trim(p_decision) || ' — ' || trim(p_reason),
          jsonb_build_object('ticket_id', p_ticket_id, 'route', '/help/tickets/' || p_ticket_id));

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), 'TICKET_RESOLVE', 'support_ticket', p_ticket_id,
          jsonb_build_object('decision', p_decision, 'reason', p_reason));

  return jsonb_build_object('id', p_ticket_id, 'state', 'SELESAI');
end$$;

-- ---------------------------------------------------------------------------
-- Laporan chat (moderasi). Membaca thread terlapor tercatat di audit.
-- ---------------------------------------------------------------------------

create or replace function public.admin_chat_report_thread(p_report_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_r public.chat_reports;
begin
  if not public.has_admin_role('cs') then raise exception 'Hanya admin CS'; end if;
  select * into v_r from public.chat_reports where id = p_report_id;
  if v_r.id is null then raise exception 'Laporan tidak ditemukan'; end if;

  update public.chat_reports set state = 'reviewing' where id = p_report_id and state = 'open';

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), 'VIEW_REPORTED_CHAT', 'chat_thread', v_r.thread_id,
          jsonb_build_object('report_id', p_report_id));

  return jsonb_build_object(
    'report', to_jsonb(v_r),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id, 'kind', m.kind, 'body', m.body, 'created_at', m.created_at,
        'role', case when m.sender_id = t.rider_id then 'pengendara' else 'bengkel' end
      ) order by m.created_at)
      from public.chat_messages m join public.chat_threads t on t.id = m.thread_id
      where m.thread_id = v_r.thread_id
    ), '[]'::jsonb)
  );
end$$;

create or replace function public.admin_chat_report_resolve(
  p_report_id uuid,
  p_action text,
  p_note text default null,
  p_close_thread boolean default false
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_r public.chat_reports;
begin
  if not public.has_admin_role('cs') then raise exception 'Hanya admin CS'; end if;
  if p_action not in ('actioned', 'dismissed') then raise exception 'Aksi tidak valid'; end if;

  update public.chat_reports set state = p_action::chat_report_state
  where id = p_report_id
  returning * into v_r;
  if v_r.id is null then raise exception 'Laporan tidak ditemukan'; end if;

  if p_close_thread then
    update public.chat_threads set state = 'readonly' where id = v_r.thread_id;
  end if;

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), 'CHAT_REPORT_' || upper(p_action), 'chat_thread', v_r.thread_id,
          jsonb_build_object('report_id', p_report_id, 'note', p_note, 'closed', p_close_thread));
end$$;

-- ---------------------------------------------------------------------------
-- Pemantauan darurat aktif (status, bengkel, usia; > 3 menit tanpa penerima).
-- ---------------------------------------------------------------------------

create or replace function public.admin_sos_live()
returns table (
  id uuid, code text, status sos_status, problem_code sos_problem,
  tier int, wave int, total int, created_at timestamptz, updated_at timestamptz,
  age_seconds int, workshop_name text, offers_sent int, needs_attention boolean
)
language sql
stable
security definer set search_path = public, extensions
as $$
  select r.id, r.code, r.status, r.problem_code, r.tier, r.wave, r.total,
         r.created_at, r.updated_at,
         extract(epoch from now() - r.created_at)::int,
         w.name,
         (select count(*)::int from public.sos_offers o where o.request_id = r.id),
         (r.status = 'MENCARI_BENGKEL' and now() - r.created_at > interval '3 minutes')
  from public.sos_requests r
  left join public.workshops w on w.id = r.accepted_workshop_id
  where public.is_admin()
    and r.status in ('MENUNGGU_PEMBAYARAN','MENCARI_BENGKEL','DITERIMA','MENUJU_LOKASI','TIBA','MEMERIKSA','DIKERJAKAN')
  order by r.created_at asc
$$;

create or replace function public.admin_dashboard_stats()
returns jsonb
language sql
stable
security definer set search_path = public, extensions
as $$
  select case when not public.is_admin() then null else jsonb_build_object(
    'pending_workshops', (select count(*) from public.workshops where status = 'pending'),
    'verified_workshops', (select count(*) from public.workshops where status = 'verified'),
    'suspended_workshops', (select count(*) from public.workshops where status = 'suspended'),
    'users', (select count(*) from public.users),
    'bookings_today', (select count(*) from public.bookings where created_at >= date_trunc('day', now())),
    'sos_active', (select count(*) from public.sos_requests
                   where status in ('MENCARI_BENGKEL','DITERIMA','MENUJU_LOKASI','TIBA','MEMERIKSA','DIKERJAKAN')),
    'sos_unanswered', (select count(*) from public.sos_requests
                       where status = 'MENCARI_BENGKEL' and now() - created_at > interval '3 minutes'),
    'standby_ready', (select count(*) from public.workshop_standby
                      where emergency_ready and last_seen_at > now() - interval '60 seconds'),
    'tickets_open', (select count(*) from public.support_tickets where state <> 'SELESAI'),
    'chat_reports_open', (select count(*) from public.chat_reports where state in ('open','reviewing'))
  ) end
$$;

-- ---------------------------------------------------------------------------
-- Konfigurasi (super_admin): ubah app_config dengan validasi tipe + audit.
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_config(p_key text, p_value jsonb)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_old jsonb;
begin
  if not public.has_admin_role('super_admin') then raise exception 'Hanya super admin'; end if;
  select value into v_old from public.app_config where key = p_key;
  if v_old is null then raise exception 'Kunci konfigurasi tidak dikenal'; end if;
  if jsonb_typeof(v_old) <> jsonb_typeof(p_value) then
    raise exception 'Tipe nilai harus % (bukan %)', jsonb_typeof(v_old), jsonb_typeof(p_value);
  end if;
  if p_key = 'commission_rate'
     and ((p_value #>> '{}')::numeric < 0 or (p_value #>> '{}')::numeric > 0.5) then
    raise exception 'Komisi harus antara 0 dan 0,5';
  end if;

  update public.app_config set value = p_value, updated_at = now() where key = p_key;

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), 'SET_CONFIG', 'app_config', null,
          jsonb_build_object('key', p_key, 'old', v_old, 'new', p_value));
end$$;

grant execute on function public.admin_ticket_reply(uuid, text, support_state) to authenticated;
grant execute on function public.admin_ticket_resolve(uuid, text, text) to authenticated;
grant execute on function public.admin_chat_report_thread(uuid) to authenticated;
grant execute on function public.admin_chat_report_resolve(uuid, text, text, boolean) to authenticated;
grant execute on function public.admin_sos_live() to authenticated;
grant execute on function public.admin_dashboard_stats() to authenticated;
grant execute on function public.admin_set_config(text, jsonb) to authenticated;
