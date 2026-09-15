alter table public.employee_salary_defaults
  add column if not exists epf_enabled boolean not null default true,
  add column if not exists eis_enabled boolean not null default true,
  add column if not exists socso_enabled boolean not null default true,
  add column if not exists socso_category text not null default 'type1';

update public.employee_salary_defaults
set epf_enabled = true
where epf_enabled is null;

update public.employee_salary_defaults
set eis_enabled = true
where eis_enabled is null;

update public.employee_salary_defaults
set socso_enabled = true
where socso_enabled is null;

update public.employee_salary_defaults
set socso_category = 'type1'
where socso_category is null
   or socso_category not in ('type1', 'type2');

alter table public.employee_salary_defaults
  drop constraint if exists employee_salary_defaults_socso_category_check;

alter table public.employee_salary_defaults
  add constraint employee_salary_defaults_socso_category_check
  check (socso_category in ('type1', 'type2'));

comment on column public.employee_salary_defaults.epf_enabled is
  'Whether EPF employee and employer contributions are calculated.';
comment on column public.employee_salary_defaults.eis_enabled is
  'Whether EIS employee and employer contributions are calculated.';
comment on column public.employee_salary_defaults.socso_enabled is
  'Whether SOCSO employee and employer contributions are calculated.';
comment on column public.employee_salary_defaults.socso_category is
  'SOCSO contribution category: type1 or type2 (employer only).';

notify pgrst, 'reload schema';
