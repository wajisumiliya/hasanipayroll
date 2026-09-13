alter table public.employees
  add column if not exists is_temp_staff boolean not null default false;

create index if not exists employees_temp_staff_idx
  on public.employees (is_temp_staff, is_active);

comment on column public.employees.is_temp_staff is
  'Temporary staff are excluded from branch attendance and use salary defaults without attendance-based payroll adjustments.';
