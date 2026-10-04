-- 0101_audit_log.sql — jejak audit aksi admin

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.admin_users (id) on delete set null,
  action text not null,                 -- APPROVE_WORKSHOP, REJECT_WORKSHOP, VIEW_DOCUMENTS, ...
  target_type text,                     -- workshop | user | payout | ...
  target_id uuid,
  meta jsonb,
  ip inet,
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_actor on public.audit_logs (actor_id);
create index if not exists idx_audit_target on public.audit_logs (target_type, target_id);
create index if not exists idx_audit_created on public.audit_logs (created_at desc);
