-- Uji alur verifikasi bengkel app ↔ admin web (0021, 0103, 0104).
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
grant select, insert, update on all tables in schema public to authenticated;

insert into auth.users(id,email) values
  ('00000000-0000-0000-0000-0000000000c1','owner@x'),
  ('00000000-0000-0000-0000-0000000000c2','rider@x'),
  ('00000000-0000-0000-0000-0000000000ad','admin@x'),
  ('00000000-0000-0000-0000-0000000000a5','cs@x');
insert into public.admin_users(id,email,role) values
  ('00000000-0000-0000-0000-0000000000ad','admin@x','super_admin'),
  ('00000000-0000-0000-0000-0000000000a5','cs@x','cs');

-- Pemilik mendaftar (draft) — tidak bisa menyetujui diri sendiri.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select pg_temp.assert(pg_temp.fails($q$select public.workshop_register('Jaya','Jl. Fatmawati No. 12','08',51.5,-0.1)$q$, '%Indonesia%'),
  'lokasi di luar Indonesia ditolak');
select (public.workshop_register('Bengkel Jaya Motor','Jl. Fatmawati No. 12, Jakarta Selatan','0812000111',-6.2615,106.8106,'servis matic')->>'id') as wid \gset
select pg_temp.assert((select status from public.workshops where id = :'wid') = 'draft', 'pendaftaran baru = draft');
select pg_temp.assert((public.workshop_my_status()->>'lat')::float between -6.27 and -6.25, 'lokasi GPS asli tersimpan');

set role authenticated;
select pg_temp.assert(pg_temp.fails($q$update public.workshops set status='verified' where owner_id='00000000-0000-0000-0000-0000000000c1'$q$, '%hanya bisa diubah oleh admin%'),
  'pemilik tidak bisa menyetujui bengkelnya sendiri');
insert into public.workshops(owner_id,name,status,rating_avg) values ('00000000-0000-0000-0000-0000000000c1','Palsu','verified',5);
select pg_temp.assert((select status = 'draft' and rating_avg = 0 from public.workshops where name='Palsu'), 'insert langsung dipaksa draft & rating 0');
reset role;
delete from public.workshops where name = 'Palsu';

select pg_temp.assert(pg_temp.fails(format('select public.workshop_submit_verification(%L)', :'wid'), '%Dokumen belum lengkap%'),
  'pengajuan tanpa dokumen ditolak');
insert into public.workshop_documents(workshop_id,type,storage_path) values
  (:'wid','ktp','u/ktp.jpg'),(:'wid','selfie','u/selfie.jpg'),(:'wid','location','u/loc.jpg');
select public.workshop_submit_verification(:'wid');
select pg_temp.assert((select status from public.workshops where id = :'wid') = 'pending', 'diajukan → pending (masuk antrean admin)');
select pg_temp.assert(pg_temp.fails($q$select public.workshop_register('Bengkel Jaya Motor','Jl. Fatmawati No. 12, Jakarta','08',-6.26,106.81)$q$, '%sedang ditinjau%'),
  'data terkunci saat ditinjau');

-- Admin: helper tanpa rekursi, antrean terlihat, tolak → ajukan ulang → setujui.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000ad');
set role authenticated;
select pg_temp.assert(public.is_admin(), 'is_admin() tanpa rekursi RLS');
select pg_temp.assert((select count(*) from public.admin_users) = 2, 'admin membaca admin_users');
select pg_temp.assert((select count(*) from public.workshops where status = 'pending') = 1, 'antrean admin melihat bengkel pending');
select pg_temp.assert((public.admin_me()->>'role') = 'super_admin', 'admin_me mengembalikan peran');
reset role;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
select pg_temp.assert(pg_temp.fails(format('select public.admin_verify_workshop(%L,''approve'')', :'wid'), '%Hanya admin%'),
  'non-admin tidak bisa memverifikasi');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000ad');
select pg_temp.assert(pg_temp.fails(format('select public.admin_verify_workshop(%L,''reject'')', :'wid'), '%Alasan penolakan wajib%'),
  'tolak tanpa alasan ditolak');
select public.admin_verify_workshop(:'wid','reject','KTP_BURAM','foto KTP buram');
select pg_temp.assert((select status = 'rejected' and rejected_reason = 'foto KTP buram' from public.workshops where id = :'wid'),
  'admin menolak + alasan tersimpan');
select pg_temp.assert((select count(*) from public.workshop_documents where workshop_id = :'wid' and status='rejected') = 3, 'dokumen ditandai ditolak');
select pg_temp.assert(exists (select 1 from public.notifications where user_id='00000000-0000-0000-0000-0000000000c1' and kind='verification'),
  'pemilik mendapat notifikasi');
select pg_temp.assert(exists (select 1 from public.audit_logs where action='REJECT_WORKSHOP' and target_id = :'wid'), 'penolakan tercatat di audit');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select pg_temp.assert(pg_temp.fails(format('select public.workshop_submit_verification(%L)', :'wid'), '%Dokumen belum lengkap%'),
  'ajukan ulang wajib dokumen baru');
insert into public.workshop_documents(workshop_id,type,storage_path) values
  (:'wid','ktp','u/ktp2.jpg'),(:'wid','selfie','u/selfie2.jpg'),(:'wid','location','u/loc2.jpg');
select public.workshop_submit_verification(:'wid');
select pg_temp.assert((select status = 'pending' and submission_count = 2 from public.workshops where id = :'wid'), 'ajukan ulang setelah ditolak');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000ad');
select public.admin_verify_workshop(:'wid','approve',null,null,'{"ktp":true}'::jsonb);
select pg_temp.assert((select status from public.workshops where id = :'wid') = 'verified', 'admin menyetujui → verified');
select pg_temp.assert((select 'owner' = any(roles) from public.users where id='00000000-0000-0000-0000-0000000000c1'), 'peran owner ditambahkan');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
select pg_temp.assert((select count(*) from public.nearby_workshops(-6.2615,106.8106,5000,10)) = 1, 'bengkel disetujui muncul di bengkel terdekat');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select pg_temp.assert((public.sos_update_standby_settings(true,false,4)->>'emergency_ready')::boolean, 'bengkel disetujui bisa siaga darurat');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000ad');
select public.admin_set_workshop_status(:'wid','suspended','banyak laporan harga');
select pg_temp.assert((select emergency_ready from public.workshop_standby where workshop_id = :'wid') = false, 'tangguhkan mematikan siaga');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
select pg_temp.assert((select count(*) from public.nearby_workshops(-6.2615,106.8106,5000,10)) = 0, 'bengkel ditangguhkan tidak tampil');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000ad');
select public.admin_set_workshop_status(:'wid','verified','sudah diklarifikasi');

-- Rating ulasan tersimpan.
select set_config('bengkelku.allow_status_change','on',false);
insert into public.bookings(id,rider_id,workshop_id,status,scheduled_at)
values ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000c2',:'wid','SELESAI',now());
select set_config('bengkelku.allow_status_change','',false);
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
set role authenticated;
insert into public.reviews(booking_id,rider_id,workshop_id,rating) values
  ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000c2',:'wid',4);
reset role;
select pg_temp.assert((select rating_avg = 4.0 and rating_count = 1 from public.workshops where id = :'wid'), 'ulasan memperbarui rating bengkel');

-- 0104: tiket bantuan, konfigurasi, statistik.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
select (public.support_create_ticket('HARGA_TIDAK_SESUAI','harga beda dengan penawaran','{}',null,null,null)->>'id') as tid \gset
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a5');
select public.admin_ticket_reply(:'tid','mohon kirim foto nota','MENUNGGU_INFO');
select pg_temp.assert((select state from public.support_tickets where id = :'tid') = 'MENUNGGU_INFO', 'CS minta info');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
select public.support_reply(:'tid','ini fotonya');
select pg_temp.assert((select state from public.support_tickets where id = :'tid') = 'DITINJAU', 'balasan pengguna → DITINJAU');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a5');
select public.admin_ticket_resolve(:'tid','Refund sebagian','selisih harga Rp 20.000 dikembalikan');
select pg_temp.assert((select state = 'SELESAI' and decision = 'Refund sebagian' from public.support_tickets where id = :'tid'), 'CS menyelesaikan dengan keputusan');
select pg_temp.assert((select count(*) from public.notifications where user_id='00000000-0000-0000-0000-0000000000c2' and kind='support') = 2,
  'pengguna mendapat notifikasi balasan & keputusan');
select pg_temp.assert(pg_temp.fails($q$select public.admin_set_config('commission_rate','0.1'::jsonb)$q$, '%super admin%'), 'CS tidak bisa mengubah konfigurasi');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000ad');
select pg_temp.assert(pg_temp.fails($q$select public.admin_set_config('commission_rate','"abc"'::jsonb)$q$, '%Tipe nilai%'), 'tipe nilai konfigurasi divalidasi');
select public.admin_set_config('sos_night_fee','12000'::jsonb);
select pg_temp.assert((select value from public.app_config where key='sos_night_fee') = '12000'::jsonb
  and exists (select 1 from public.audit_logs where action='SET_CONFIG'), 'super admin mengubah konfigurasi + audit');
select pg_temp.assert((public.admin_dashboard_stats()->>'verified_workshops')::int = 1, 'statistik dasbor admin');
select pg_temp.assert((select count(*) from public.admin_sos_live()) = 0, 'pemantauan SOS');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
select pg_temp.assert(public.admin_dashboard_stats() is null, 'non-admin tidak melihat statistik');

-- ---------------------------------------------------------------------------
-- 0022: aksi booking bengkel & dasbor.
-- ---------------------------------------------------------------------------
select set_config('bengkelku.allow_status_change','on',false);
insert into public.bookings(id,rider_id,workshop_id,status,scheduled_at,total_idr)
values ('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000c2',:'wid','DIBAYAR_MENUNGGU_KONFIRMASI',now()+interval '1 hour',75000),
       ('30000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-0000000000c2',:'wid','DIBAYAR_MENUNGGU_KONFIRMASI',now()+interval '2 hour',50000);
select set_config('bengkelku.allow_status_change','',false);

select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select pg_temp.assert(jsonb_array_length(public.owner_dashboard()->'queue') = 2
  and (public.owner_dashboard()->>'waiting_confirmation')::int = 2, 'dasbor bengkel menampilkan antrean nyata');
set role authenticated;
update public.bookings set status = 'SELESAI', total_idr = 1 where id = '30000000-0000-0000-0000-000000000002';
reset role;
select pg_temp.assert((select status from public.bookings where id='30000000-0000-0000-0000-000000000002') = 'DIBAYAR_MENUNGGU_KONFIRMASI',
  'pemilik tidak bisa mengubah booking langsung');
do $$ begin
  perform public.owner_booking_action('30000000-0000-0000-0000-000000000002','complete');
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%tidak bisa dilakukan%', 'transisi status tidak valid ditolak');
end $$;
select public.owner_booking_action('30000000-0000-0000-0000-000000000002','confirm');
select public.owner_booking_action('30000000-0000-0000-0000-000000000002','start');
select public.owner_booking_action('30000000-0000-0000-0000-000000000002','complete');
select pg_temp.assert((select status from public.bookings where id='30000000-0000-0000-0000-000000000002') = 'SELESAI', 'konfirmasi → kerjakan → selesai');
select public.owner_booking_action('30000000-0000-0000-0000-000000000003','reject','slot penuh, hubungi 081234567890');
select pg_temp.assert((select amount_idr from public.refunds where booking_id='30000000-0000-0000-0000-000000000003') = 50000,
  'tolak booking → refund 100% dicatat');
select pg_temp.assert((select cancel_reason from public.bookings where id='30000000-0000-0000-0000-000000000003') not like '%0812%',
  'nomor telepon di alasan penolakan disembunyikan');
select pg_temp.assert((public.owner_dashboard()->>'today_revenue')::int = 69000, 'pendapatan bersih hari ini (75.000 − 8%)');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
do $$ begin
  perform public.owner_booking_action('30000000-0000-0000-0000-000000000003','confirm');
  raise exception 'seharusnya ditolak';
exception when others then
  perform pg_temp.assert(sqlerrm like '%tidak ditemukan%', 'pengendara tidak bisa memakai aksi bengkel');
end $$;

\echo VERIFICATION_ADMIN_OK
