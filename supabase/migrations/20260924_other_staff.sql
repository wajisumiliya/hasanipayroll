alter table public.employees
  add column if not exists is_other_staff boolean not null default false;

create index if not exists employees_other_staff_idx
  on public.employees (is_other_staff, is_active);

comment on column public.employees.is_other_staff is
  'Administrative Other Staff category. Other Staff remain eligible for attendance and HRDF unless excluded by another category.';

notify pgrst, 'reload schema';
