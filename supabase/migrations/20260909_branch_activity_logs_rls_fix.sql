-- Restore branch activity logging after the RLS lockdown and tolerate harmless
-- casing/whitespace differences between stored branch IDs and JWT claims.
alter table public.branch_activity_logs enable row level security;

drop policy if exists "branch activity app access" on public.branch_activity_logs;
drop policy if exists branch_logs_admin_read on public.branch_activity_logs;
drop policy if exists branch_logs_branch_insert on public.branch_activity_logs;
drop policy if exists branch_logs_branch_update on public.branch_activity_logs;

create policy branch_logs_admin_read on public.branch_activity_logs
  for select to authenticated
  using (public.current_app_role() in ('admin', 'administrator'));

create policy branch_logs_branch_insert on public.branch_activity_logs
  for insert to authenticated
  with check (
    public.current_app_role() = 'branch'
    and lower(trim(branch_id)) = lower(trim(public.current_branch_id()))
  );

create policy branch_logs_branch_update on public.branch_activity_logs
  for update to authenticated
  using (
    public.current_app_role() = 'branch'
    and lower(trim(branch_id)) = lower(trim(public.current_branch_id()))
  )
  with check (
    lower(trim(branch_id)) = lower(trim(public.current_branch_id()))
  );