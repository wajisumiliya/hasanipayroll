-- Deny anonymous access to all payroll identity and HR data. Application
-- authorization must be expressed in trusted JWT app_metadata claims.

create or replace function public.current_app_role()
returns text language sql stable as $$
  select lower(coalesce(
    auth.jwt() -> 'app_metadata' ->> 'app_role',
    auth.jwt() -> 'app_metadata' ->> 'role',
    ''
  ));
$$;

create or replace function public.current_branch_id()
returns text language sql stable as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'branch_id', '');
$$;

create or replace function public.current_employee_id()
returns text language sql stable as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'employee_id', '');
$$;

create or replace function public.current_is_frn()
returns boolean language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'is_frn')::boolean, false);
$$;

do $$
declare
  table_name text;
  policy_row record;
begin
  foreach table_name in array array[
    'app_user', 'users', 'employees', 'payroll', 'attendance',
    'employee_requests', 'branch_activity_logs'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      execute format('alter table public.%I enable row level security', table_name);
      execute format('revoke all on table public.%I from anon', table_name);
      for policy_row in
        select policyname from pg_policies
        where schemaname = 'public' and tablename = table_name
      loop
        execute format('drop policy if exists %I on public.%I', policy_row.policyname, table_name);
      end loop;
    end if;
  end loop;
end $$;

-- Remove legacy plaintext credential columns. Run only after confirming the
-- backend app_user table contains passwordHash values for every active user.
alter table if exists public.app_user drop column if exists password;
alter table if exists public.users drop column if exists password;

-- Account records are backend-managed. Even authenticated clients cannot read
-- password hashes or account administration data directly.
revoke all on table public.app_user from authenticated;
do $$ begin
  if to_regclass('public.users') is not null then
    revoke all on table public.users from authenticated;
  end if;
end $$;

create policy employees_admin_all on public.employees
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');
create policy employees_branch_read on public.employees
  for select to authenticated
  using (public.current_app_role() = 'branch'
    and branch_id = public.current_branch_id()
    and ((public.current_is_frn() and coalesce(address, '') ilike '%FRN%')
      or (not public.current_is_frn() and coalesce(address, '') not ilike '%FRN%')));
create policy employees_branch_update on public.employees
  for update to authenticated
  using (public.current_app_role() = 'branch'
    and branch_id = public.current_branch_id()
    and ((public.current_is_frn() and coalesce(address, '') ilike '%FRN%')
      or (not public.current_is_frn() and coalesce(address, '') not ilike '%FRN%')))
  with check (branch_id = public.current_branch_id()
    and ((public.current_is_frn() and coalesce(address, '') ilike '%FRN%')
      or (not public.current_is_frn() and coalesce(address, '') not ilike '%FRN%')));
create policy employees_self_read on public.employees
  for select to authenticated
  using (public.current_app_role() = 'employee' and employee_id = public.current_employee_id());

create policy attendance_admin_all on public.attendance
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');
create policy attendance_branch_all on public.attendance
  for all to authenticated
  using (public.current_app_role() = 'branch' and exists (
    select 1 from public.employees e where e.employee_id = attendance.employee_id
      and e.branch_id = public.current_branch_id()
  ))
  with check (public.current_app_role() = 'branch' and exists (
    select 1 from public.employees e where e.employee_id = attendance.employee_id
      and e.branch_id = public.current_branch_id()
  ));
create policy attendance_self_read on public.attendance
  for select to authenticated
  using (public.current_app_role() = 'employee' and employee_id = public.current_employee_id());

create policy payroll_admin_all on public.payroll
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');
create policy payroll_branch_read on public.payroll
  for select to authenticated
  using (public.current_app_role() = 'branch' and exists (
    select 1 from public.employees e where e.employee_id = payroll.employee_id
      and e.branch_id = public.current_branch_id()
  ));
create policy payroll_self_read on public.payroll
  for select to authenticated
  using (public.current_app_role() = 'employee' and employee_id = public.current_employee_id());

create policy employee_requests_admin_all on public.employee_requests
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');
create policy employee_requests_branch_read on public.employee_requests
  for select to authenticated
  using (public.current_app_role() = 'branch' and branch_id = public.current_branch_id());
create policy employee_requests_branch_insert on public.employee_requests
  for insert to authenticated
  with check (public.current_app_role() = 'branch' and branch_id = public.current_branch_id());

create policy branch_logs_admin_read on public.branch_activity_logs
  for select to authenticated
  using (public.current_app_role() = 'admin');
create policy branch_logs_branch_insert on public.branch_activity_logs
  for insert to authenticated
  with check (public.current_app_role() = 'branch' and branch_id = public.current_branch_id());
create policy branch_logs_branch_update on public.branch_activity_logs
  for update to authenticated
  using (public.current_app_role() = 'branch' and branch_id = public.current_branch_id())
  with check (branch_id = public.current_branch_id());

alter function public.approve_employee_request(uuid, text)
  rename to approve_employee_request_internal;
revoke execute on function public.approve_employee_request_internal(uuid, text)
  from public, anon, authenticated;

create function public.approve_employee_request(request_id uuid, new_employee_id text)
returns public.employees
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() <> 'admin' then
    raise exception 'Administrator access required.';
  end if;
  return public.approve_employee_request_internal(request_id, new_employee_id);
end;
$$;

revoke execute on function public.approve_employee_request(uuid, text)
  from public, anon;
grant execute on function public.approve_employee_request(uuid, text)
  to authenticated, service_role;
