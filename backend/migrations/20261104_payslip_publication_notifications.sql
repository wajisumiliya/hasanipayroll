-- Publication and its employee inbox message commit together. Push is delivered
-- afterwards by the backend worker, including scheduled releases.
CREATE TABLE IF NOT EXISTS app_private.payslip_notice_delivery (
  employee_id text NOT NULL REFERENCES public.employees(employee_id) ON UPDATE CASCADE ON DELETE CASCADE,
  payroll_month date NOT NULL,
  notification_id uuid REFERENCES public.app_notifications(id) ON DELETE CASCADE,
  attempts integer NOT NULL DEFAULT 0,
  available_at timestamptz NOT NULL DEFAULT now(),
  claimed_until timestamptz,
  claim_token uuid,
  completed_at timestamptz,
  last_status text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (employee_id, payroll_month)
);
REVOKE ALL ON app_private.payslip_notice_delivery FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS payslip_notice_pending ON app_private.payslip_notice_delivery(available_at)
  WHERE completed_at IS NULL;

CREATE OR REPLACE FUNCTION app_private.payslip_published_notice()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE
  target_month date;
  target_employee text;
  message_body text;
  notice_id uuid;
BEGIN
  IF NOT NEW.is_published OR (NEW.release_at IS NOT NULL AND NEW.release_at > now()) THEN
    RETURN NEW;
  END IF;
  target_employee := trim(NEW.employee_id);
  IF nullif(target_employee, '') IS NULL THEN RETURN NEW; END IF;
  target_month := date_trunc('month', NEW.period::timestamp)::date;
  INSERT INTO app_private.payslip_notice_delivery(employee_id,payroll_month)
    VALUES (target_employee,target_month) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN NEW; END IF;

  message_body := format('Your %s payslip is ready to view.', to_char(target_month,'FMMonth YYYY'));
  SELECT id INTO notice_id FROM public.app_notifications
    WHERE audience='employee' AND notification_type='payslip'
      AND employee_id=target_employee AND body=message_body
    ORDER BY created_at DESC LIMIT 1;
  IF notice_id IS NULL THEN
    INSERT INTO public.app_notifications(title,body,notification_type,audience,employee_id)
      VALUES ('New Payslip Available',message_body,'payslip','employee',target_employee)
      RETURNING id INTO notice_id;
  END IF;
  UPDATE app_private.payslip_notice_delivery SET notification_id=notice_id
    WHERE employee_id=target_employee AND payroll_month=target_month;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION app_private.payslip_published_notice() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS payslip_published_notice ON public.payroll;
CREATE TRIGGER payslip_published_notice
  AFTER INSERT OR UPDATE OF is_published,release_at,employee_id,period ON public.payroll
  FOR EACH ROW EXECUTE FUNCTION app_private.payslip_published_notice();
