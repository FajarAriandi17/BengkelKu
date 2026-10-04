-- seed.sql — data awal BengkelKu. Dijalankan oleh `supabase db reset`.

insert into public.oil_interval_presets (label, interval_km, interval_days) values
  ('Oli mineral', 2000, 60),
  ('Oli semi-sintetik', 4000, 90),
  ('Oli sintetik', 8000, 180)
on conflict do nothing;
