ALTER TABLE app_private.payslip_notice_delivery
  ADD COLUMN IF NOT EXISTS last_error_codes text[] NOT NULL DEFAULT '{}';

-- Re-enable recent missed deliveries when an employee finally registers a
-- device. Successful deliveries never replay, and old months are not backfilled.
CREATE OR REPLACE FUNCTION app_private.retry_payslip_push_on_device_registration()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
  IF nullif(trim(NEW.employee_id),'') IS NULL THEN RETURN NEW; END IF;
  UPDATE app_private.payslip_notice_delivery
    SET completed_at=NULL,available_at=now(),last_status='queued',
      last_error_codes='{}',claim_token=NULL,claimed_until=NULL
    WHERE employee_id=NEW.employee_id
      AND created_at>=now()-interval '7 days'
      AND last_status IN ('no_devices','failed','authentication_failed','invalid_configuration','not_configured')
      AND (completed_at IS NULL OR last_status='no_devices')
      AND (claimed_until IS NULL OR claimed_until<=now());
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION app_private.retry_payslip_push_on_device_registration() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS retry_payslip_push_on_device_registration ON public.notification_devices;
CREATE TRIGGER retry_payslip_push_on_device_registration
  AFTER INSERT OR UPDATE OF employee_id,token ON public.notification_devices
  FOR EACH ROW EXECUTE FUNCTION app_private.retry_payslip_push_on_device_registration();
