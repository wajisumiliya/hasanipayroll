-- Record when an employee is marked as resigned and permanently remove their
-- database records after the 90-day retention period.

alter table public.employees
  add column if not exists resigned_at timestamptz;

comment on column public.employees.resigned_at is
  'Time the employee was marked inactive/resigned. The automatic purge runs after 90 days.';

create or replace function public.sync_employee_resigned_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.is_active then
    new.resigned_at := null;
  elsif tg_op = 'INSERT' or old.is_active or old.resigned_at is null then
    new.resigned_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists employees_sync_resigned_at on public.employees;
create trigger employees_sync_resigned_at
before insert or update on public.employees
for each row
execute function public.sync_employee_resigned_at();

-- Existing inactive employees begin their retention period when this migration
-- is deployed. This avoids immediately deleting historical records whose true
-- resignation date was never recorded.
update public.employees
set resigned_at = now()
where is_active = false
  and resigned_at is null;

create index if not exists employees_resigned_purge_idx
  on public.employees (resigned_at)
  where is_active = false and resigned_at is not null;

create or replace function public.purge_resigned_employees()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  resigned_employee record;
  purged_count integer := 0;
  app_user_employee_column text;
begin
  -- Support both app_user column layouts used by existing deployments.
  select case
           when exists (
             select 1
             from information_schema.columns
             where table_schema = 'public'
               and table_name = 'app_user'
               and column_name = 'employee_id'
           ) then 'employee_id'
           when exists (
             select 1
             from information_schema.columns
             where table_schema = 'public'
               and table_name = 'app_user'
               and column_name = 'employeeId'
           ) then 'employeeId'
           else null
         end
    into app_user_employee_column;

  for resigned_employee in
    select employee_id
    from public.employees
    where is_active = false
      and resigned_at is not null
      and resigned_at <= now() - interval '90 days'
    for update skip locked
  loop
    -- Delete children before the employee row so this also works with legacy
    -- tables that do not have ON DELETE CASCADE constraints.
    delete from public.notification_reads
     where employee_id = resigned_employee.employee_id;
    delete from public.notification_devices
     where employee_id = resigned_employee.employee_id;
    delete from public.app_notifications
     where employee_id = resigned_employee.employee_id;
    delete from public.employee_aquarium_logins
     where employee_id = resigned_employee.employee_id;
    delete from public.employee_aquariums
     where employee_id = resigned_employee.employee_id;
    delete from public.employee_ea_forms
     where employee_id = resigned_employee.employee_id;
    delete from public.leave_requests
     where employee_id = resigned_employee.employee_id;
    delete from public.overtime_requests
     where employee_id = resigned_employee.employee_id;
    delete from public.daily_rosters
     where employee_id = resigned_employee.employee_id;
    delete from public.monthly_rosters
     where employee_id = resigned_employee.employee_id;
    delete from public.staff_transfer_history
     where employee_id = resigned_employee.employee_id;
    delete from public.employee_salary_defaults
     where employee_id = resigned_employee.employee_id;
    delete from public.attendance
     where employee_id = resigned_employee.employee_id;
    delete from public.payroll
     where employee_id = resigned_employee.employee_id;
    delete from public.branch_activity_logs
     where employee_id = resigned_employee.employee_id;
    delete from public.employee_requests
     where assigned_employee_id = resigned_employee.employee_id;

    if app_user_employee_column is not null then
      execute format(
        'delete from public.app_user where upper(trim(coalesce(%I::text, ''''))) = upper($1)',
        app_user_employee_column
      ) using resigned_employee.employee_id;
    end if;

    delete from public.employees
     where employee_id = resigned_employee.employee_id
       and is_active = false
       and resigned_at <= now() - interval '90 days';

    if found then
      purged_count := purged_count + 1;
    end if;
  end loop;

  return purged_count;
end;
$$;

comment on function public.purge_resigned_employees() is
  'Permanently deletes employees and linked database records 90 days after resignation.';

revoke all on function public.sync_employee_resigned_at() from public, anon, authenticated;
revoke all on function public.purge_resigned_employees() from public, anon, authenticated;
grant execute on function public.purge_resigned_employees() to service_role;

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'purge-resigned-employees-after-90-days',
  '15 2 * * *',
  $$select public.purge_resigned_employees();$$
);
