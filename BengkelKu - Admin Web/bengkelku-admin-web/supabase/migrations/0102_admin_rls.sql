-- 0102_admin_rls.sql — RLS untuk tabel admin + akses admin lintas data mobile
-- Admin membaca data mobile untuk verifikasi/moderasi/keuangan; tulis sensitif
-- lebih baik lewat service role (Edge Function/Route Handler) + audit.

alter table public.admin_users enable row level security;
alter table public.audit_logs enable row level security;

-- admin_users: admin bisa lihat daftar; hanya super_admin yang kelola.
create policy admin_users_read on public.admin_users
  for select using (public.is_admin());
create policy admin_users_manage on public.admin_users
  for all using (public.has_admin_role('super_admin'))
  with check (public.has_admin_role('super_admin'));

-- audit_logs: admin baca; sisipan umumnya lewat service role.
create policy audit_read on public.audit_logs
  for select using (public.is_admin());
create policy audit_insert on public.audit_logs
  for insert with check (public.is_admin());

-- Perluas akses admin ke data mobile (SELECT) untuk keperluan panel.
-- (INSERT/UPDATE sensitif tetap via service role di server.)
create policy admin_read_workshops on public.workshops
  for select using (public.is_admin());
create policy admin_update_workshops on public.workshops
  for update using (public.has_admin_role('verifikator'));

create policy admin_read_documents on public.workshop_documents
  for select using (public.has_admin_role('verifikator'));

create policy admin_read_bookings on public.bookings
  for select using (public.is_admin());
create policy admin_read_payments on public.payments
  for select using (public.has_admin_role('finance'));
create policy admin_read_payouts on public.payouts
  for select using (public.has_admin_role('finance'));
create policy admin_read_reviews on public.reviews
  for select using (public.is_admin());
create policy admin_read_users on public.users
  for select using (public.is_admin());
