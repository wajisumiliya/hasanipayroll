alter table public.employee_salary_defaults
  add column if not exists address text;

comment on column public.employee_salary_defaults.address is
  'Payroll statutory nationality marker. FRN identifies foreign employees.';

update public.employee_salary_defaults as salary_defaults
   set address = employees.address
  from public.employees as employees
 where upper(trim(employees.employee_id)) =
       upper(trim(salary_defaults.employee_id))
   and coalesce(trim(salary_defaults.address), '') = ''
   and coalesce(trim(employees.address), '') <> '';

notify pgrst, 'reload schema';
