-- Daily-report count cells are operational notes, not calculations. Allow
-- values such as `11/15`, `X`, or `N/A` and retain existing numeric data.
alter table public.daily_reports
  alter column attendance drop default,
  alter column unpaid_leave drop default,
  alter column weekly_leave drop default,
  alter column annual_leave drop default,
  alter column maintenance_total drop default,
  alter column working_condition drop default,
  alter column service_repair drop default,
  alter column attendance type text using attendance::text,
  alter column unpaid_leave type text using unpaid_leave::text,
  alter column weekly_leave type text using weekly_leave::text,
  alter column annual_leave type text using annual_leave::text,
  alter column maintenance_total type text using maintenance_total::text,
  alter column working_condition type text using working_condition::text,
  alter column service_repair type text using service_repair::text,
  alter column attendance set default '',
  alter column unpaid_leave set default '',
  alter column weekly_leave set default '',
  alter column annual_leave set default '',
  alter column maintenance_total set default '',
  alter column working_condition set default '',
  alter column service_repair set default '';
