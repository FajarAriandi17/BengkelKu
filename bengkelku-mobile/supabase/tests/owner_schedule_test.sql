-- Uji jadwal buka/tutup yang diatur pemilik bengkel (0026).
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
  ('00000000-0000-0000-0000-0000000000c1','owner@x'),
  ('00000000-0000-0000-0000-0000000000c2','rider@x');

select set_config('bengkelku.allow_status_change','on',false);
insert into public.workshops(id, owner_id, name, status, location)
values ('60000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000c1','Bengkel Jadwal','verified',
        st_setsrid(st_makepoint(106.81,-6.26),4326)::geography);
select set_config('bengkelku.allow_status_change','',false);

\set W '60000000-0000-0000-0000-000000000001'
select (current_date + 3) as d \gset
select extract(dow from (current_date + 3))::int as dow \gset

-- Pemilik lain / rider tidak bisa menulis jam langsung
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
set role authenticated;
select pg_temp.assert(pg_temp.fails($q$insert into public.workshop_hours(workshop_id,weekday,open_time,close_time)
  values ('60000000-0000-0000-0000-000000000001',1,'08:00','17:00')$q$, '%row-level security%'),
  'tulis workshop_hours langsung dari klien diblokir');
reset role;
select pg_temp.assert(pg_temp.fails($q$select public.owner_schedule_get()$q$, '%belum punya bengkel%'),
  'non-pemilik tidak bisa membaca jadwal pemilik');

-- Pemilik mengatur jam
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select pg_temp.assert(jsonb_array_length(public.owner_schedule_get()->'hours') = 7, 'jadwal bawaan 7 hari');
select pg_temp.assert(pg_temp.fails($q$select public.owner_schedule_set_hours('[{"weekday":1,"open_time":"17:00","close_time":"08:00"}]')$q$,
  '%harus setelah jam buka%'), 'jam tutup sebelum jam buka ditolak');
select pg_temp.assert(pg_temp.fails($q$select public.owner_schedule_set_hours(
  (select jsonb_agg(jsonb_build_object('weekday', g, 'is_closed', true)) from generate_series(0,6) g))$q$,
  '%Minimal satu hari buka%'), 'semua hari tutup ditolak');
select pg_temp.assert(pg_temp.fails($q$select public.owner_schedule_set_hours('[{"weekday":1,"open_time":"08:00","close_time":"12:00"}]', 7)$q$,
  '%Durasi slot%'), 'durasi slot tidak valid ditolak');

select public.owner_schedule_set_hours(
  (select jsonb_agg(jsonb_build_object('weekday', g, 'open_time', '09:00', 'close_time', '12:00',
     'is_closed', g = 0)) from generate_series(0,6) g), 30, 2);
select pg_temp.assert((select count(*) from public.workshop_hours where workshop_id = :'W') = 7, 'upsert 7 baris jam');
-- simpan ulang tidak menggandakan baris
select public.owner_schedule_set_hours('[{"weekday":1,"open_time":"09:00","close_time":"12:00"}]');
select pg_temp.assert((select count(*) from public.workshop_hours where workshop_id = :'W') = 7, 'simpan ulang tidak menggandakan');
select pg_temp.assert((select slot_minutes = 30 and capacity_per_slot = 2 from public.workshop_slots_config where workshop_id = :'W'),
  'durasi slot & kapasitas tersimpan');

select pg_temp.assert(
  (select count(*) from public.booking_available_slots(:'W', :'d')) = case when :dow = 0 then 0 else 6 end,
  'slot mengikuti jam pemilik (09–12 per 30 menit = 6; Minggu libur)');

-- Libur khusus
select pg_temp.assert(pg_temp.fails($q$select public.owner_closure_add(current_date - 1)$q$, '%masa lalu%'), 'libur di masa lalu ditolak');
select public.owner_closure_add(:'d', 'Cuti bersama');
select pg_temp.assert((select count(*) from public.booking_available_slots(:'W', :'d')) = 0, 'libur khusus menutup semua slot');
select pg_temp.assert(jsonb_array_length(public.owner_schedule_get()->'closures') = 1, 'libur tampil di jadwal pemilik');
select pg_temp.assert(jsonb_array_length(public.workshop_open_status(:'W')->'closures') = 1, 'libur tampil di status publik');
select public.owner_closure_remove(:'d');
select pg_temp.assert(
  (select count(*) from public.booking_available_slots(:'W', :'d')) = case when :dow = 0 then 0 else 6 end,
  'hapus libur memulihkan slot');

-- Tutup sementara
select pg_temp.assert(pg_temp.fails($q$select public.owner_set_temp_closed(now() - interval '1 hour')$q$, '%masa depan%'),
  'tutup sementara ke masa lalu ditolak');
select public.owner_set_temp_closed(now() + interval '5 days', 'Renovasi');
select pg_temp.assert(not public.workshop_is_open(:'W', now()), 'tutup sementara → bengkel tutup');
select pg_temp.assert((select count(*) from public.booking_available_slots(:'W', :'d')) = 0, 'tutup sementara menutup slot');
select pg_temp.assert(public.workshop_open_status(:'W')->>'temp_closed_reason' = 'Renovasi', 'alasan tutup tampil publik');
select pg_temp.assert((select not is_open from public.nearby_workshops(-6.26, 106.81) where id = :'W'),
  'nearby_workshops melaporkan tutup');
select public.owner_set_temp_closed(null);
select pg_temp.assert((public.owner_schedule_get()->>'temp_closed_until') is null, 'buka kembali menghapus tutup sementara');

\o
select 'OWNER_SCHEDULE_OK' as result;
