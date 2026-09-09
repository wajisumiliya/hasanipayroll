alter table public.employees
  add column if not exists is_management_staff boolean not null default false;

create index if not exists employees_management_staff_idx
  on public.employees (is_management_staff, is_active);

comment on column public.employees.is_management_staff is
  'Management staff are excluded from branch attendance and use salary defaults without attendance-based payroll adjustments.';