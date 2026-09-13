alter table public.employee_salary_defaults enable row level security;

revoke all on table public.employee_salary_defaults from anon;
grant select, insert, update, delete
  on table public.employee_salary_defaults
  to authenticated;

drop policy if exists employee_salary_defaults_admin_all
  on public.employee_salary_defaults;

create policy employee_salary_defaults_admin_all
  on public.employee_salary_defaults
  for all
  to authenticated
  using (public.current_app_role() in ('admin', 'administrator'))
  with check (public.current_app_role() in ('admin', 'administrator'));
