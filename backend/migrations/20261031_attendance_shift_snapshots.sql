ALTER TABLE public.attendance
  ADD COLUMN IF NOT EXISTS scheduled_shift_start time,
  ADD COLUMN IF NOT EXISTS scheduled_shift_end time;

-- Capture the assigned schedule at save time so later roster removal does not
-- erase the evidence needed to calculate arrival minutes. No guessed defaults.
CREATE OR REPLACE FUNCTION app_private.capture_attendance_shift()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
  daily_row public.daily_rosters%ROWTYPE;
  weekly_row public.monthly_rosters%ROWTYPE;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.employee_id IS DISTINCT FROM OLD.employee_id OR NEW.branch_id IS DISTINCT FROM OLD.branch_id
      OR NEW.attendance_date IS DISTINCT FROM OLD.attendance_date THEN
      NEW.scheduled_shift_start = NULL;
      NEW.scheduled_shift_end = NULL;
    END IF;
  END IF;
  IF NEW.scheduled_shift_start IS NOT NULL AND NEW.scheduled_shift_end IS NOT NULL THEN RETURN NEW; END IF;
  SELECT * INTO daily_row FROM public.daily_rosters
    WHERE UPPER(TRIM(employee_id))=UPPER(TRIM(NEW.employee_id))
      AND UPPER(TRIM(branch_id))=UPPER(TRIM(NEW.branch_id)) AND roster_date=NEW.attendance_date LIMIT 1;
  IF FOUND AND COALESCE(daily_row.assignment_type::text,'SHIFT') <> 'SHIFT' THEN RETURN NEW; END IF;
  SELECT * INTO weekly_row FROM public.monthly_rosters
    WHERE UPPER(TRIM(employee_id))=UPPER(TRIM(NEW.employee_id))
      AND UPPER(TRIM(branch_id))=UPPER(TRIM(NEW.branch_id))
      AND roster_year=EXTRACT(YEAR FROM NEW.attendance_date)
      AND roster_month=EXTRACT(MONTH FROM NEW.attendance_date)
      AND week_number=((EXTRACT(DAY FROM NEW.attendance_date)::int-1)/7)+1 LIMIT 1;
  NEW.scheduled_shift_start = COALESCE(NEW.scheduled_shift_start,daily_row.shift_start,weekly_row.shift_start);
  NEW.scheduled_shift_end = COALESCE(NEW.scheduled_shift_end,daily_row.shift_end,weekly_row.shift_end);
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION app_private.capture_attendance_shift() FROM PUBLIC;
DROP TRIGGER IF EXISTS attendance_shift_snapshot ON public.attendance;
CREATE TRIGGER attendance_shift_snapshot BEFORE INSERT OR UPDATE ON public.attendance
FOR EACH ROW EXECUTE FUNCTION app_private.capture_attendance_shift();
