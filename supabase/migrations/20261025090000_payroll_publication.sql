alter table public.payroll
  add column if not exists is_published boolean not null default false,
  add column if not exists published_at timestamptz,
  add column if not exists published_by text;

comment on column public.payroll.is_published is
  'Controls whether an employee may view this payroll record and payslip.';

create index if not exists payroll_employee_published_period_idx
  on public.payroll (employee_id, is_published, period desc);

-- Replace the consolidated read policy so employees can only access payroll
-- explicitly published by an administrator. Admin and branch access remains
-- unchanged for payroll preparation and review.
drop policy if exists payroll_read on public.payroll;
create policy payroll_read on public.payroll
for select to authenticated
using (
  public.current_app_role() = 'admin'
  or (
    public.current_app_role() = 'branch'
    and exists (
      select 1
      from public.employees e
      where e.employee_id = payroll.employee_id
        and e.branch_id = public.current_branch_id()
    )
  )
  or (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
    and is_published = true
  )
);
