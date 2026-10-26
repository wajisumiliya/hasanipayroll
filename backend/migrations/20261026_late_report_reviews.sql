CREATE TABLE IF NOT EXISTS app_private.late_report_reviews (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  branch_id text NOT NULL,
  employee_id text NOT NULL,
  event_date date NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('arrival', 'break')),
  event_fingerprint text NOT NULL CHECK (length(event_fingerprint) = 64),
  event_snapshot jsonb NOT NULL,
  status text NOT NULL CHECK (status IN ('noted', 'approved', 'correction_required', 'pending')),
  reason_code text NOT NULL CHECK (reason_code IN ('transport', 'approved_late', 'attendance_error', 'other')),
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 3 AND 1000),
  reviewed_by text NOT NULL,
  reviewed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS late_report_reviews_event_idx
  ON app_private.late_report_reviews(event_date, branch_id, employee_id, event_type, id DESC);
REVOKE ALL ON app_private.late_report_reviews FROM PUBLIC, anon, authenticated;
