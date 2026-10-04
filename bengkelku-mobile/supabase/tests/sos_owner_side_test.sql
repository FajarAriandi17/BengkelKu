-- Uji sisi bengkel Bantuan Darurat (0018 + 0019).
-- Jalankan pada DB baru: stub → semua migrasi → seed → file ini.
--   psql -d <db> -v ON_ERROR_STOP=1 -f supabase/tests/sos_owner_side_test.sql
-- Setiap pemeriksaan memakai assert(); kegagalan menghentikan skrip.
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

-- Hak akses ala Supabase untuk menguji RLS sebagai `authenticated`.
grant usage on schema public, extensions to authenticated;
grant select on all tables in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Data: pengendara R, bengkel A (dekat), B (dekat), C (belum disetujui),
--       D (dekat tapi tutup & tanpa siaga luar jam).
-- ---------------------------------------------------------------------------
insert into auth.users(id,email) values
  ('00000000-0000-0000-0000-0000000000a1','r@x'),
  ('00000000-0000-0000-0000-0000000000b1','a@x'),
  ('00000000-0000-0000-0000-0000000000b2','b@x'),
  ('00000000-0000-0000-0000-0000000000b3','c@x'),
  ('00000000-0000-0000-0000-0000000000b4','d@x');

-- Fixture: bengkel disetujui ditulis seperti admin (guard 0021).
select set_config('bengkelku.allow_status_change','on',false);
insert into public.workshops(id,owner_id,name,location,status) values
 ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000b1','A', st_setsrid(st_makepoint(106.801,-6.201),4326)::geography,'verified'),
 ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000b2','B', st_setsrid(st_makepoint(106.805,-6.205),4326)::geography,'verified'),
 ('20000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-0000000000b3','C', st_setsrid(st_makepoint(106.802,-6.202),4326)::geography,'pending'),
 ('20000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-0000000000b4','D', st_setsrid(st_makepoint(106.803,-6.203),4326)::geography,'verified');
select set_config('bengkelku.allow_status_change','',false);

-- D tutup setiap hari.
insert into public.workshop_hours(workshop_id, weekday, is_closed)
select '20000000-0000-0000-0000-000000000004', d, true from generate_series(0,6) d;

-- ---------------------------------------------------------------------------
-- Pengaturan siaga
-- ---------------------------------------------------------------------------
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b3');
do $$ begin
  perform public.sos_update_standby_settings(true, false, 4);
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%sudah disetujui%', 'bengkel belum disetujui tidak bisa siaga');
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
do $$ begin
  perform public.sos_update_standby_settings(true, false, 9);
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%Radius tidak valid%', 'radius di luar tier ditolak');
end $$;
select pg_temp.assert(
  (public.sos_update_standby_settings(true, false, 4)->>'emergency_ready')::boolean,
  'bengkel A siaga');
select public.sos_update_standby_position('20000000-0000-0000-0000-000000000001', -6.201, 106.801);

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select public.sos_update_standby_settings(true, false, 4);
select public.sos_update_standby_position('20000000-0000-0000-0000-000000000002', -6.205, 106.805);

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b4');
select public.sos_update_standby_settings(true, false, 4);
select public.sos_update_standby_position('20000000-0000-0000-0000-000000000004', -6.203, 106.803);

-- ---------------------------------------------------------------------------
-- Pengendara membuat permintaan: belum ada tawaran sebelum bayar.
-- ---------------------------------------------------------------------------
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select (public.sos_create('FLAT_TIRE','ban bocor','{}',-6.2,106.8,10,'depan masjid')->'request'->>'id') as rid \gset
select pg_temp.assert((select count(*) from public.sos_offers where request_id = :'rid') = 0,
  'tidak ada tawaran sebelum biaya panggilan dibayar');

select public.sos_mark_paid(:'rid');
select pg_temp.assert(
  (select array_agg(w.name order by w.name) from public.sos_offers o join public.workshops w on w.id = o.workshop_id
   where o.request_id = :'rid') = array['A','B'],
  'gelombang 1 hanya ke bengkel disetujui & buka (A, B) — bukan C/D');

-- ---------------------------------------------------------------------------
-- Privasi: bengkel yang hanya ditawari tidak bisa membaca baris permintaan.
-- ---------------------------------------------------------------------------
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select id as oid_a from public.sos_offers where request_id = :'rid' and workshop_id = '20000000-0000-0000-0000-000000000001' \gset
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select id as oid_b from public.sos_offers where request_id = :'rid' and workshop_id = '20000000-0000-0000-0000-000000000002' \gset

set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select pg_temp.assert((select count(*) from public.sos_requests where id = :'rid') = 0,
  'RLS: bengkel yang ditawari tidak membaca lokasi tepat');
select pg_temp.assert((select count(*) from public.sos_offers where id = :'oid_a') = 1,
  'RLS: bengkel membaca tawarannya sendiri');
select pg_temp.assert((select count(*) from public.sos_offers where id = :'oid_b') = 0,
  'RLS: bengkel tidak membaca tawaran bengkel lain');
reset role;

select public.sos_offer_details(:'oid_a') as det \gset
select pg_temp.assert(not (:'det'::jsonb ? 'lat') and not (:'det'::jsonb ? 'lng'),
  'detail tawaran tanpa lat/lng tepat');
select pg_temp.assert(abs((:'det'::jsonb->>'area_lat')::float - (-6.2)) < 0.003,
  'area umum dibulatkan ±300 m');
select pg_temp.assert((:'det'::jsonb->>'net_earnings')::int = round(((:'det'::jsonb->>'call_fee')::int + (:'det'::jsonb->>'night_fee')::int) * 0.92),
  'pendapatan bersih = biaya panggilan − 8%');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
do $$ begin
  perform public.sos_offer_details((select id from public.sos_offers where workshop_id = '20000000-0000-0000-0000-000000000001' limit 1));
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%tidak ditemukan%', 'bengkel lain tidak bisa membuka detail tawaran A');
end $$;

-- ---------------------------------------------------------------------------
-- Lewati (B) lalu terima (A).
-- ---------------------------------------------------------------------------
select public.sos_skip_offer(:'oid_b');
select pg_temp.assert((select state from public.sos_offers where id = :'oid_b') = 'skipped', 'B melewatkan tawaran');
select pg_temp.assert((select accept_rate from public.workshop_standby where workshop_id = '20000000-0000-0000-0000-000000000002') < 1.0,
  'tingkat penerimaan B turun');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select public.sos_accept(:'oid_a');

set role authenticated;
select pg_temp.assert((select count(*) from public.sos_requests where id = :'rid') = 1,
  'RLS: bengkel pemenang membaca permintaan');
reset role;

-- ---------------------------------------------------------------------------
-- Satu panggilan aktif per bengkel: permintaan kedua tidak ditawarkan ke A.
-- ---------------------------------------------------------------------------
insert into auth.users(id,email) values ('00000000-0000-0000-0000-0000000000a2','r2@x');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a2');
select (public.sos_create('DEAD_BATTERY',null,'{}',-6.2,106.8,10,null)->'request'->>'id') as rid2 \gset
select public.sos_mark_paid(:'rid2');
select pg_temp.assert(not exists (select 1 from public.sos_offers where request_id = :'rid2'
  and workshop_id = '20000000-0000-0000-0000-000000000001'),
  'bengkel yang sedang menangani panggilan tidak ditawari lagi');

-- ---------------------------------------------------------------------------
-- Rute → tiba → kode kedatangan.
-- ---------------------------------------------------------------------------
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
do $$ begin
  perform public.sos_verify_arrival_code((select id from public.sos_requests where code is not null and accepted_workshop_id = '20000000-0000-0000-0000-000000000001'), '0000');
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%setelah kamu tiba%', 'kode belum bisa dimasukkan sebelum tiba');
end $$;

select public.sos_start_route(:'rid');
select public.sos_record_tracking(:'rid', -6.2003, 106.8003);
select public.sos_mark_arrived(:'rid') as arr \gset
select pg_temp.assert(not (:'arr'::jsonb ? 'arrival_code'), 'sos_mark_arrived tidak membocorkan kode');

set role authenticated;
select pg_temp.assert((select arrival_code from public.sos_requests where id = :'rid') is null,
  'kolom arrival_code tidak berisi kode');
select pg_temp.assert((select count(*) from public.sos_arrival_codes where request_id = :'rid') = 0,
  'RLS: mekanik tidak bisa membaca tabel kode');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select pg_temp.assert((select count(*) from public.sos_arrival_codes where request_id = :'rid') = 1,
  'RLS: pengendara membaca kodenya');
reset role;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.sos_rider_arrival_code(:'rid') as code \gset
select pg_temp.assert(:'code' ~ '^[0-9]{4}$', 'kode 4 digit');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select pg_temp.assert(public.sos_rider_arrival_code(:'rid') is null, 'RPC kode tidak terbuka untuk mekanik');

select (case when :'code' = '0000' then '1111' else '0000' end) as wrong \gset
select pg_temp.assert(public.sos_verify_arrival_code(:'rid', :'wrong') = false, 'kode salah ditolak');
select pg_temp.assert((select arrival_code_attempts from public.sos_requests where id = :'rid') = 1, 'percobaan dihitung');
select pg_temp.assert(public.sos_verify_arrival_code(:'rid', :'code') = true, 'kode benar diterima');
select pg_temp.assert((select status from public.sos_requests where id = :'rid') = 'MEMERIKSA', 'status MEMERIKSA');

-- ---------------------------------------------------------------------------
-- Penawaran → disetujui → DIKERJAKAN → selesai.
-- ---------------------------------------------------------------------------
select (public.quote_create(null, :'rid',
  '[{"name":"Tambal ban","type":"jasa","price":20000},{"name":"Ban dalam","type":"sparepart","price":45000}]'::jsonb,
  'ban dalam sobek', '{}')->>'id') as qid \gset
select pg_temp.assert((select total from public.quotes where id = :'qid') = 65000, 'total dihitung server');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.quote_approve(:'qid');
select pg_temp.assert((select status from public.sos_requests where id = :'rid') = 'DIKERJAKAN', 'disetujui → DIKERJAKAN');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select public.sos_complete(:'rid', true);
select pg_temp.assert((select status from public.sos_requests where id = :'rid') = 'SELESAI', 'selesai');

-- ---------------------------------------------------------------------------
-- Pusat bantuan: tidak bisa mengaku admin; balasan saat MENUNGGU_INFO → DITINJAU.
-- ---------------------------------------------------------------------------
grant insert on public.support_messages, public.support_tickets to authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select (public.support_create_ticket('BENGKEL_TIDAK_DATANG','mekanik telat','{}',null,:'rid',null)->>'id') as tid \gset

set role authenticated;
do $$ begin
  insert into public.support_tickets(code,user_id,category,description)
  values ('TK-HACK','00000000-0000-0000-0000-0000000000a1','LAINNYA','x');
  raise exception 'seharusnya ditolak';
exception when insufficient_privilege then
  perform pg_temp.assert(true, 'tiket hanya lewat RPC');
end $$;
do $$ begin
  insert into public.support_messages(ticket_id,sender_id,from_admin,body)
  values ((select id from public.support_tickets limit 1),'00000000-0000-0000-0000-0000000000a1',true,'saya admin');
  raise exception 'seharusnya ditolak';
exception when insufficient_privilege then
  perform pg_temp.assert(true, 'pengguna tidak bisa mengirim pesan sebagai admin');
end $$;
reset role;

update public.support_tickets set state = 'MENUNGGU_INFO' where id = :'tid';
set role authenticated;
insert into public.support_messages(ticket_id,sender_id,body)
values (:'tid','00000000-0000-0000-0000-0000000000a1','ini foto tambahannya');
reset role;
select pg_temp.assert((select state from public.support_tickets where id = :'tid') = 'DITINJAU',
  'balasan pengguna mengembalikan tiket ke DITINJAU');

-- ---------------------------------------------------------------------------
-- 0020: bengkel peserta boleh melapor; validasi server; balasan lewat RPC.
-- ---------------------------------------------------------------------------
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select pg_temp.assert(
  (public.support_create_ticket('HARGA_TIDAK_SESUAI','pengendara minta harga di luar aplikasi','{}',null,:'rid',null)->>'code') like 'TK-%',
  'bengkel penerima bisa melapor atas panggilan darurat');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
do $$ begin
  perform public.support_create_ticket('LAINNYA','bukan panggilan saya sama sekali','{}',null,
    (select id from public.sos_requests where accepted_workshop_id = '20000000-0000-0000-0000-000000000001' limit 1),null);
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%tidak ditemukan%', 'bengkel lain tidak bisa melapor atas panggilan itu');
end $$;
do $$ begin
  perform public.support_create_ticket('LAINNYA','pendek','{}',null,null,null);
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%minimal 10%', 'deskripsi terlalu pendek ditolak');
end $$;
do $$ begin
  perform public.support_create_ticket('LAINNYA','foto terlalu banyak sekali','{a,b,c,d}',null,null,null);
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%Maksimal 3 foto%', 'lebih dari 3 foto ditolak');
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
update public.support_tickets set state = 'MENUNGGU_INFO' where id = :'tid';
select public.support_reply(:'tid', 'kirim info tambahan lewat RPC');
select pg_temp.assert((select state from public.support_tickets where id = :'tid') = 'DITINJAU',
  'support_reply mengembalikan tiket ke DITINJAU');
update public.support_tickets set state = 'SELESAI' where id = :'tid';
do $$ begin
  perform public.support_reply((select id from public.support_tickets where state = 'SELESAI' limit 1), 'halo');
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%sudah selesai%', 'tidak bisa membalas tiket SELESAI');
end $$;

\echo OWNER_SIDE_OK
