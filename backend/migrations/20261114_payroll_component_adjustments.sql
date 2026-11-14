-- Extend audited corrections to the editable payroll components; never reopen rows.
CREATE TABLE IF NOT EXISTS app_private.payroll_adjustments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), payroll_id text NOT NULL,
 employee_id text NOT NULL, period date NOT NULL,
 before_row jsonb NOT NULL, after_row jsonb NOT NULL,
 reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 5 AND 1000),
 adjusted_by text NOT NULL, transaction_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON app_private.payroll_adjustments FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION app_private.protect_locked_payroll()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = pg_catalog
AS $function$
DECLARE prior jsonb := to_jsonb(OLD); next_row jsonb := to_jsonb(NEW);
BEGIN
 IF EXISTS (SELECT 1 FROM app_private.payroll_adjustments a
      WHERE a.id::text=current_setting('app.payroll_general_adjustment_id',true)
        AND a.transaction_id=txid_current() AND a.payroll_id=prior->>'id'
        AND a.before_row-'updated_at'=prior-'updated_at'
        AND a.after_row-'updated_at'=next_row-'updated_at') THEN
   RETURN NEW;
 END IF;
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

CREATE OR REPLACE FUNCTION public.adjust_payroll(
 p_payroll_id text, p_changes jsonb, p_expected jsonb, p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
 prior jsonb; desired jsonb; result jsonb; audit_id uuid; assignments text;
 entry record; amount numeric;
 actor text=auth.user_id();
 scope text=lower(coalesce(auth.jwt()->'app_metadata'->>'staff_scope','all'));
 foreign_staff boolean;
 previous_context text=current_setting('app.payroll_general_adjustment_id',true);
 allowed constant text[]=ARRAY[
 'basic_salary','fw_salary','elaun_kedatangan','elaun_perkhidmatan','elaun_kerajinan','elaun_makanan',
 'overtime','cuti_umum','bonus','commission','other_earnings','late_deduction','unpaid_deduction',
 'epf_employee','socso_employee','eis_employee','pcb','zakat','advance','epf_employer','socso_employer','eis_employer','remarks',
 'gross_salary','gross_pay','total_gross','grossSalary','grossPay','jumlah','total_earnings','totalEarnings',
 'total_deductions','totalDeductions','net_pay','net_salary','total_net','netPay','netSalary','net'];
 net_keys constant text[]=ARRAY['net_pay','net_salary','total_net','netPay','netSalary','net'];
 snapshot_keys constant text[]=ARRAY['gross_salary','gross_pay','total_gross','grossSalary','grossPay','jumlah','total_earnings','totalEarnings','total_deductions','totalDeductions','net_pay','net_salary','total_net','netPay','netSalary','net'];
BEGIN
 IF public.current_app_role() NOT IN ('admin','administrator') OR actor IS NULL
   OR coalesce((auth.jwt()->'app_metadata'->>'is_reviewer')::boolean,false)
   OR scope NOT IN ('all','','local','foreign') THEN
   RAISE EXCEPTION 'Payroll administrator access required' USING ERRCODE='42501';
 END IF;
 IF p_changes IS NULL OR jsonb_typeof(p_changes)<>'object'
   OR p_expected IS NULL OR jsonb_typeof(p_expected)<>'object'
   OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 5 AND 1000 THEN
   RAISE EXCEPTION 'Payroll changes, original record and adjustment reason are required' USING ERRCODE='23514';
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
 IF prior IS DISTINCT FROM p_expected THEN
   RAISE EXCEPTION 'Payroll changed; reload before adjusting' USING ERRCODE='40001';
 END IF;
 FOR entry IN SELECT key,value FROM jsonb_each(p_changes) LOOP
   IF NOT entry.key=ANY(allowed) OR NOT prior ? entry.key THEN
     RAISE EXCEPTION 'Field cannot be adjusted' USING ERRCODE='23514';
   END IF;
   IF entry.key='remarks' THEN
     IF jsonb_typeof(entry.value) NOT IN ('null','string') OR length(entry.value #>> '{}')>10000 THEN
       RAISE EXCEPTION 'Invalid remarks' USING ERRCODE='23514';
     END IF;
   ELSE
     IF jsonb_typeof(entry.value) NOT IN ('number','string') THEN
       RAISE EXCEPTION 'Invalid payroll amount' USING ERRCODE='23514';
     END IF;
     BEGIN amount=(entry.value #>> '{}')::numeric;
     EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
       RAISE EXCEPTION 'Invalid payroll amount' USING ERRCODE='23514';
     END;
     IF amount::text IN ('NaN','Infinity','-Infinity') OR (round(amount,2)<>amount AND NOT entry.key=ANY(snapshot_keys))
       OR (amount<0 AND NOT entry.key=ANY(net_keys)) THEN
       RAISE EXCEPTION 'Invalid payroll amount' USING ERRCODE='23514';
     END IF;
     IF entry.key=ANY(snapshot_keys) THEN
       p_changes=jsonb_set(p_changes,ARRAY[entry.key],to_jsonb(round(amount,2)));
     END IF;
   END IF;
 END LOOP;
 SELECT to_jsonb(r) INTO desired FROM jsonb_populate_record(NULL::public.payroll,prior||p_changes) r;
 IF desired=prior THEN RETURN prior; END IF;
 INSERT INTO app_private.payroll_adjustments(payroll_id,employee_id,period,before_row,after_row,reason,adjusted_by,transaction_id)
 VALUES(p_payroll_id,prior->>'employee_id',(prior->>'period')::date,prior,desired,trim(p_reason),actor,txid_current()) RETURNING id INTO audit_id;
 SELECT string_agg(format('%I=r.%I',key,key),',') INTO assignments FROM jsonb_object_keys(p_changes) AS keys(key);
 PERFORM set_config('app.payroll_general_adjustment_id',audit_id::text,true);
 EXECUTE 'UPDATE public.payroll p SET '||assignments||',updated_at=clock_timestamp() FROM jsonb_populate_record(NULL::public.payroll,$1) r WHERE p.id::text=$2 RETURNING to_jsonb(p)'
   USING desired,p_payroll_id INTO result;
 PERFORM set_config('app.payroll_general_adjustment_id',coalesce(previous_context,''),true);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.adjust_payroll(text,jsonb,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.adjust_payroll(text,jsonb,jsonb,text) TO authenticated;
