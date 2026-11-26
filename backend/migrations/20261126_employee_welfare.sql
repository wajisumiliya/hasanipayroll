CREATE TABLE IF NOT EXISTS app_private.employee_welfare (
  source_key text PRIMARY KEY CHECK (length(source_key)=64),
  employee_id text NOT NULL REFERENCES public.employees(employee_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  payment_date date NOT NULL,
  particulars text NOT NULL CHECK (length(particulars) BETWEEN 1 AND 2000),
  amount numeric(14,2) NOT NULL CHECK (amount>=0),
  reference text NOT NULL DEFAULT '',
  project text NOT NULL DEFAULT '',
  imported_by text NOT NULL,
  imported_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS employee_welfare_employee_date ON app_private.employee_welfare(employee_id,payment_date);
REVOKE ALL ON app_private.employee_welfare FROM PUBLIC;
