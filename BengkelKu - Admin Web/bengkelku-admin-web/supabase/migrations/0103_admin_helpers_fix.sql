-- 0103_admin_helpers_fix.sql
--
-- is_admin()/has_admin_role() membaca admin_users, sementara policy
-- admin_users_read memanggil is_admin() → rekursi RLS tak berujung
-- ("stack depth limit exceeded") untuk setiap query admin. Jadikan
-- SECURITY DEFINER agar pembacaan di dalam helper tidak terkena RLS.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.admin_users a
    where a.id = auth.uid() and a.is_active
  );
$$;

create or replace function public.has_admin_role(r admin_role)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.admin_users a
    where a.id = auth.uid() and a.is_active
      and (a.role = r or a.role = 'super_admin')
  );
$$;

-- Profil admin saat ini (dipakai admin web untuk guard & menu per peran).
create or replace function public.admin_me()
returns jsonb
language sql
stable
security definer set search_path = public
as $$
  select jsonb_build_object('id', a.id, 'email', a.email, 'full_name', a.full_name,
                            'role', a.role, 'totp_enabled', a.totp_enabled)
  from public.admin_users a
  where a.id = auth.uid() and a.is_active
$$;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.has_admin_role(admin_role) to authenticated;
grant execute on function public.admin_me() to authenticated;

-- Admin membaca data v1.3 untuk pemantauan & moderasi.
drop policy if exists admin_read_sos on public.sos_requests;
create policy admin_read_sos on public.sos_requests for select using (public.is_admin());
drop policy if exists admin_read_sos_offers on public.sos_offers;
create policy admin_read_sos_offers on public.sos_offers for select using (public.is_admin());
drop policy if exists admin_read_quotes on public.quotes;
create policy admin_read_quotes on public.quotes for select using (public.is_admin());
drop policy if exists admin_read_tickets on public.support_tickets;
create policy admin_read_tickets on public.support_tickets for select using (public.has_admin_role('cs'));
drop policy if exists admin_read_ticket_msgs on public.support_messages;
create policy admin_read_ticket_msgs on public.support_messages for select using (public.has_admin_role('cs'));
drop policy if exists admin_read_chat_reports on public.chat_reports;
create policy admin_read_chat_reports on public.chat_reports for select using (public.has_admin_role('cs'));
drop policy if exists admin_read_standby on public.workshop_standby;
create policy admin_read_standby on public.workshop_standby for select using (public.is_admin());
drop policy if exists admin_read_services on public.services;
create policy admin_read_services on public.services for select using (public.is_admin());

-- Pembaruan langsung workshops oleh admin dilarang: wajib lewat RPC (audit).
drop policy if exists admin_update_workshops on public.workshops;
