-- Report grouping only: employee/payroll/attendance records stay unchanged.
CREATE TABLE IF NOT EXISTS app_private.salary_report_branch_assignments (
  employee_id text NOT NULL REFERENCES public.employees(employee_id) ON UPDATE CASCADE ON DELETE CASCADE,
  period date NOT NULL CHECK (period = date_trunc('month', period)::date),
  branch_id text NOT NULL REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  assigned_by text NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (employee_id, period)
);
REVOKE ALL ON app_private.salary_report_branch_assignments FROM PUBLIC;
-- Preserve the previously confirmed BAS025 correction as editable assignments.
INSERT INTO app_private.salary_report_branch_assignments(employee_id,period,branch_id,assigned_by)
SELECT e.employee_id,m.period::date,b.id,'historical-correction'
FROM public.employees e
CROSS JOIN generate_series(DATE '2025-07-01',DATE '2026-06-01',INTERVAL '1 month') AS m(period)
CROSS JOIN (SELECT min(id) AS id FROM public.branches
  WHERE upper(trim(name))='GURUN' OR upper(trim(id))='GURUN'
  HAVING count(*)=1) b
WHERE e.employee_id='BAS025'
ON CONFLICT (employee_id,period) DO NOTHING;
