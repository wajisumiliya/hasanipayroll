alter table public.employees
  add column if not exists first_name text,
  add column if not exists last_name text;

comment on column public.employees.first_name is
  'First/given name for foreign (FRN) employees.';

comment on column public.employees.last_name is
  'Last/family name for foreign (FRN) employees. Printed before first_name on statutory reports.';
