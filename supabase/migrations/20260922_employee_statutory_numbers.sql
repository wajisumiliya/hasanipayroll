alter table public.employees
  add column if not exists epf_no text,
  add column if not exists socso_no text;

comment on column public.employees.epf_no is
  'Employee EPF/KWSP membership number, stored as text to preserve leading zeros.';

comment on column public.employees.socso_no is
  'Employee SOCSO membership number, stored as text to preserve leading zeros.';
