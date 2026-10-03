-- Store food allowance independently from diligence allowance.
alter table public.employee_salary_defaults
  add column if not exists elaun_makanan numeric(12, 2) not null default 0;

alter table public.payroll
  add column if not exists elaun_makanan numeric(12, 2) not null default 0;

comment on column public.employee_salary_defaults.elaun_makanan is
  'Default monthly food allowance copied into generated payroll.';

comment on column public.payroll.elaun_makanan is
  'Monthly food allowance.';

-- FRN marks a foreign employee. Their existing diligence allowance is food
-- allowance, so move it once and leave ELAUN KERAJINAN for local employees.
update public.employee_salary_defaults as defaults
   set elaun_makanan = coalesce(defaults.elaun_makanan, 0) +
                       coalesce(defaults.elaun_kerajinan, 0),
       elaun_kerajinan = 0
  from public.employees as employees
 where upper(trim(employees.employee_id)) = upper(trim(defaults.employee_id))
   and upper(concat_ws(' ', defaults.address, employees.address)) like '%FRN%'
   and coalesce(defaults.elaun_kerajinan, 0) <> 0;

update public.payroll as payroll
   set elaun_makanan = coalesce(payroll.elaun_makanan, 0) +
                       coalesce(payroll.elaun_kerajinan, 0),
       elaun_kerajinan = 0
  from public.employees as employees
  left join public.employee_salary_defaults as defaults
    on upper(trim(defaults.employee_id)) = upper(trim(employees.employee_id))
 where upper(trim(employees.employee_id)) = upper(trim(payroll.employee_id))
   and upper(concat_ws(' ', defaults.address, employees.address)) like '%FRN%'
   and coalesce(payroll.elaun_kerajinan, 0) <> 0;

notify pgrst, 'reload schema';
