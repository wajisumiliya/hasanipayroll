create table if not exists public.daily_rosters (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null,
  employee_id text not null,
  roster_date date not null,
  assignment_type text not null check (assignment_type in ('SHIFT','OFF','MC','PL','AL','EL','PH','UNPAID')),
  shift_start time,
  shift_end time,
  break_minutes integer not null default 0 check (break_minutes between 0 and 720),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, employee_id, roster_date),
  check (
    (assignment_type = 'SHIFT' and shift_start is not null and shift_end is not null)
    or (assignment_type <> 'SHIFT' and shift_start is null and shift_end is null)
  )
);

create index if not exists daily_rosters_employee_period_idx
  on public.daily_rosters (branch_id, employee_id, roster_date);

alter table public.daily_rosters enable row level security;
revoke all on table public.daily_rosters from anon;
grant select, insert, update, delete on table public.daily_rosters to authenticated;

drop policy if exists daily_rosters_admin_all on public.daily_rosters;
create policy daily_rosters_admin_all on public.daily_rosters
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');

drop policy if exists daily_rosters_branch_all on public.daily_rosters;
create policy daily_rosters_branch_all on public.daily_rosters
  for all to authenticated
  using (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  )
  with check (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  );

drop policy if exists daily_rosters_employee_read on public.daily_rosters;
create policy daily_rosters_employee_read on public.daily_rosters
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );