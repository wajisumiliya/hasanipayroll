alter table public.employees
  add column if not exists payroll_branch_id text;

comment on column public.employees.payroll_branch_id is
  'Optional permanent payroll-only branch. Attendance continues to use branch_id.';

create index if not exists employees_payroll_branch_id_idx
  on public.employees (payroll_branch_id);
