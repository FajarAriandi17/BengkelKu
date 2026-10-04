-- Jalankan: psql -d <db> -f local_supabase_stub.sql, semua migrasi + seed, lalu file ini.
-- Error "Panggilan sudah diambil" memang diharapkan (uji 2 bengkel menerima bersamaan).
\set ON_ERROR_STOP 1
-- users
insert into auth.users(id,email) values ('00000000-0000-0000-0000-00000000000a','rider@x'),('00000000-0000-0000-0000-00000000000b','owner@x'),('00000000-0000-0000-0000-00000000000c','owner2@x');
select id, roles from public.users;
-- Fixture: bengkel disetujui ditulis seperti admin (guard 0021).
select set_config('bengkelku.allow_status_change','on',false);
insert into public.workshops(id,owner_id,name,location,status) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000b','Bengkel A', st_setsrid(st_makepoint(106.801,-6.201),4326)::geography,'verified'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-00000000000c','Bengkel B', st_setsrid(st_makepoint(106.805,-6.205),4326)::geography,'verified');
select set_config('bengkelku.allow_status_change','',false);
-- owner standby
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false);
select public.sos_toggle_standby('10000000-0000-0000-0000-000000000001', true, 4);
select public.sos_update_standby_position('10000000-0000-0000-0000-000000000001', -6.201,106.801);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false);
select public.sos_toggle_standby('10000000-0000-0000-0000-000000000002', true, 4);
select public.sos_update_standby_position('10000000-0000-0000-0000-000000000002', -6.205,106.805);
-- rider creates
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false);
select public.sos_quote_fee(-6.2,106.8);
select public.sos_create('DEAD_BATTERY','aki soak','{}',-6.2,106.8,12,'depan indomaret')::text as created \gset
\echo :created
select (:'created'::jsonb->'request'->>'id') as rid \gset
\echo request :rid
select public.sos_mark_paid(:'rid')->>'status';
select public.sos_dispatch_wave();
select workshop_id, state, wave from public.sos_offers where request_id=:'rid';
-- owner accepts
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false);
select id as oid from public.sos_offers where request_id=:'rid' and workshop_id='10000000-0000-0000-0000-000000000001' \gset
select public.sos_accept(:'oid');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false);
select id as oid2 from public.sos_offers where request_id=:'rid' and workshop_id='10000000-0000-0000-0000-000000000002' \gset
\set ON_ERROR_STOP 0
select public.sos_accept(:'oid2');
\set ON_ERROR_STOP 1
select type, state from public.chat_threads;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false);
select public.sos_start_route(:'rid');
select public.sos_record_tracking(:'rid',-6.2005,106.8005);
select public.sos_mark_arrived(:'rid') as arr \gset
-- Kode TIDAK dikembalikan ke mekanik (0019); pengendara membacanya lalu mekanik memasukkannya.
select (:'arr'::jsonb ? 'arrival_code') = false as code_hidden_from_mechanic;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false);
select public.sos_rider_arrival_code(:'rid') as code \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false);
select public.sos_verify_arrival_code(:'rid', :'code') as verified;
select public.quote_create(null, :'rid', '[{"name":"Ganti aki","type":"sparepart","price":185000}]'::jsonb, 'aki GS', '{}') as q \gset
select (:'q'::jsonb->>'id') as qid \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false);
select public.quote_approve(:'qid');
select status from public.sos_requests where id=:'rid';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false);
select public.sos_complete(:'rid', true);
select status from public.sos_requests where id=:'rid';
-- chat
select id as tid from public.chat_threads limit 1 \gset
select public.chat_send(:'tid','00000000-0000-0000-0000-00000000000b','text','hubungi 08123456789 atau https://wa.me/x',null,null,null,null,'c1');
select body from public.chat_messages where thread_id=:'tid' order by created_at;
-- support
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false);
select public.support_create_ticket('HARGA_TIDAK_SESUAI','harga beda','{}',null,:'rid',null);
\echo SMOKE_OK
