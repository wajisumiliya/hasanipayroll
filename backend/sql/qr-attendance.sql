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
CREATE INDEX IF NOT EXISTS qr_attendance_timestamp_idx ON public.qr_attendance_events(scanned_at);
CREATE INDEX IF NOT EXISTS qr_attendance_branch_date_idx ON public.qr_attendance_events(branch_id, scanned_at DESC);
REVOKE ALL ON public.qr_attendance_credentials FROM PUBLIC;
REVOKE ALL ON public.qr_attendance_events FROM PUBLIC;
-- API must use its existing restricted database credentials; no direct browser DB access.

-- Additive v2 migration. Apply manually to STAGING first; never run on startup.
-- Existing pilot credentials and raw events are retained.
BEGIN;
ALTER TABLE public.qr_attendance_credentials ADD COLUMN IF NOT EXISTS issued_by text;
ALTER TABLE public.qr_attendance_credentials ADD COLUMN IF NOT EXISTS expires_at timestamptz;
CREATE TABLE IF NOT EXISTS public.qr_attendance_stations (
  id uuid PRIMARY KEY,
  branch_id text NOT NULL,
  label text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  min_interval_seconds integer NOT NULL DEFAULT 60 CHECK (min_interval_seconds BETWEEN 1 AND 3600),
  max_open_hours integer NOT NULL DEFAULT 36 CHECK (max_open_hours BETWEEN 1 AND 168),
  allow_multiple_sessions boolean NOT NULL DEFAULT true,
  verification_required boolean NOT NULL DEFAULT true,
  created_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(branch_id,label)
);
CREATE TABLE IF NOT EXISTS public.qr_attendance_sessions (
  id uuid PRIMARY KEY,
  station_id uuid NOT NULL REFERENCES public.qr_attendance_stations(id),
  operator text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL DEFAULT (clock_timestamp() + INTERVAL '12 hours'),
  revoked_at timestamptz
);
CREATE INDEX IF NOT EXISTS qr_session_station_idx ON public.qr_attendance_sessions(station_id,expires_at);
ALTER TABLE public.qr_attendance_events ADD COLUMN IF NOT EXISTS session_id uuid REFERENCES public.qr_attendance_sessions(id);
ALTER TABLE public.qr_attendance_events ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE public.qr_attendance_events ADD COLUMN IF NOT EXISTS work_date date;
ALTER TABLE public.qr_attendance_events ADD COLUMN IF NOT EXISTS paired_event_id bigint REFERENCES public.qr_attendance_events(id);
ALTER TABLE public.qr_attendance_events ADD COLUMN IF NOT EXISTS verified_by text;
UPDATE public.qr_attendance_events SET work_date=(scanned_at AT TIME ZONE 'Asia/Kuala_Lumpur')::date WHERE work_date IS NULL;
ALTER TABLE public.qr_attendance_events ALTER COLUMN work_date SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS qr_event_request_idx ON public.qr_attendance_events(session_id,request_id) WHERE request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS qr_event_work_date_idx ON public.qr_attendance_events(branch_id,work_date,employee_id);
CREATE TABLE IF NOT EXISTS public.qr_attendance_attempts (
  session_id uuid NOT NULL REFERENCES public.qr_attendance_sessions(id),
  request_id uuid NOT NULL,
  credential_hash text NOT NULL,
  employee_id text,
  branch_id text NOT NULL,
  operator text NOT NULL,
  status text NOT NULL CHECK (status IN ('ACCEPTED','REJECTED')),
  code text NOT NULL,
  message text NOT NULL,
  http_status integer NOT NULL,
  event_id bigint REFERENCES public.qr_attendance_events(id),
  attempted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY(session_id,request_id)
);
CREATE INDEX IF NOT EXISTS qr_attempt_branch_time_idx ON public.qr_attendance_attempts(branch_id,attempted_at);
CREATE TABLE IF NOT EXISTS public.qr_attendance_verifications (
  ticket_hash text PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES public.qr_attendance_sessions(id),
  employee_id text NOT NULL REFERENCES public.employees(employee_id),
  credential_hash text NOT NULL,
  expires_at timestamptz NOT NULL DEFAULT (clock_timestamp() + INTERVAL '2 minutes'),
  used_at timestamptz
);
CREATE INDEX IF NOT EXISTS qr_verification_expiry_idx ON public.qr_attendance_verifications(expires_at);
CREATE TABLE IF NOT EXISTS public.qr_attendance_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_id text,
  branch_id text,
  operator text NOT NULL,
  action text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS qr_audit_employee_time_idx ON public.qr_attendance_audit(employee_id,created_at DESC);
CREATE TABLE IF NOT EXISTS public.qr_attendance_corrections (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_id text NOT NULL REFERENCES public.employees(employee_id),
  branch_id text NOT NULL,
  work_date date NOT NULL,
  event_id bigint REFERENCES public.qr_attendance_events(id),
  action text NOT NULL CHECK (action IN ('IN','OUT','VOID')),
  corrected_at timestamptz NOT NULL,
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 5 AND 1000),
  requested_by text NOT NULL,
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED')),
  reviewed_by text,
  reviewed_at timestamptz
);
CREATE INDEX IF NOT EXISTS qr_correction_date_idx ON public.qr_attendance_corrections(corrected_at) WHERE status='APPROVED';
CREATE INDEX IF NOT EXISTS qr_correction_event_latest_idx ON public.qr_attendance_corrections(event_id,id DESC) WHERE status='APPROVED';
CREATE INDEX IF NOT EXISTS qr_correction_manual_time_idx ON public.qr_attendance_corrections(employee_id,corrected_at DESC) WHERE status='APPROVED' AND event_id IS NULL;
CREATE INDEX IF NOT EXISTS qr_correction_employee_day_idx ON public.qr_attendance_corrections(employee_id,work_date,id DESC);
CREATE TABLE IF NOT EXISTS public.qr_attendance_reconciliations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_id text NOT NULL REFERENCES public.employees(employee_id),
  branch_id text NOT NULL,
  work_date date NOT NULL,
  fingerprint text NOT NULL,
  source_events jsonb NOT NULL,
  previous_attendance jsonb,
  approved_attendance jsonb NOT NULL,
  approved_by text NOT NULL,
  approved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(employee_id,work_date,fingerprint)
);
CREATE OR REPLACE VIEW public.qr_attendance_effective_events AS
SELECT 'E'||e.id::text AS event_key,e.id AS raw_id,e.employee_id,e.branch_id,e.work_date,
       COALESCE(c.action,e.action) AS action,COALESCE(c.corrected_at,e.scanned_at) AS scanned_at,
       e.scanned_by,c.id AS correction_id
FROM public.qr_attendance_events e
LEFT JOIN LATERAL (SELECT id,action,corrected_at FROM public.qr_attendance_corrections
  WHERE event_id=e.id AND status='APPROVED' ORDER BY id DESC LIMIT 1) c ON true
WHERE COALESCE(c.action,e.action)<>'VOID'
UNION ALL
SELECT 'C'||c.id::text,NULL::bigint,c.employee_id,c.branch_id,c.work_date,c.action,c.corrected_at,c.requested_by,c.id
FROM public.qr_attendance_corrections c WHERE event_id IS NULL AND status='APPROVED' AND action<>'VOID';
CREATE OR REPLACE FUNCTION public.qr_attendance_immutable_event() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Raw QR events are immutable; use an audited correction'; END $$;
DROP TRIGGER IF EXISTS qr_events_immutable ON public.qr_attendance_events;
CREATE TRIGGER qr_events_immutable BEFORE UPDATE OR DELETE ON public.qr_attendance_events
FOR EACH ROW EXECUTE FUNCTION public.qr_attendance_immutable_event();
DO $$ DECLARE relation text; role_name text; BEGIN
  FOREACH relation IN ARRAY ARRAY['qr_attendance_credentials','qr_attendance_events','qr_attendance_stations','qr_attendance_sessions',
    'qr_attendance_attempts','qr_attendance_verifications','qr_attendance_audit','qr_attendance_corrections','qr_attendance_reconciliations','qr_attendance_effective_events'] LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC',relation);
    FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
      IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=role_name) THEN
        EXECUTE format('REVOKE ALL ON public.%I FROM %I',relation,role_name);
      END IF;
    END LOOP;
  END LOOP;
END $$;
CREATE TABLE IF NOT EXISTS public.qr_attendance_presence (
  employee_id text PRIMARY KEY REFERENCES public.employees(employee_id),
  branch_id text NOT NULL, action text NOT NULL CHECK(action IN ('IN','OUT')),
  work_date date NOT NULL, scanned_at timestamptz NOT NULL,raw_id bigint,event_key text
);
ALTER TABLE public.qr_attendance_presence ADD COLUMN IF NOT EXISTS raw_id bigint;
ALTER TABLE public.qr_attendance_presence ADD COLUMN IF NOT EXISTS event_key text;
CREATE INDEX IF NOT EXISTS qr_presence_open_idx ON public.qr_attendance_presence(branch_id,work_date) WHERE action='IN';
INSERT INTO public.qr_attendance_presence(employee_id,branch_id,action,work_date,scanned_at,raw_id,event_key)
SELECT DISTINCT ON(employee_id) employee_id,branch_id,action,work_date,scanned_at,raw_id,event_key FROM public.qr_attendance_effective_events
ORDER BY employee_id,scanned_at DESC,event_key DESC
ON CONFLICT(employee_id) DO UPDATE SET branch_id=EXCLUDED.branch_id,action=EXCLUDED.action,work_date=EXCLUDED.work_date,scanned_at=EXCLUDED.scanned_at,raw_id=EXCLUDED.raw_id,event_key=EXCLUDED.event_key;
REVOKE ALL ON public.qr_attendance_presence FROM PUBLIC;
DO $$ DECLARE r text; BEGIN FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
  IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r) THEN EXECUTE format('REVOKE ALL ON public.qr_attendance_presence FROM %I',r); END IF;
END LOOP; END $$;
COMMIT;
