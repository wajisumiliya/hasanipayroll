-- Historical reconciliation entries only. No live payroll or employee writes.
CREATE TABLE IF NOT EXISTS app_private.salary_report_temporary_payroll (
  employee_id text NOT NULL CHECK (length(trim(employee_id)) BETWEEN 1 AND 100),
  period date NOT NULL CHECK (period=date_trunc('month',period)::date),
  employee_name text NOT NULL CHECK (length(trim(employee_name)) BETWEEN 1 AND 200),
  branch_id text NOT NULL REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  staff_scope text NOT NULL CHECK (staff_scope IN ('local','foreign')),
  basic_salary numeric(12,2) NOT NULL CHECK (basic_salary>=0),
  allowances numeric(12,2) NOT NULL CHECK (allowances>=0),
  other_earnings numeric(12,2) NOT NULL CHECK (other_earnings>=0),
  deductions numeric(12,2) NOT NULL CHECK (deductions>=0),
  amount numeric(14,2) GENERATED ALWAYS AS (basic_salary+allowances+other_earnings-deductions) STORED,
  notes text NOT NULL DEFAULT '' CHECK (length(notes)<=2000),
  created_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_by text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(employee_id,period)
);
REVOKE ALL ON app_private.salary_report_temporary_payroll FROM PUBLIC;
