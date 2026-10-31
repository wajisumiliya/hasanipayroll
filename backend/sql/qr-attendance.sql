-- Apply to Neon before enabling the scanner screen.
CREATE TABLE IF NOT EXISTS public.qr_attendance_credentials (
  employee_id text PRIMARY KEY REFERENCES public.employees(employee_id),
  token_hash text NOT NULL UNIQUE,
  issued_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);
CREATE TABLE IF NOT EXISTS public.qr_attendance_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_id text NOT NULL REFERENCES public.employees(employee_id),
  branch_id text NOT NULL,
  action text NOT NULL CHECK (action IN ('IN','OUT')),
  scanned_at timestamptz NOT NULL DEFAULT now(),
  scanned_by text NOT NULL,
  source text NOT NULL DEFAULT 'USB_QR',
  CONSTRAINT qr_attendance_source CHECK (source = 'USB_QR')
);
CREATE INDEX IF NOT EXISTS qr_attendance_lookup_idx ON public.qr_attendance_events(employee_id, scanned_at DESC);
CREATE INDEX IF NOT EXISTS qr_attendance_branch_date_idx ON public.qr_attendance_events(branch_id, scanned_at DESC);
REVOKE ALL ON public.qr_attendance_credentials FROM PUBLIC;
REVOKE ALL ON public.qr_attendance_events FROM PUBLIC;
-- API must use its existing restricted database credentials; no direct browser DB access.
