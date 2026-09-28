-- Consolidate attendance RLS so branch row integrity cannot be bypassed
-- through overlapping permissive policies. PostgreSQL ORs permissive policies.

drop policy if exists attendance_branch_all on public.attendance;
drop policy if exists attendance_insert on public.attendance;
drop policy if exists attendance_update on public.attendance;
drop policy if exists attendance_delete on public.attendance;

create policy attendance_insert on public.attendance
  for insert to authenticated
  with check (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  );

create policy attendance_update on public.attendance
  for update to authenticated
  using (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  )
  with check (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  );

create policy attendance_delete on public.attendance
  for delete to authenticated
  using (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  );
