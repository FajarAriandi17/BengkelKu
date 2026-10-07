-- Uji alur pembayaran Mayar (0025): intent, idempotensi, webhook mark, escrow.
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

create or replace function pg_temp.assert(ok boolean, msg text) returns void
language plpgsql as $$ begin
  if ok is not true then raise exception 'GAGAL: %', msg; end if;
  raise notice 'ok - %', msg;
end $$;
create or replace function pg_temp.as_user(uid text) returns void
language sql as $$ select set_config('request.jwt.claim.sub', uid, false) $$;
create or replace function pg_temp.fails(q text, pat text) returns boolean
language plpgsql as $$ begin
  execute q; return false;
exception when others then
  if sqlerrm like pat then return true; end if;
  raise notice 'pesan tak terduga: %', sqlerrm; return false;
end $$;

grant usage on schema public, extensions, auth to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

insert into auth.users(id,email) values
  ('00000000-0000-0000-0000-0000000000b1','owner@x'),
  ('00000000-0000-0000-0000-0000000000b2','rider@x'),
  ('00000000-0000-0000-0000-0000000000b3','rider2@x');
-- Profil rider diisi supaya data invoice Mayar (nama/no HP) teruji.
update public.users set full_name='Rider Uji', phone='081234567890' where id = '00000000-0000-0000-0000-0000000000b2';

select set_config('bengkelku.allow_status_change','on',false);
insert into public.workshops(id, owner_id, name, status, location)
values ('50000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','Bengkel Uji','verified',
        st_setsrid(st_makepoint(106.81,-6.26),4326)::geography);
select set_config('bengkelku.allow_status_change','',false);
insert into public.services(id, workshop_id, name, price_idr) values
  ('51000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','Servis ringan',55000);
insert into public.vehicles(id, user_id, brand, model, plate) values
  ('52000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b2','Honda','Vario 160','B 1234 XYZ');

-- Aktifkan Mayar (nonaktifkan sandbox) seperti konfigurasi produksi.
update public.app_config set value = 'false'::jsonb where key = 'payments_sandbox';
update public.app_config set value = 'true'::jsonb  where key = 'mayar_enabled';

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select (current_date + 3) as d \gset
select slot_at as s from public.booking_available_slots('50000000-0000-0000-0000-000000000001', :'d') where label = '09:00' \gset
select (public.booking_create('50000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001',
  array['51000000-0000-0000-0000-000000000001']::uuid[], :'s')->>'id') as bid \gset

-- booking_create_payment: harus ditolak saat mayar_enabled false.
update public.app_config set value = 'false'::jsonb where key = 'mayar_enabled';
select pg_temp.assert(pg_temp.fails(format('select public.booking_create_payment(%L)', :'bid'), '%tidak tersedia%'),
  'gateway nonaktif menolak intent');
update public.app_config set value = 'true'::jsonb where key = 'mayar_enabled';

-- Kepemilikan: rider lain tidak bisa membuat intent untuk booking ini.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b3');
select pg_temp.assert(pg_temp.fails(format('select public.booking_create_payment(%L)', :'bid'), '%tidak ditemukan%'),
  'rider lain ditolak');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');

-- Intent pertama: nominal diambil server (55.000), status pending, provider mayar.
select (public.booking_create_payment(:'bid')->>'provider_ref') as ref \gset
select pg_temp.assert((select amount_idr from public.payments where provider_ref = :'ref') = 55000, 'nominal intent dari server');
select pg_temp.assert((select status from public.payments where provider_ref = :'ref') = 'pending', 'intent berstatus pending');
select pg_temp.assert((select provider from public.payments where provider_ref = :'ref') = 'mayar', 'provider mayar');
select pg_temp.assert((select method from public.payments where provider_ref = :'ref') is null, 'method null (kanal dipilih di Mayar)');

-- Data invoice ikut intent dalam satu round trip (customer + items + biaya layanan).
select pg_temp.assert((public.booking_create_payment(:'bid')->'customer'->>'email') = 'rider@x', 'email customer ikut intent');
select pg_temp.assert((public.booking_create_payment(:'bid')->'customer'->>'name') = 'Rider Uji', 'nama customer ikut intent');
select pg_temp.assert((public.booking_create_payment(:'bid')->'customer'->>'mobile') = '081234567890', 'no HP customer ikut intent');
select pg_temp.assert((public.booking_create_payment(:'bid')->'items'->0->>'name') = 'Servis ringan', 'item layanan ikut intent');
select pg_temp.assert((public.booking_create_payment(:'bid')->'items'->0->>'price_idr') = '55000', 'harga item ikut intent');
select pg_temp.assert((public.booking_create_payment(:'bid')->>'service_fee') = '0', 'biaya layanan dilaporkan ke gateway');

-- Idempotensi: panggilan ulang mengembalikan provider_ref yang sama.
select pg_temp.assert((public.booking_create_payment(:'bid')->>'provider_ref') = :'ref', 'intent idempoten');

-- Simulasi Edge Function menyimpan invoice + transactionId Mayar.
select public.payment_set_invoice(:'ref','https://mayar.id/i/1','maya-txn-001', now() + interval '30 minutes');
select pg_temp.assert((select invoice_url from public.payments where provider_ref = :'ref') = 'https://mayar.id/i/1', 'invoice_url tersimpan');
select pg_temp.assert((select gateway_txn_id from public.payments where provider_ref = :'ref') = 'maya-txn-001', 'gateway_txn_id tersimpan');

-- payment_mark: HANYA service role. Klien biasa harus ditolak.
set role authenticated;
select pg_temp.assert(pg_temp.fails(format('select public.payment_mark(%L,''paid'')', 'maya-txn-001'), '%permission%'),
  'rider tidak bisa menandai lunas');
reset role;

set role service_role;
-- Webhook pertama: lunas → booking menunggu konfirmasi + notif owner + thread chat.
select public.payment_mark('maya-txn-001','paid','qris', 55000, now());
select pg_temp.assert((select status from public.payments where gateway_txn_id = 'maya-txn-001') = 'paid', 'webhook menandai paid');
select pg_temp.assert((select paid_at is not null from public.payments where gateway_txn_id = 'maya-txn-001'), 'paid_at tercatat');
select pg_temp.assert((select method from public.payments where gateway_txn_id = 'maya-txn-001') = 'qris', 'kanal dari webhook tersimpan');
select pg_temp.assert((select status from public.bookings where id = :'bid') = 'DIBAYAR_MENUNGGU_KONFIRMASI',
  'booking lanjut ke menunggu konfirmasi');
select pg_temp.assert(exists(select 1 from public.chat_threads where booking_id = :'bid'), 'thread chat dibuat saat lunas');
select pg_temp.assert(exists(select 1 from public.notifications where user_id='00000000-0000-0000-0000-0000000000b1' and kind='booking'),
  'owner dapat notifikasi pembayaran');

-- Pengiriman ulang webhook tidak menggandakan efek.
select public.payment_mark('maya-txn-001','expired');
select pg_temp.assert((select status from public.payments where gateway_txn_id = 'maya-txn-001') = 'paid', 'webhook ulang idempoten');
select pg_temp.assert((select status from public.bookings where id = :'bid') = 'DIBAYAR_MENUNGGU_KONFIRMASI',
  'status booking tidak mundur');
reset role;

-- Webhook dengan nominal salah ditolak (anti pemalsuan).
select slot_at as s4 from public.booking_available_slots('50000000-0000-0000-0000-000000000001', :'d') where label = '12:00' \gset
select (public.booking_create('50000000-0000-0000-0000-000000000001',null,
  array['51000000-0000-0000-0000-000000000001']::uuid[], :'s4')->>'id') as bid4 \gset
select (public.booking_create_payment(:'bid4')->>'provider_ref') as ref4 \gset
select public.payment_set_invoice(:'ref4','https://mayar.id/i/4','maya-txn-004', now() + interval '30 minutes');
set role service_role;
select pg_temp.assert(pg_temp.fails(format('select public.payment_mark(%L,''paid'',''qris'',99999)', 'maya-txn-004'), '%tidak cocok%'),
  'webhook dengan nominal salah ditolak');
reset role;

-- Alur kedaluwarsa: booking baru, deadline lewat → intent ditolak & booking hangus.
select slot_at as s2 from public.booking_available_slots('50000000-0000-0000-0000-000000000001', :'d') where label = '10:00' \gset
select (public.booking_create('50000000-0000-0000-0000-000000000001',null,
  array['51000000-0000-0000-0000-000000000001']::uuid[], :'s2')->>'id') as bid2 \gset
update public.bookings set payment_deadline = now() - interval '5 minutes' where id = :'bid2';
select pg_temp.assert(pg_temp.fails(format('select public.booking_create_payment(%L)', :'bid2'), '%sudah lewat%'),
  'intent setelah batas bayar ditolak');
select pg_temp.assert((select status from public.bookings where id = :'bid2') = 'KEDALUWARSA', 'booking kedaluwarsa otomatis');

-- Alur gagal: pembayaran gagal → booking tetap menunggu, bisa coba lagi.
select slot_at as s3 from public.booking_available_slots('50000000-0000-0000-0000-000000000001', :'d') where label = '11:00' \gset
select (public.booking_create('50000000-0000-0000-0000-000000000001',null,
  array['51000000-0000-0000-0000-000000000001']::uuid[], :'s3')->>'id') as bid3 \gset
select (public.booking_create_payment(:'bid3')->>'provider_ref') as ref3 \gset
select public.payment_set_invoice(:'ref3','https://mayar.id/i/3','maya-txn-003', now() + interval '30 minutes');
set role service_role;
select public.payment_mark('maya-txn-003','failed','va/bni');
reset role;
select pg_temp.assert((select status from public.payments where gateway_txn_id = 'maya-txn-003') = 'failed', 'pembayaran gagal tercatat');
select pg_temp.assert((select status from public.bookings where id = :'bid3') = 'MENUNGGU_PEMBAYARAN', 'booking tetap bisa dibayar ulang');
select pg_temp.assert((public.booking_create_payment(:'bid3')->>'provider_ref') <> :'ref3', 'intent baru setelah gagal');

\echo MAYAR_PAYMENT_OK
