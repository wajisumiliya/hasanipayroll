-- Harden branch attendance writes.
-- A branch may only create/update attendance rows whose employee AND stored
-- branch_id both belong to the authenticated branch. This prevents an
-- internally inconsistent branch_id from being written while preserving the
-- existing Admin/Branch/Employee access model.

drop policy if exists attendance_branch_all on public.attendance;

create policy attendance_branch_all on public.attendance
  for all
  to authenticated
  using (
    public.current_app_role() = 'branch'
    and branch_id = public.current_branch_id()
    and exists (
      select 1
      from public.employees e
      where e.employee_id = attendance.employee_id
        and e.branch_id = public.current_branch_id()
    )
  )
  with check (
    public.current_app_role() = 'branch'
    and branch_id = public.current_branch_id()
    and exists (
      select 1
      from public.employees e
      where e.employee_id = attendance.employee_id
        and e.branch_id = public.current_branch_id()
    )
  );

-- Reassert the employee-request approval execution boundary in the final
-- migration state. The public wrapper performs the trusted admin-role check;
-- its SECURITY DEFINER implementation is not directly API-callable.
revoke execute on function public.approve_employee_request_internal(uuid, text)
  from public, anon, authenticated;

revoke execute on function public.approve_employee_request(uuid, text)
  from public, anon;
grant execute on function public.approve_employee_request(uuid, text)
  to authenticated;
