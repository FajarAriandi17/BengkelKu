-- 0105_admin_panel_rpcs.sql — RPC pendukung halaman panel admin
-- (peta verifikasi, pengguna, tim admin, payout, laporan). Semua security definer,
-- cek peran, dan menulis audit_logs untuk aksi yang mengubah data.

-- ---------------------------------------------------------------------------
-- Koordinat pin bengkel (geography → lat/lng) untuk halaman verifikasi.
-- ---------------------------------------------------------------------------
create or replace function public.admin_workshop_geo(p_workshop_id uuid)
returns jsonb
language sql
stable
security definer set search_path = public, extensions
as $$
  select case when not public.is_admin() then null else (
    select jsonb_build_object(
      'lat', st_y(w.location::geometry),
      'lng', st_x(w.location::geometry)
    )
    from public.workshops w
    where w.id = p_workshop_id and w.location is not null
  ) end
$$;

-- ---------------------------------------------------------------------------
-- Daftar pengguna + email (auth.users) + ringkasan aktivitas.
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_users(p_search text default null, p_limit int default 100)
returns table (
  id uuid, full_name text, email text, phone text, roles user_role[],
  created_at timestamptz, bookings int, sos int, workshops int
)
language sql
stable
security definer set search_path = public, extensions
as $$
  select u.id, u.full_name, au.email::text, u.phone, u.roles, u.created_at,
         (select count(*)::int from public.bookings b where b.rider_id = u.id),
         (select count(*)::int from public.sos_requests s where s.rider_id = u.id),
         (select count(*)::int from public.workshops w where w.owner_id = u.id)
  from public.users u
  left join auth.users au on au.id = u.id
  where public.is_admin()
    and (p_search is null or trim(p_search) = ''
         or u.full_name ilike '%' || trim(p_search) || '%'
         or au.email ilike '%' || trim(p_search) || '%'
         or u.phone ilike '%' || trim(p_search) || '%')
  order by u.created_at desc
  limit least(greatest(coalesce(p_limit, 100), 1), 500)
$$;

-- ---------------------------------------------------------------------------
-- Tim admin (super_admin): tambah akun yang sudah terdaftar di Auth, ubah peran,
-- aktif/nonaktifkan. Tidak bisa menonaktifkan/menurunkan diri sendiri.
-- ---------------------------------------------------------------------------
create or replace function public.admin_team_upsert(
  p_email text,
  p_role admin_role,
  p_full_name text default null
)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.has_admin_role('super_admin') then raise exception 'Hanya super admin'; end if;
  if v_email = '' then raise exception 'Email wajib diisi'; end if;

  select id into v_uid from auth.users where lower(email) = v_email limit 1;
  if v_uid is null then
    raise exception 'Akun % belum terdaftar. Undang dulu lewat Supabase Auth.', v_email;
  end if;
  if v_uid = auth.uid() and p_role <> 'super_admin' then
    raise exception 'Tidak bisa menurunkan peran diri sendiri';
  end if;

  insert into public.admin_users (id, email, full_name, role, is_active, invited_by)
  values (v_uid, v_email, nullif(trim(coalesce(p_full_name, '')), ''), p_role, true, auth.uid())
  on conflict (id) do update
    set role = excluded.role,
        full_name = coalesce(excluded.full_name, public.admin_users.full_name),
        is_active = true;

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), 'TEAM_UPSERT', 'admin_user', v_uid,
          jsonb_build_object('email', v_email, 'role', p_role));

  return jsonb_build_object('id', v_uid, 'email', v_email, 'role', p_role);
end$$;

create or replace function public.admin_team_set_active(p_admin_id uuid, p_active boolean)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  if not public.has_admin_role('super_admin') then raise exception 'Hanya super admin'; end if;
  if p_admin_id = auth.uid() and not p_active then
    raise exception 'Tidak bisa menonaktifkan diri sendiri';
  end if;
  update public.admin_users set is_active = p_active where id = p_admin_id;
  if not found then raise exception 'Admin tidak ditemukan'; end if;

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), case when p_active then 'TEAM_ACTIVATE' else 'TEAM_DEACTIVATE' end,
          'admin_user', p_admin_id, null);
end$$;

-- ---------------------------------------------------------------------------
-- Payout (finance): ubah status terjadwal → diproses → dibayar / gagal.
-- ---------------------------------------------------------------------------
create or replace function public.admin_payout_set_status(
  p_payout_id uuid,
  p_status payout_status,
  p_note text default null
)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_p public.payouts;
begin
  if not public.has_admin_role('finance') then raise exception 'Hanya admin finance'; end if;
  select * into v_p from public.payouts where id = p_payout_id for update;
  if v_p.id is null then raise exception 'Payout tidak ditemukan'; end if;
  if v_p.status = 'paid' then raise exception 'Payout sudah dibayar'; end if;
  if p_status = 'failed' and char_length(trim(coalesce(p_note, ''))) < 5 then
    raise exception 'Alasan gagal wajib diisi';
  end if;

  update public.payouts
  set status = p_status,
      paid_at = case when p_status = 'paid' then now() else paid_at end
  where id = p_payout_id;

  if p_status in ('paid', 'failed') then
    insert into public.notifications (user_id, kind, title, body, data)
    select w.owner_id, 'payout',
           case when p_status = 'paid' then 'dana servis sudah ditransfer'
                else 'pencairan dana tertunda' end,
           case when p_status = 'paid'
                then 'Rp' || to_char(v_p.net_idr, 'FM999G999G999') || ' masuk ke rekening terdaftar.'
                else trim(p_note) end,
           jsonb_build_object('payout_id', p_payout_id)
    from public.workshops w where w.id = v_p.workshop_id;
  end if;

  insert into public.audit_logs (actor_id, action, target_type, target_id, meta)
  values (auth.uid(), 'PAYOUT_' || upper(p_status::text), 'payout', p_payout_id,
          jsonb_build_object('from', v_p.status, 'note', p_note));
end$$;

-- ---------------------------------------------------------------------------
-- Laporan ringkas N hari terakhir (GMV, komisi, status booking/SOS, top bengkel).
-- ---------------------------------------------------------------------------
create or replace function public.admin_report_summary(p_days int default 30)
returns jsonb
language sql
stable
security definer set search_path = public, extensions
as $$
  with since as (select now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 365)) as t),
  b as (select * from public.bookings, since where created_at >= since.t),
  s as (select * from public.sos_requests, since where created_at >= since.t),
  done as (select * from b where status in ('SELESAI', 'PAYOUT'))
  select case when not public.is_admin() then null else jsonb_build_object(
    'days', least(greatest(coalesce(p_days, 30), 1), 365),
    'bookings_total', (select count(*) from b),
    'bookings_done', (select count(*) from done),
    'gmv_idr', (select coalesce(sum(total_idr), 0) from done),
    'commission_idr', (select coalesce(sum(round(total_idr * commission_rate)), 0) from done),
    'bookings_by_status', coalesce((select jsonb_object_agg(status, n)
        from (select status, count(*) n from b group by status) x), '{}'::jsonb),
    'sos_total', (select count(*) from s),
    'sos_done', (select count(*) from s where status in ('SELESAI', 'SELESAI_TANPA_PERBAIKAN')),
    'sos_no_workshop', (select count(*) from s where status = 'TIDAK_ADA_BENGKEL'),
    'sos_revenue_idr', (select coalesce(sum(total), 0) from s
                        where status in ('SELESAI', 'SELESAI_TANPA_PERBAIKAN')),
    'new_users', (select count(*) from public.users, since where users.created_at >= since.t),
    'new_workshops', (select count(*) from public.workshops, since where workshops.created_at >= since.t),
    'top_workshops', coalesce((select jsonb_agg(x order by x.gmv desc) from (
        select w.name, count(*) as bookings, sum(d.total_idr) as gmv
        from done d join public.workshops w on w.id = d.workshop_id
        group by w.name order by sum(d.total_idr) desc limit 5) x), '[]'::jsonb)
  ) end
$$;

grant execute on function public.admin_workshop_geo(uuid) to authenticated;
grant execute on function public.admin_list_users(text, int) to authenticated;
grant execute on function public.admin_team_upsert(text, admin_role, text) to authenticated;
grant execute on function public.admin_team_set_active(uuid, boolean) to authenticated;
grant execute on function public.admin_payout_set_status(uuid, payout_status, text) to authenticated;
grant execute on function public.admin_report_summary(int) to authenticated;
