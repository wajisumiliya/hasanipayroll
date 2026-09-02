create extension if not exists pgcrypto;

create table if not exists public.branch_activity_logs (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null,
  action text not null,
  employee_id text,
  employee_name text,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists branch_activity_logs_branch_opened_idx
  on public.branch_activity_logs (branch_id, opened_at desc);

create index if not exists branch_activity_logs_employee_idx
  on public.branch_activity_logs (employee_id);

alter table public.branch_activity_logs enable row level security;

create policy "branch activity app access"
  on public.branch_activity_logs
  for all
  to anon, authenticated
  using (true)
  with check (true);
