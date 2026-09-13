alter table public.employee_salary_defaults
  add column if not exists zakat numeric(12, 2) not null default 0;

alter table public.payroll
  add column if not exists advance numeric(12, 2) not null default 0;

comment on column public.employee_salary_defaults.zakat is
  'Default monthly employee Zakat deduction copied into generated payroll.';

comment on column public.payroll.advance is
  'Monthly employee salary advance deduction.';

notify pgrst, 'reload schema';
