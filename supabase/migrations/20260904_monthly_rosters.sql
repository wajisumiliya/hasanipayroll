create extension if not exists pgcrypto;

create table if not exists public.monthly_rosters (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null,
  employee_id text not null,
  roster_year integer not null check (roster_year between 2020 and 2100),
  roster_month integer not null check (roster_month between 1 and 12),
  week_number integer not null check (week_number between 1 and 5),
  shift_start time not null,
  shift_end time not null,
  break_minutes integer not null default 60 check (break_minutes between 0 and 720),
  off_weekday smallint check (off_weekday between 1 and 7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, employee_id, roster_year, roster_month, week_number)
);

alter table public.monthly_rosters
  add column if not exists off_weekday smallint
  check (off_weekday between 1 and 7);

create index if not exists monthly_rosters_branch_period_idx
  on public.monthly_rosters (branch_id, roster_year, roster_month);

alter table public.monthly_rosters enable row level security;
revoke all on table public.monthly_rosters from anon;

create policy monthly_rosters_admin_all on public.monthly_rosters
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');
create policy monthly_rosters_branch_all on public.monthly_rosters
  for all to authenticated
  using (public.current_app_role() = 'branch' and branch_id = public.current_branch_id())
  with check (public.current_app_role() = 'branch' and branch_id = public.current_branch_id());
create policy monthly_rosters_employee_read on public.monthly_rosters
  for select to authenticated
  using (public.current_app_role() = 'employee' and employee_id = public.current_employee_id());
