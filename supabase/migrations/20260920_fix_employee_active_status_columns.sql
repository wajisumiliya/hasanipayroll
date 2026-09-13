create or replace function public.set_employee_active_status(
  p_employee_id text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  wanted_employee_id text := trim(coalesce(p_employee_id, ''));
  account_employee_column text;
  account_active_column text;
  account_updated_column text;
  updated_assignment text := '';
begin
  if public.current_app_role() not in ('admin', 'administrator') then
    raise exception 'Administrator access required';
  end if;

  if wanted_employee_id = '' or p_is_active is null then
    raise exception 'Employee ID and active status are required';
  end if;

  update public.employees
     set is_active = p_is_active
   where upper(trim(employee_id)) = upper(wanted_employee_id);

  if not found then
    raise exception 'Employee % was not found', wanted_employee_id;
  end if;

  select case
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'employee_id'
           ) then 'employee_id'
           else 'employeeId'
         end,
         case
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'is_active'
           ) then 'is_active'
           else 'isActive'
         end,
         case
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'updated_at'
           ) then 'updated_at'
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'updatedAt'
           ) then 'updatedAt'
           else null
         end
    into account_employee_column, account_active_column, account_updated_column;

  if account_updated_column is not null then
    updated_assignment := format(', %I = now()', account_updated_column);
  end if;

  execute format(
    'update public.app_user set %I = $1%s '
    'where upper(trim(coalesce(%I::text, ''''))) = upper($2)',
    account_active_column,
    updated_assignment,
    account_employee_column
  ) using p_is_active, wanted_employee_id;
end;
$$;

revoke all on function public.set_employee_active_status(text, boolean)
  from public, anon;
grant execute on function public.set_employee_active_status(text, boolean)
  to authenticated;
