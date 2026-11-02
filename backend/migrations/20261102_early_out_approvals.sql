-- MANUAL, APPROVAL-REQUIRED MIGRATION. Not registered in application startup.
BEGIN;
CREATE SCHEMA IF NOT EXISTS app_private;
CREATE TABLE IF NOT EXISTS app_private.early_out_decisions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 request_id uuid NOT NULL UNIQUE,
 employee_id text NOT NULL,
 attendance_date date NOT NULL,
 branch_id text NOT NULL,
 fingerprint text NOT NULL CHECK(length(fingerprint)=64),
 status text NOT NULL CHECK(status IN ('APPROVED','REJECTED')),
 approved_minutes integer NOT NULL CHECK(approved_minutes BETWEEN 0 AND 1440),
 approver_role text NOT NULL CHECK(approver_role IN ('ADMIN','ACCOUNTS')),
 approver_user_id text NOT NULL,
 approved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 remarks text NOT NULL CHECK(length(btrim(remarks)) BETWEEN 3 AND 1000),
 attendance_snapshot jsonb NOT NULL,
 CHECK ((status='APPROVED' AND approved_minutes>0) OR (status='REJECTED' AND approved_minutes=0))
);
CREATE INDEX IF NOT EXISTS early_out_decisions_day_idx ON app_private.early_out_decisions(employee_id,attendance_date,id DESC);
ALTER TABLE public.payroll ADD COLUMN IF NOT EXISTS early_out_snapshot jsonb;
-- API-owned audit data is never exposed via the generic table API.
REVOKE ALL ON app_private.early_out_decisions FROM PUBLIC;
DO $$
DECLARE role_name text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=role_name) THEN
      EXECUTE format('REVOKE ALL ON TABLE app_private.early_out_decisions FROM %I',role_name);
    END IF;
  END LOOP;
END $$;
CREATE OR REPLACE FUNCTION app_private.keep_early_out_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Early Out decisions are append-only'; END $$;
DROP TRIGGER IF EXISTS keep_early_out_audit ON app_private.early_out_decisions;
CREATE TRIGGER keep_early_out_audit BEFORE UPDATE OR DELETE ON app_private.early_out_decisions FOR EACH ROW EXECUTE FUNCTION app_private.keep_early_out_audit();
CREATE OR REPLACE FUNCTION app_private.protect_locked_payroll() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE prior jsonb := to_jsonb(OLD); next_row jsonb := to_jsonb(NEW);
BEGIN
 IF COALESCE((prior->>'is_published')::boolean,false) OR COALESCE((prior->>'is_paid')::boolean,false)
    OR COALESCE((prior->>'isPaid')::boolean,false) OR prior->>'paid_at' IS NOT NULL OR prior->>'paidAt' IS NOT NULL
    OR COALESCE((prior->>'is_finalized')::boolean,false) OR prior->>'finalized_at' IS NOT NULL
    OR lower(COALESCE(prior->>'status','')) IN ('paid','finalized','finalised','locked') THEN
   IF (COALESCE((prior->>'is_published')::boolean,false) AND NOT COALESCE((next_row->>'is_published')::boolean,false))
      OR (COALESCE((prior->>'is_paid')::boolean,false) AND NOT COALESCE((next_row->>'is_paid')::boolean,false))
      OR (COALESCE((prior->>'isPaid')::boolean,false) AND NOT COALESCE((next_row->>'isPaid')::boolean,false))
      OR (COALESCE((prior->>'is_finalized')::boolean,false) AND NOT COALESCE((next_row->>'is_finalized')::boolean,false))
      OR (prior->>'paid_at' IS NOT NULL AND next_row->>'paid_at' IS NULL)
      OR (prior->>'paidAt' IS NOT NULL AND next_row->>'paidAt' IS NULL)
      OR (prior->>'finalized_at' IS NOT NULL AND next_row->>'finalized_at' IS NULL)
      OR (lower(COALESCE(prior->>'status','')) IN ('paid','finalized','finalised','locked') AND lower(COALESCE(next_row->>'status','')) NOT IN ('paid','finalized','finalised','locked')) THEN
       RAISE EXCEPTION 'Locked payroll cannot be reopened by an ordinary update';
   END IF;
   IF (next_row - ARRAY['updated_at','is_published','published_at','published_by','release_at','is_paid','isPaid','paid_at','paidAt','payment_reference','status'])
      IS DISTINCT FROM (prior - ARRAY['updated_at','is_published','published_at','published_by','release_at','is_paid','isPaid','paid_at','paidAt','payment_reference','status']) THEN
     RAISE EXCEPTION 'Finalized, published or paid payroll requires an authorized adjustment; regeneration is blocked';
   END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS protect_locked_payroll ON public.payroll;
CREATE TRIGGER protect_locked_payroll BEFORE UPDATE ON public.payroll FOR EACH ROW EXECUTE FUNCTION app_private.protect_locked_payroll();
COMMIT;
