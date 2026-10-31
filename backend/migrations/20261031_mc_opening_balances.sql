ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS medical_leave_opening_month date
    CHECK (EXTRACT(DAY FROM medical_leave_opening_month) = 1);
CREATE TABLE IF NOT EXISTS app_private.employee_mc_openings (
  employee_id text NOT NULL REFERENCES public.employees(employee_id) ON DELETE CASCADE,
  opening_month date NOT NULL CHECK (EXTRACT(DAY FROM opening_month) = 1),
  balance numeric(6,2) NOT NULL CHECK (balance >= 0 AND balance < 10000),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (employee_id, opening_month)
);
REVOKE ALL ON app_private.employee_mc_openings FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION app_private.capture_employee_mc_opening()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
  IF NEW.medical_leave_balance IS NOT NULL AND NEW.medical_leave_opening_month IS NOT NULL THEN
    INSERT INTO app_private.employee_mc_openings(employee_id, opening_month, balance)
    VALUES (NEW.employee_id, NEW.medical_leave_opening_month, NEW.medical_leave_balance)
    ON CONFLICT (employee_id, opening_month) DO UPDATE
      SET balance = EXCLUDED.balance, updated_at = now();
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION app_private.capture_employee_mc_opening() FROM PUBLIC;
DROP TRIGGER IF EXISTS employee_mc_opening_capture ON public.employees;
CREATE TRIGGER employee_mc_opening_capture
AFTER INSERT OR UPDATE OF medical_leave_balance, medical_leave_opening_month ON public.employees
FOR EACH ROW EXECUTE FUNCTION app_private.capture_employee_mc_opening();
-- User-confirmed opening period for balances already uploaded before this migration.
UPDATE public.employees SET medical_leave_opening_month = DATE '2026-10-01'
WHERE medical_leave_balance IS NOT NULL AND medical_leave_opening_month IS NULL;
INSERT INTO app_private.employee_mc_openings(employee_id, opening_month, balance)
SELECT employee_id, medical_leave_opening_month, medical_leave_balance FROM public.employees
WHERE medical_leave_opening_month IS NOT NULL AND medical_leave_balance IS NOT NULL
ON CONFLICT (employee_id, opening_month) DO NOTHING;
