-- Uji alur booking pengendara lewat RPC (0023).
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
  ('00000000-0000-0000-0000-0000000000b2','rider@x');

select set_config('bengkelku.allow_status_change','on',false);
insert into public.workshops(id, owner_id, name, status, location)
values ('50000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','Bengkel Uji','verified',
        st_setsrid(st_makepoint(106.81,-6.26),4326)::geography);
select set_config('bengkelku.allow_status_change','',false);
insert into public.workshop_slots_config(workshop_id, slot_minutes, capacity_per_slot)
values ('50000000-0000-0000-0000-000000000001', 60, 1);
insert into public.services(id, workshop_id, name, price_idr) values
  ('51000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','Servis ringan',55000),
  ('51000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000001','Ganti oli',65000);
insert into public.services(id, workshop_id, name, price_idr, is_active) values
  ('51000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001','Nonaktif',1, false);
insert into public.vehicles(id, user_id, brand, model, plate) values
  ('52000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b2','Honda','Vario 160','B 1234 XYZ');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select (current_date + 3) as d \gset
select pg_temp.assert((select count(*) from public.booking_available_slots('50000000-0000-0000-0000-000000000001', :'d')) = 9,
  'slot bawaan 08:00–17:00 per 60 menit = 9');
select slot_at as s from public.booking_available_slots('50000000-0000-0000-0000-000000000001', :'d') where label = '09:00' \gset

set role authenticated;
select pg_temp.assert(pg_temp.fails($q$insert into public.bookings(rider_id,workshop_id,status,scheduled_at,total_idr)
  values ('00000000-0000-0000-0000-0000000000b2','50000000-0000-0000-0000-000000000001','SELESAI',now(),1)$q$, '%row-level security%'),
  'insert booking langsung dari klien diblokir');
reset role;

select pg_temp.assert(pg_temp.fails(format($q$select public.booking_create('50000000-0000-0000-0000-000000000001',null,
  array['51000000-0000-0000-0000-000000000003']::uuid[], %L)$q$, :'s'), '%tidak tersedia%'), 'layanan nonaktif ditolak');
select (public.booking_create('50000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001',
  array['51000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002']::uuid[], :'s')->>'id') as bid \gset
select pg_temp.assert((select total_idr = 120000 and status = 'MENUNGGU_PEMBAYARAN' from public.bookings where id = :'bid'),
  'total dihitung server (120.000)');
select pg_temp.assert((select count(*) from public.booking_items where booking_id = :'bid') = 2, 'item booking tersimpan');
select pg_temp.assert((select remaining from public.booking_available_slots('50000000-0000-0000-0000-000000000001', :'d') where label='09:00') = 0,
  'kuota slot berkurang');
select pg_temp.assert(pg_temp.fails(format($q$select public.booking_create('50000000-0000-0000-0000-000000000001',null,
  array['51000000-0000-0000-0000-000000000001']::uuid[], %L)$q$, :'s'), '%penuh%'), 'slot penuh ditolak');
select pg_temp.assert(pg_temp.fails($q$select public.booking_create('50000000-0000-0000-0000-000000000001',null,
  array['51000000-0000-0000-0000-000000000001']::uuid[], now() + interval '10 minutes')$q$, '%Slot tidak tersedia%'), 'jam di luar slot ditolak');

select public.booking_sandbox_pay(:'bid');
select pg_temp.assert((select status from public.bookings where id = :'bid') = 'DIBAYAR_MENUNGGU_KONFIRMASI', 'bayar sandbox → menunggu konfirmasi');
select pg_temp.assert(exists(select 1 from public.chat_threads where booking_id = :'bid'), 'thread chat booking dibuat');
select pg_temp.assert(exists(select 1 from public.notifications where user_id='00000000-0000-0000-0000-0000000000b1' and kind='booking'),
  'bengkel dapat notifikasi booking baru');
select pg_temp.assert((public.booking_detail(:'bid')->'vehicle'->>'plate') = 'B 1234 XYZ', 'booking_detail lengkap');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select public.owner_booking_action(:'bid','confirm');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select pg_temp.assert((public.booking_cancel(:'bid','berubah rencana')->>'refund_pct')::numeric = 1, 'batal ≥ 2 jam → refund 100%');
select pg_temp.assert((select amount_idr from public.refunds where booking_id = :'bid') = 120000, 'refund tercatat');
select pg_temp.assert(pg_temp.fails(format('select public.booking_cancel(%L,''lagi'')', :'bid'), '%tidak bisa dibatalkan%'), 'tidak bisa batal dua kali');

update public.app_config set value = 'false'::jsonb where key = 'payments_sandbox';
select (public.booking_create('50000000-0000-0000-0000-000000000001',null,
  array['51000000-0000-0000-0000-000000000001']::uuid[], :'s')->>'id') as bid2 \gset
select pg_temp.assert(pg_temp.fails(format('select public.booking_sandbox_pay(%L)', :'bid2'), '%dinonaktifkan%'), 'sandbox nonaktif di produksi');
update public.bookings set payment_deadline = now() - interval '1 minute' where id = :'bid2';
select pg_temp.assert(public.booking_expire_unpaid() = 1, 'booking belum bayar kedaluwarsa');

\echo BOOKING_FLOW_OK
