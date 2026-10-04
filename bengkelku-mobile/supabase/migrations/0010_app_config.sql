-- 0010_app_config.sql — konfigurasi aplikasi (nilai usulan PRD v1.3)
-- Semua angka bertanda (usulan) disimpan di sini agar admin bisa mengubah
-- tanpa rilis aplikasi. Baca di klien: supabase.from('app_config').select()

create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  label text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

-- app_config boleh dibaca publik (berisi tarif, bukan rahasia).
create policy app_config_read on public.app_config
  for select using (true);

-- Index agar order by updated_at cepat (pemantauan admin).
create index if not exists idx_app_config_updated on public.app_config (updated_at);

-- Seed nilai bawaan PRD v1.3 (Bagian 3.5, 3.4, 4.1, 3.8, 7, 5, 6).
insert into public.app_config (key, value, label) values
  -- Tier biaya panggilan darurat (jarak bengkel ke pengendara).
  ('sos_tiers', '[{"tier":1,"max_km":3,"fee":25000},{"tier":2,"max_km":6,"fee":40000},{"tier":3,"max_km":10,"fee":55000},{"tier":4,"max_km":15,"fee":75000}]'::jsonb, 'Tier biaya panggilan darurat'),
  ('sos_night_fee', '10000'::jsonb, 'Biaya malam darurat'),
  ('sos_night_start_hour', '21'::jsonb, 'Jam mulai biaya malam'),
  ('sos_night_end_hour', '5'::jsonb, 'Jam selesai biaya malam'),
  ('sos_max_radius_m', '15000'::jsonb, 'Radius maksimal pencarian bengkel'),
  ('sos_payment_minutes', '10'::jsonb, 'Batas bayar biaya panggilan (menit)'),
  -- Dispatch gelombang.
  ('sos_wave_count', '3'::jsonb, 'Jumlah gelombang pencarian'),
  ('sos_wave_size', '3'::jsonb, 'Bengkel per gelombang'),
  ('sos_wave_seconds', '60'::jsonb, 'Durasi tiap gelombang (detik)'),
  ('sos_eta_speed_kmh', '25'::jsonb, 'Kecepatan asumsi estimasi tiba (km/jam)'),
  ('sos_offer_seconds', '60'::jsonb, 'Hitung mundur tawaran bengkel (detik)'),
  ('sos_min_accept_rate', '0.7'::jsonb, 'Ambang tingkat penerimaan siaga darurat'),
  ('sos_eta_overdue_minutes', '15'::jsonb, 'Menit ETA terlewatan = mekanik dianggap tidak muncul'),
  ('sos_rider_wait_minutes', '10'::jsonb, 'Menit tunggu mekanik di lokasi'),
  ('sos_cancel_free_seconds', '120'::jsonb, 'Pembatalan gratis setelah diterima (detik)'),
  ('sos_cancel_free_radius_m', '300'::jsonb, 'Radius gerak mekanik untuk pembatalan gratis'),
  ('sos_abuse_limit', '5'::jsonb, 'Batas pembatalan tanpa alasan per 30 hari'),
  ('sos_abuse_hold_days', '7'::jsonb, 'Hari fitur ditahan setelah batas abuse'),
  -- Penawaran (Fitur C).
  ('quote_max_total', '2000000'::jsonb, 'Total maksimal penawaran di tempat'),
  ('quote_max_items', '10'::jsonb, 'Jumlah butir maksimal per penawaran'),
  ('quote_min_items', '1'::jsonb, 'Jumlah butir minimal per penawaran'),
  ('quote_emergency_minutes', '10'::jsonb, 'Masa berlaku penawaran darurat (menit)'),
  ('quote_booking_minutes', '30'::jsonb, 'Masa berlaku penawaran booking biasa (menit)'),
  ('quote_max_revisions', '2'::jsonb, 'Maksimal revisi per penawaran'),
  -- Komisi & biaya layanan.
  ('commission_rate', '0.08'::jsonb, 'Komisi platform'),
  ('user_service_fee', '0'::jsonb, 'Biaya layanan platform untuk pengendara'),
  -- Chat (Fitur A).
  ('chat_max_chars', '1000'::jsonb, 'Maksimal karakter pesan'),
  ('chat_max_photos', '3'::jsonb, 'Maksimal foto per pesan'),
  ('chat_booking_open_days', '7'::jsonb, 'Hari thread booking tetap terbuka setelah selesai'),
  ('chat_sos_open_hours', '24'::jsonb, 'Jam thread darurat tetap terbuka setelah selesai'),
  ('chat_retention_months', '12'::jsonb, 'Retensi pesan chat (bulan)'),
  -- Tracking.
  ('sos_tracking_broadcast_seconds', '5'::jsonb, 'Interval broadcast lokasi mekanik (detik)'),
  ('sos_tracking_persist_seconds', '30'::jsonb, 'Interval simpan jejak lokasi ke DB (detik)'),
  ('sos_tracking_retention_hours', '24'::jsonb, 'Retensi jejak lokasi (jam)'),
  -- Support (Fitur F).
  ('support_sla_hours', '24'::jsonb, 'SLA balasan pertama tiket bantuan (jam kerja)'),
  -- Voucher (Fitur E).
  ('referral_commission_free_months', '1'::jsonb, 'Bonus komisi 0% untuk referral bengkel (bulan)'),
  -- CTA eksternal.
  ('tax_info_url', '"https://www.dipendajakarta.go.id/"'::jsonb, 'Tautan informasi resmi pajak daerah')
on conflict (key) do nothing;
