ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS annual_leave_balance numeric(6,2)
    CONSTRAINT employees_annual_leave_balance_valid CHECK (annual_leave_balance >= 0 AND annual_leave_balance < 10000),
  ADD COLUMN IF NOT EXISTS medical_leave_balance numeric(6,2)
    CONSTRAINT employees_medical_leave_balance_valid CHECK (medical_leave_balance >= 0 AND medical_leave_balance < 10000);
COMMENT ON COLUMN public.employees.annual_leave_balance IS 'Admin-maintained AL balance in days; NULL means not uploaded.';
COMMENT ON COLUMN public.employees.medical_leave_balance IS 'Admin-only MC balance in days; NULL means not uploaded.';
