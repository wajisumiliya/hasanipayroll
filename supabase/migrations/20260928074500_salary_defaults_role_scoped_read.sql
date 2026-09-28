-- Salary defaults contain payroll-sensitive data. Replace legacy broad read
-- policies with role-scoped access while preserving existing application flows.

drop policy if exists "employee_salary_defaults_read"
  on public.employee_salary_defaults;
drop policy if exists "allow authenticated read salary defaults"
  on public.employee_salary_defaults;

create policy employee_salary_defaults_role_read
on public.employee_salary_defaults
for select to authenticated
using (
  public.current_app_role() in ('admin','administrator')
  or (
    public.current_app_role() = 'branch'
    and exists (
      select 1
      from public.employees e
      where e.employee_id = employee_salary_defaults.employee_id
        and public.normalized_branch_key(e.branch_id) =
            public.normalized_branch_key(public.current_branch_id())
    )
  )
  or (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  )
);
