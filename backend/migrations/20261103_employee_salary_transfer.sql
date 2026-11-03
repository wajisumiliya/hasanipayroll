ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS salary_transfer_method text;
UPDATE public.employees SET salary_transfer_method = 'rhb'
WHERE salary_transfer_method IS NULL AND NULLIF(BTRIM(bank_account), '') IS NOT NULL;
ALTER TABLE public.employees ADD CONSTRAINT employees_salary_transfer_method_check
CHECK (salary_transfer_method IS NULL OR salary_transfer_method IN ('rhb', 'instant', 'cash'));

-- Apply the default to future imports and edits as well as existing employees.
CREATE OR REPLACE FUNCTION app_private.default_employee_salary_transfer()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  NEW.salary_transfer_method := NULLIF(LOWER(BTRIM(NEW.salary_transfer_method)), '');
  IF NEW.salary_transfer_method IS NULL AND NULLIF(BTRIM(NEW.bank_account), '') IS NOT NULL THEN
    NEW.salary_transfer_method := 'rhb';
  ELSIF NEW.salary_transfer_method = 'rhb' AND NULLIF(BTRIM(NEW.bank_account), '') IS NULL THEN
    NEW.salary_transfer_method := NULL;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER employees_salary_transfer_default
BEFORE INSERT OR UPDATE OF bank_account, salary_transfer_method ON public.employees
FOR EACH ROW EXECUTE FUNCTION app_private.default_employee_salary_transfer();
