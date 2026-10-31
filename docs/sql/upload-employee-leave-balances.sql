-- First run backend/migrations/20261031_employee_leave_balances.sql.
-- Replace the placeholder IDs and sample day balances with YOUR actual data.
-- NULL means not set; 0 means a confirmed zero balance. Half days are allowed.
BEGIN;
CREATE TEMP TABLE leave_balance_upload (
  employee_id text PRIMARY KEY,
  annual_leave_balance numeric(6,2),
  medical_leave_balance numeric(6,2)
) ON COMMIT DROP;

INSERT INTO leave_balance_upload (employee_id, annual_leave_balance, medical_leave_balance)
VALUES
  ('REPLACE_WITH_EMPLOYEE_ID_1', 14.00, 14.00),
  ('REPLACE_WITH_EMPLOYEE_ID_2', 10.50, 12.00);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM leave_balance_upload GROUP BY UPPER(TRIM(employee_id)) HAVING COUNT(*) > 1) THEN
    RAISE EXCEPTION 'Duplicate employee IDs in leave balance upload';
  END IF;
  IF EXISTS (
    SELECT 1 FROM leave_balance_upload u LEFT JOIN public.employees e
      ON UPPER(TRIM(e.employee_id)) = UPPER(TRIM(u.employee_id))
    WHERE e.employee_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Upload cancelled: an employee ID does not exist. Replace placeholders and check all IDs.';
  END IF;
END $$;

UPDATE public.employees e
SET annual_leave_balance = u.annual_leave_balance,
    medical_leave_balance = u.medical_leave_balance
FROM leave_balance_upload u
WHERE UPPER(TRIM(e.employee_id)) = UPPER(TRIM(u.employee_id));

SELECT e.employee_id, e.name, e.annual_leave_balance, e.medical_leave_balance
FROM public.employees e JOIN leave_balance_upload u
  ON UPPER(TRIM(e.employee_id)) = UPPER(TRIM(u.employee_id))
ORDER BY e.employee_id;
COMMIT;
