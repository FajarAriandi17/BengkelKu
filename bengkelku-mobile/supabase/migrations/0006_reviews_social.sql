-- 0006_reviews_social.sql — ulasan, favorit, notifikasi

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  rider_id uuid not null references public.users (id) on delete cascade,
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  photo_path text,                              -- bucket publik (<=2MB)
  created_at timestamptz not null default now(),
  unique (booking_id)                           -- satu ulasan per booking
);
create index if not exists idx_reviews_workshop on public.reviews (workshop_id);

create table if not exists public.favorites (
  user_id uuid not null references public.users (id) on delete cascade,
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, workshop_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  title text not null,
  body text,
  kind text not null default 'general',         -- booking | oil | verification | general
  data jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_notif_user on public.notifications (user_id);

-- Perbarui agregat rating bengkel saat ada ulasan baru.
create or replace function public.refresh_workshop_rating()
returns trigger
language plpgsql
as $$
begin
  update public.workshops w
  set rating_avg = coalesce((select round(avg(rating)::numeric, 1) from public.reviews r where r.workshop_id = w.id), 0),
      rating_count = (select count(*) from public.reviews r where r.workshop_id = w.id)
  where w.id = new.workshop_id;
  return new;
end$$;

drop trigger if exists on_review_created on public.reviews;
create trigger on_review_created
  after insert on public.reviews
  for each row execute function public.refresh_workshop_rating();
