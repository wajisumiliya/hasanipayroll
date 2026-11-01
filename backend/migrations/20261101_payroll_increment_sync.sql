-- Preserve pre-payroll eligibility while maintaining the latest verified increment.
CREATE TABLE IF NOT EXISTS app_private.payroll_increment_state (
  employee_id text NOT NULL REFERENCES public.employees(employee_id) ON DELETE CASCADE,
  period date NOT NULL,
  inc_details_before text,
  joining_date_before date,
  detected_amount numeric(14,2),
  applied_inc_details text,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY(employee_id,period)
);
REVOKE ALL ON app_private.payroll_increment_state FROM PUBLIC;
DO $$ DECLARE r text; BEGIN
  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r) THEN
      EXECUTE format('REVOKE ALL ON app_private.payroll_increment_state FROM %I',r);
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION app_private.increment_reference_month(value text)
RETURNS date LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE parts text[]; month_number integer; year_number integer;
BEGIN
  parts=regexp_match(upper(trim(value)), '^([A-Z]{3,4})[-/]([0-9]{4}|[0-9]{2})([^0-9]|$)');
  IF parts IS NULL THEN RETURN NULL; END IF;
  month_number=array_position(ARRAY['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'],CASE WHEN parts[1]='SEPT' THEN 'SEP' ELSE parts[1] END);
  IF month_number IS NULL THEN RETURN NULL; END IF;
  year_number=parts[2]::integer;
  IF length(parts[2])=2 THEN year_number=2000+year_number; END IF;
  IF year_number<1 OR year_number>9999 THEN RETURN NULL; END IF;
  RETURN make_date(year_number,month_number,1);
END $$;

CREATE OR REPLACE FUNCTION app_private.sync_payroll_increment(target_employee text,target_period date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  month_date date=date_trunc('month',target_period)::date;
  current_details text; join_date date; state_row app_private.payroll_increment_state%ROWTYPE;
  current_pay record; previous_pay record; row_count integer; amount numeric(14,2); label text;
BEGIN
  -- Salary-default row locks serialize all increment metadata writes for an employee.
  SELECT d.inc_details,e.joining_date INTO current_details,join_date
    FROM public.employee_salary_defaults d JOIN public.employees e ON e.employee_id=d.employee_id
    WHERE d.employee_id=target_employee FOR UPDATE OF d;
  IF NOT FOUND THEN RETURN; END IF;
  SELECT count(*) INTO row_count FROM public.payroll
    WHERE employee_id=target_employee AND period>=month_date AND period<month_date+INTERVAL '1 month';
  IF row_count=0 THEN
    SELECT * INTO state_row FROM app_private.payroll_increment_state WHERE employee_id=target_employee AND period=month_date;
    IF FOUND AND state_row.applied_inc_details IS NOT NULL AND current_details IS NOT DISTINCT FROM state_row.applied_inc_details THEN
      UPDATE public.employee_salary_defaults SET inc_details=state_row.inc_details_before WHERE employee_id=target_employee;
    END IF;
    UPDATE app_private.payroll_increment_state SET detected_amount=NULL,applied_inc_details=NULL,updated_at=clock_timestamp()
      WHERE employee_id=target_employee AND period=month_date;
    RETURN;
  END IF;
  IF row_count<>1 THEN RETURN; END IF;
  INSERT INTO app_private.payroll_increment_state(employee_id,period,inc_details_before,joining_date_before)
    VALUES(target_employee,month_date,current_details,join_date) ON CONFLICT(employee_id,period) DO NOTHING;
  SELECT * INTO state_row FROM app_private.payroll_increment_state WHERE employee_id=target_employee AND period=month_date;
  SELECT coalesce(basic_salary,0)::numeric AS basic,coalesce(elaun_kedatangan,0)::numeric AS attendance,
    coalesce(elaun_perkhidmatan,0)::numeric AS service,coalesce(elaun_kerajinan,0)::numeric AS diligence
    INTO current_pay FROM public.payroll WHERE employee_id=target_employee AND period>=month_date AND period<month_date+INTERVAL '1 month';
  IF current_pay.basic<0 OR current_pay.attendance<0 OR current_pay.service<0 OR current_pay.diligence<0
    OR current_pay.basic::text IN ('NaN','Infinity','-Infinity') OR current_pay.attendance::text IN ('NaN','Infinity','-Infinity')
    OR current_pay.service::text IN ('NaN','Infinity','-Infinity') OR current_pay.diligence::text IN ('NaN','Infinity','-Infinity') THEN RETURN; END IF;
  SELECT max(coalesce(basic_salary,0))::numeric AS basic,max(coalesce(elaun_kedatangan,0))::numeric AS attendance,
    max(coalesce(elaun_perkhidmatan,0))::numeric AS service,max(coalesce(elaun_kerajinan,0))::numeric AS diligence,count(*) AS count
    INTO previous_pay FROM public.payroll WHERE employee_id=target_employee AND period>=month_date-INTERVAL '7 months' AND period<month_date
      AND coalesce(basic_salary,0)>=0 AND coalesce(elaun_kedatangan,0)>=0 AND coalesce(elaun_perkhidmatan,0)>=0 AND coalesce(elaun_kerajinan,0)>=0
      AND coalesce(basic_salary,0)::text NOT IN ('NaN','Infinity','-Infinity') AND coalesce(elaun_kedatangan,0)::text NOT IN ('NaN','Infinity','-Infinity')
      AND coalesce(elaun_perkhidmatan,0)::text NOT IN ('NaN','Infinity','-Infinity') AND coalesce(elaun_kerajinan,0)::text NOT IN ('NaN','Infinity','-Infinity');
  IF previous_pay.count=0 OR previous_pay.basic+previous_pay.attendance+previous_pay.service+previous_pay.diligence<=0 THEN RETURN; END IF;
  amount=round(greatest(0,current_pay.basic-previous_pay.basic)+greatest(0,current_pay.attendance-previous_pay.attendance)
    +greatest(0,current_pay.service-previous_pay.service)+greatest(0,current_pay.diligence-previous_pay.diligence),2);
  UPDATE app_private.payroll_increment_state SET detected_amount=amount,updated_at=clock_timestamp()
    WHERE employee_id=target_employee AND period=month_date;
  IF amount>0 THEN
    label=upper(to_char(month_date,'MON-YY'))||'/'||trim(trailing '.' from trim(trailing '0' from to_char(amount,'FM999999999990.00')));
    -- A historical import/edit must never replace a later maintained increment.
    IF coalesce(app_private.increment_reference_month(current_details),month_date)<=month_date THEN
      UPDATE public.employee_salary_defaults SET inc_details=label WHERE employee_id=target_employee AND inc_details IS DISTINCT FROM label;
      UPDATE app_private.payroll_increment_state SET applied_inc_details=label WHERE employee_id=target_employee AND period=month_date;
    END IF;
  ELSIF state_row.applied_inc_details IS NOT NULL AND current_details IS NOT DISTINCT FROM state_row.applied_inc_details THEN
    UPDATE public.employee_salary_defaults SET inc_details=state_row.inc_details_before WHERE employee_id=target_employee;
    UPDATE app_private.payroll_increment_state SET applied_inc_details=NULL WHERE employee_id=target_employee AND period=month_date;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION app_private.payroll_increment_saved()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE employee text; changed_period date; latest_period date;
BEGIN
  IF TG_OP='UPDATE' THEN
    IF OLD.employee_id IS DISTINCT FROM NEW.employee_id OR date_trunc('month',OLD.period) IS DISTINCT FROM date_trunc('month',NEW.period) THEN
      PERFORM app_private.sync_payroll_increment(OLD.employee_id,OLD.period);
      SELECT max(period) INTO latest_period FROM public.payroll WHERE employee_id=OLD.employee_id;
      IF latest_period IS NOT NULL THEN PERFORM app_private.sync_payroll_increment(OLD.employee_id,latest_period); END IF;
    END IF;
  END IF;
  IF TG_OP='DELETE' THEN employee=OLD.employee_id; changed_period=OLD.period;
  ELSE employee=NEW.employee_id; changed_period=NEW.period; END IF;
  PERFORM app_private.sync_payroll_increment(employee,changed_period);
  SELECT max(period) INTO latest_period FROM public.payroll WHERE employee_id=employee;
  IF latest_period IS NOT NULL AND date_trunc('month',latest_period)<>date_trunc('month',changed_period) THEN
    PERFORM app_private.sync_payroll_increment(employee,latest_period);
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION app_private.increment_reference_month(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.sync_payroll_increment(text,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.payroll_increment_saved() FROM PUBLIC;
DROP TRIGGER IF EXISTS payroll_increment_saved ON public.payroll;
CREATE TRIGGER payroll_increment_saved AFTER INSERT OR UPDATE OF employee_id,period,basic_salary,elaun_kedatangan,elaun_perkhidmatan,elaun_kerajinan OR DELETE
  ON public.payroll FOR EACH ROW EXECUTE FUNCTION app_private.payroll_increment_saved();

-- Synchronize existing latest payroll records once without rewriting any payroll rows.
DO $$ DECLARE target record; BEGIN
  FOR target IN SELECT employee_id,max(period) AS period FROM public.payroll GROUP BY employee_id ORDER BY employee_id LOOP
    PERFORM app_private.sync_payroll_increment(target.employee_id,target.period);
  END LOOP;
END $$;
