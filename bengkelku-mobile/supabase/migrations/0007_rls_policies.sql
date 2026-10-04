-- 0007_rls_policies.sql — Row Level Security di semua tabel
-- Prinsip: pengguna hanya akses barisnya; bengkel verified bisa dibaca publik.
-- Operasi keuangan (payments/payouts/refunds) dikelola service role (Edge Functions).

alter table public.users enable row level security;
alter table public.vehicles enable row level security;
alter table public.odometer_logs enable row level security;
alter table public.workshops enable row level security;
alter table public.workshop_documents enable row level security;
alter table public.workshop_hours enable row level security;
alter table public.workshop_slots_config enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_items enable row level security;
alter table public.payments enable row level security;
alter table public.refunds enable row level security;
alter table public.payouts enable row level security;
alter table public.service_records enable row level security;
alter table public.oil_reminders enable row level security;
alter table public.reviews enable row level security;
alter table public.favorites enable row level security;
alter table public.notifications enable row level security;

-- USERS: baca/ubah diri sendiri.
create policy users_self_select on public.users
  for select using (auth.uid() = id);
create policy users_self_update on public.users
  for update using (auth.uid() = id);

-- VEHICLES / ODOMETER: milik sendiri.
create policy vehicles_owner_all on public.vehicles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy odo_owner_all on public.odometer_logs
  for all using (exists (select 1 from public.vehicles v where v.id = vehicle_id and v.user_id = auth.uid()))
  with check (exists (select 1 from public.vehicles v where v.id = vehicle_id and v.user_id = auth.uid()));

-- WORKSHOPS: baca publik bila verified; owner kelola miliknya.
create policy workshops_public_read on public.workshops
  for select using (status = 'verified' or owner_id = auth.uid());
create policy workshops_owner_write on public.workshops
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Helper: apakah auth.uid() pemilik workshop tsb.
create or replace function public.is_workshop_owner(ws uuid)
returns boolean language sql stable as $$
  select exists (select 1 from public.workshops w where w.id = ws and w.owner_id = auth.uid());
$$;

-- DOKUMEN: hanya owner (tulis/baca); TIDAK ada baca publik. Admin pakai service role.
create policy docs_owner_all on public.workshop_documents
  for all using (public.is_workshop_owner(workshop_id))
  with check (public.is_workshop_owner(workshop_id));

-- JAM / SLOT / SERVICES: baca publik; tulis owner.
create policy hours_read on public.workshop_hours for select using (true);
create policy hours_write on public.workshop_hours
  for all using (public.is_workshop_owner(workshop_id)) with check (public.is_workshop_owner(workshop_id));
create policy slots_read on public.workshop_slots_config for select using (true);
create policy slots_write on public.workshop_slots_config
  for all using (public.is_workshop_owner(workshop_id)) with check (public.is_workshop_owner(workshop_id));
create policy services_read on public.services for select using (true);
create policy services_write on public.services
  for all using (public.is_workshop_owner(workshop_id)) with check (public.is_workshop_owner(workshop_id));

-- BOOKINGS: rider pemilik ATAU owner bengkelnya.
create policy bookings_access on public.bookings
  for select using (rider_id = auth.uid() or public.is_workshop_owner(workshop_id));
create policy bookings_rider_insert on public.bookings
  for insert with check (rider_id = auth.uid());
create policy bookings_update on public.bookings
  for update using (rider_id = auth.uid() or public.is_workshop_owner(workshop_id));

create policy items_access on public.booking_items
  for select using (exists (select 1 from public.bookings b where b.id = booking_id
     and (b.rider_id = auth.uid() or public.is_workshop_owner(b.workshop_id))));
create policy items_write on public.booking_items
  for all using (exists (select 1 from public.bookings b where b.id = booking_id
     and (b.rider_id = auth.uid() or public.is_workshop_owner(b.workshop_id))))
  with check (exists (select 1 from public.bookings b where b.id = booking_id
     and (b.rider_id = auth.uid() or public.is_workshop_owner(b.workshop_id))));

-- PEMBAYARAN/REFUND/PAYOUT: hanya baca pihak terkait; tulis via service role (bypass RLS).
create policy payments_read on public.payments
  for select using (exists (select 1 from public.bookings b where b.id = booking_id and b.rider_id = auth.uid()));
create policy refunds_read on public.refunds
  for select using (exists (select 1 from public.bookings b where b.id = booking_id and b.rider_id = auth.uid()));
create policy payouts_read on public.payouts
  for select using (public.is_workshop_owner(workshop_id));

-- SERVICE RECORDS: owner yang menginput; rider pemilik kendaraan boleh baca.
create policy records_access on public.service_records
  for select using (
    public.is_workshop_owner(workshop_id)
    or exists (select 1 from public.vehicles v where v.id = vehicle_id and v.user_id = auth.uid())
  );
create policy records_owner_write on public.service_records
  for insert with check (public.is_workshop_owner(workshop_id));

-- OIL REMINDERS: milik pemilik kendaraan.
create policy oil_owner_all on public.oil_reminders
  for all using (exists (select 1 from public.vehicles v where v.id = vehicle_id and v.user_id = auth.uid()))
  with check (exists (select 1 from public.vehicles v where v.id = vehicle_id and v.user_id = auth.uid()));

-- REVIEWS: baca publik; rider menulis utk booking selesai miliknya.
create policy reviews_read on public.reviews for select using (true);
create policy reviews_rider_write on public.reviews
  for insert with check (rider_id = auth.uid());

-- FAVORITES & NOTIFICATIONS: milik sendiri.
create policy favorites_all on public.favorites
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notif_read on public.notifications
  for select using (user_id = auth.uid());
create policy notif_update on public.notifications
  for update using (user_id = auth.uid());
