alter table public.employee_salary_defaults
  add column if not exists pcb numeric(12, 2) not null default 0;

comment on column public.employee_salary_defaults.pcb is
  'Default monthly employee PCB deduction copied into generated payroll.';

notify pgrst, 'reload schema';
