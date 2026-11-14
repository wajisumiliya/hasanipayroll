CREATE OR REPLACE FUNCTION app_private.protect_locked_payroll()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
END $function$
;
CREATE TRIGGER protect_locked_payroll BEFORE UPDATE ON public.payroll
  FOR EACH ROW EXECUTE FUNCTION app_private.protect_locked_payroll();
