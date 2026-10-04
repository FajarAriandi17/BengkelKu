-- 0100_admin_roles.sql — tabel admin & peran (project Supabase sama dgn mobile)
-- Admin TERPISAH dari pengguna mobile. Akun admin dibuat lewat undangan,
-- tertaut auth.users tetapi dengan klaim/aud admin & baris di admin_users.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'admin_role') then
    create type admin_role as enum ('super_admin', 'verifikator', 'finance', 'cs');
  end if;
end$$;

create table if not exists public.admin_users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  role admin_role not null default 'verifikator',
  is_active boolean not null default true,
  totp_enabled boolean not null default false,
  invited_by uuid references public.admin_users (id),
  created_at timestamptz not null default now()
);

-- Helper: apakah auth.uid() admin aktif?
create or replace function public.is_admin()
returns boolean language sql stable as $$
  select exists (
    select 1 from public.admin_users a
    where a.id = auth.uid() and a.is_active
  );
$$;

-- Helper: cek peran tertentu.
create or replace function public.has_admin_role(r admin_role)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.admin_users a
    where a.id = auth.uid() and a.is_active
      and (a.role = r or a.role = 'super_admin')
  );
$$;
