alter table public.employees
  add column if not exists is_support_staff boolean not null default false;

create index if not exists employees_support_staff_active_idx
  on public.employees (is_support_staff, is_active);

comment on column public.employees.is_support_staff is
  'Payroll-only support staff excluded from branch attendance.';
