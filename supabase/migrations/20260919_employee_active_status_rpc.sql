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

  update public.app_user
     set "isActive" = p_is_active,
         "updatedAt" = now()
   where upper(trim(coalesce("employeeId", ''))) =
         upper(wanted_employee_id);
end;
$$;

revoke all on function public.set_employee_active_status(text, boolean)
  from public, anon;
grant execute on function public.set_employee_active_status(text, boolean)
  to authenticated;
