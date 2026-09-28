-- Require an authenticated employee identity for the company login-tree summary.
-- The function remains SECURITY DEFINER because its backing log table is
-- intentionally hidden from API roles.

create or replace function public.get_company_login_tree()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null
     or public.current_app_role() <> 'employee'
     or nullif(trim(public.current_employee_id()), '') is null then
    raise exception 'Employee access required';
  end if;

  return (
    select jsonb_build_object(
      'totalGrowth', count(*),
      'todayGrowth', count(*) filter (
        where login_date = (now() at time zone 'Asia/Kuala_Lumpur')::date
      ),
      'contributors', count(distinct employee_id),
      'asOfDate', (now() at time zone 'Asia/Kuala_Lumpur')::date
    )
    from public.company_tree_daily_logins
  );
end;
$$;

revoke execute on function public.get_company_login_tree() from public, anon;
grant execute on function public.get_company_login_tree() to authenticated;

-- Reassert that no internal SECURITY DEFINER helpers are directly API-callable.
revoke execute on function public.apply_approved_overtime_request()
  from public, anon, authenticated;
revoke execute on function public.apply_employee_aquarium_decay(text)
  from public, anon, authenticated;
revoke execute on function public.approve_employee_request_internal(uuid, text)
  from public, anon, authenticated;
revoke execute on function public.audit_branch_data_change()
  from public, anon, authenticated;
revoke execute on function public.process_historical_payroll_components()
  from public, anon, authenticated;
revoke execute on function public.process_historical_statutory_import()
  from public, anon, authenticated;
