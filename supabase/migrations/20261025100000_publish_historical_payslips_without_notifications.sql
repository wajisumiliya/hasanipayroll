-- Publish historical payslips for employee access without creating
-- app notifications. The upper bound is exclusive so the range includes
-- every payroll month from January 2023 through August 2026.

update public.payroll
set
  is_published = true,
  published_at = coalesce(published_at, now()),
  published_by = coalesce(published_by, 'historical_bulk_publish')
where period::timestamp >= timestamp '2023-01-01 00:00:00'
  and period::timestamp < timestamp '2026-09-01 00:00:00'
  and is_published = false;

