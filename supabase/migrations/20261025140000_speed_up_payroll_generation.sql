-- Support bulk payroll generation and conflict-safe batch upserts.

create unique index if not exists payroll_employee_period_unique_idx
  on public.payroll (employee_id, period);

create index if not exists attendance_employee_date_idx
  on public.attendance (employee_id, attendance_date);

create index if not exists salary_defaults_employee_idx
  on public.employee_salary_defaults (employee_id);

create index if not exists monthly_rosters_employee_period_idx
  on public.monthly_rosters (employee_id, roster_year, roster_month);

notify pgrst, 'reload schema';
