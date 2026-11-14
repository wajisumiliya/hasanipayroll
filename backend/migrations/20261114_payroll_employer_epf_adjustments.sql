-- Employer EPF corrections are audited; locked payroll is never reopened.
CREATE TABLE IF NOT EXISTS app_private.payroll_employer_epf_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payroll_id text NOT NULL,
  employee_id text NOT NULL,
  period date NOT NULL,
  old_amount numeric NOT NULL,
  new_amount numeric NOT NULL,
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 5 AND 1000),
  adjusted_by text NOT NULL,
  transaction_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON app_private.payroll_employer_epf_adjustments FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION app_private.protect_locked_payroll()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = pg_catalog
AS $function$
DECLARE prior jsonb := to_jsonb(OLD); next_row jsonb := to_jsonb(NEW);
BEGIN
 IF (next_row - ARRAY['updated_at','epf_employer']) = (prior - ARRAY['updated_at','epf_employer'])
    AND EXISTS (SELECT 1 FROM app_private.payroll_employer_epf_adjustments a
      WHERE a.id::text = current_setting('app.payroll_adjustment_id',true)
        AND a.transaction_id = txid_current()
        AND a.payroll_id = prior->>'id'
        AND a.old_amount = coalesce((prior->>'epf_employer')::numeric,0)
        AND a.new_amount = coalesce((next_row->>'epf_employer')::numeric,0)) THEN
   RETURN NEW;
 END IF;
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
END $function$
;
REVOKE ALL ON FUNCTION app_private.protect_locked_payroll() FROM PUBLIC,anon,authenticated;
-- Preserve the existing trigger and its enabled state; do not change which
-- installations enforce this lock or reopen any payroll rows.

CREATE OR REPLACE FUNCTION public.adjust_payroll_employer_epf(
  p_payroll_id text, p_amount numeric, p_expected_amount numeric, p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  prior jsonb; result jsonb; audit_id uuid;
  actor text = auth.user_id();
  scope text = lower(coalesce(auth.jwt()->'app_metadata'->>'staff_scope','all'));
  foreign_staff boolean;
  previous_context text = current_setting('app.payroll_adjustment_id',true);
BEGIN
  IF public.current_app_role() NOT IN ('admin','administrator') OR actor IS NULL
    OR coalesce((auth.jwt()->'app_metadata'->>'is_reviewer')::boolean,false)
    OR scope NOT IN ('all','','local','foreign') THEN
    RAISE EXCEPTION 'Payroll administrator access required' USING ERRCODE='42501';
  END IF;
  IF p_amount IS NULL OR p_amount::text IN ('NaN','Infinity','-Infinity')
    OR p_amount<0 OR round(p_amount,2)<>p_amount
    OR p_expected_amount IS NULL OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 5 AND 1000 THEN
    RAISE EXCEPTION 'A valid employer EPF amount and adjustment reason are required' USING ERRCODE='23514';
  END IF;
  SELECT to_jsonb(p) INTO prior FROM public.payroll p WHERE p.id::text=p_payroll_id FOR UPDATE;
  IF prior IS NULL THEN RAISE EXCEPTION 'Payroll not found' USING ERRCODE='23514'; END IF;
  IF scope IN ('local','foreign') THEN
    SELECT upper(coalesce(e.address,'')) LIKE '%FRN%' OR upper(coalesce(e.address,'')) LIKE '%FOREIGN%'
      INTO foreign_staff FROM public.employees e WHERE e.employee_id=prior->>'employee_id';
    IF foreign_staff IS NULL OR (scope='local' AND foreign_staff) OR (scope='foreign' AND NOT foreign_staff) THEN
      RAISE EXCEPTION 'Payroll is outside administrator staff scope' USING ERRCODE='42501';
    END IF;
  END IF;
  IF coalesce((prior->>'epf_employer')::numeric,0) IS DISTINCT FROM p_expected_amount THEN
    RAISE EXCEPTION 'Payroll changed; reload before adjusting' USING ERRCODE='40001';
  END IF;
  IF p_amount=p_expected_amount THEN RETURN prior; END IF;
  INSERT INTO app_private.payroll_employer_epf_adjustments
    (payroll_id,employee_id,period,old_amount,new_amount,reason,adjusted_by,transaction_id)
    VALUES(p_payroll_id,prior->>'employee_id',(prior->>'period')::date,p_expected_amount,p_amount,trim(p_reason),actor,txid_current())
    RETURNING id INTO audit_id;
  PERFORM set_config('app.payroll_adjustment_id',audit_id::text,true);
  UPDATE public.payroll SET epf_employer=p_amount WHERE id::text=p_payroll_id RETURNING to_jsonb(payroll) INTO result;
  PERFORM set_config('app.payroll_adjustment_id',coalesce(previous_context,''),true);
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.adjust_payroll_employer_epf(text,numeric,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.adjust_payroll_employer_epf(text,numeric,numeric,text) TO authenticated;
