-- Run as the database owner in the SQL editor, as one complete transaction.
-- Only these two values select the employee. This script is NOT a startup migration.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
SELECT pg_advisory_xact_lock(hashtext('hasani-application-schema'));
CREATE TEMP TABLE employee_rename_parameters(old_id text, new_id text) ON COMMIT DROP;
INSERT INTO employee_rename_parameters VALUES ('HED-TEMP-022', 'INTN-AMJ-1001');

CREATE TEMP TABLE employee_rename_columns ON COMMIT DROP AS
SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name,
       a.atttypid, 0::bigint AS old_rows, ''::text AS row_digest
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid=a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','app_private') AND c.relkind IN ('r','p')
  AND NOT c.relispartition AND a.attnum>0 AND NOT a.attisdropped
  AND a.attname IN ('employee_id','employeeId','assigned_employee_id');

CREATE TEMP TABLE employee_rename_foreign_keys ON COMMIT DROP AS
SELECT n.nspname AS schema_name, t.relname AS table_name, c.conname,
       c.condeferrable, c.condeferred, c.confupdtype
FROM pg_catalog.pg_constraint c
JOIN pg_catalog.pg_class t ON t.oid=c.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace
WHERE c.contype='f' AND c.confrelid='public.employees'::regclass
  AND (SELECT attnum FROM pg_catalog.pg_attribute
       WHERE attrelid=c.confrelid AND attname='employee_id')=ANY(c.confkey);

CREATE TEMP TABLE employee_rename_triggers ON COMMIT DROP AS
SELECT n.nspname AS schema_name, c.relname AS table_name, t.tgname, t.tgenabled
FROM pg_catalog.pg_trigger t
JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE NOT t.tgisinternal AND EXISTS (
  SELECT 1 FROM employee_rename_columns r
  WHERE r.schema_name=n.nspname AND r.table_name=c.relname);

-- Reproduce the application's exact JSON field order, not jsonb's sorted order.
-- A matching old hash is required before any review can be moved.
CREATE OR REPLACE FUNCTION pg_temp.employee_rename_review_hash(
  branch text, employee text, snapshot jsonb
) RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $hash$
DECLARE fields text[]; field text; payload text;
BEGIN
  IF snapshot->>'type'='arrival' THEN
    fields:=ARRAY['date','type','minutes','scheduled','actual'];
    IF snapshot ? 'minutes_known' OR snapshot ? 'source' THEN
      fields:=fields || ARRAY['minutes_known','source'];
    END IF;
  ELSIF snapshot->>'type'='break' THEN
    fields:=ARRAY['date','type','minutes','allocated_minutes','actual_minutes'];
  ELSE
    RAISE EXCEPTION 'Unrecognized late review snapshot; rename rolled back.';
  END IF;
  payload:='{"branch_id":'||to_json(branch)::text||',"employee_id":'||to_json(employee)::text;
  FOREACH field IN ARRAY fields LOOP
    IF NOT snapshot ? field THEN
      RAISE EXCEPTION 'Incomplete late review snapshot; rename rolled back.';
    END IF;
    payload:=payload||','||to_json(field)::text||':'||(snapshot->field)::text;
  END LOOP;
  RETURN encode(sha256(convert_to(payload||'}','UTF8')),'hex');
END $hash$;

DO $rename$
DECLARE old_employee text; new_employee text; r record; t record;
        source_count bigint; target_count bigint; remaining bigint; digest text;
        ignored text[]; new_fingerprint text;
BEGIN
  SELECT old_id,new_id INTO STRICT old_employee,new_employee FROM employee_rename_parameters;
  IF old_employee=new_employee OR old_employee !~ '^[A-Z0-9._-]{1,100}$'
     OR new_employee !~ '^[A-Z0-9._-]{1,100}$' THEN
    RAISE EXCEPTION 'Invalid employee IDs; rename rolled back.';
  END IF;
  -- Lock every affected real table. Views such as payroll_ordered are derived
  -- from their source tables and are never updated directly.
  FOR r IN SELECT DISTINCT schema_name,table_name FROM employee_rename_columns
      ORDER BY schema_name,table_name LOOP
    EXECUTE format('LOCK TABLE %I.%I IN SHARE ROW EXCLUSIVE MODE',r.schema_name,r.table_name);
  END LOOP;
  IF (SELECT count(*) FROM public.employees WHERE employee_id=old_employee)<>1 THEN
    RAISE EXCEPTION 'Source employee % does not exist exactly once.',old_employee;
  END IF;
  IF EXISTS (SELECT 1 FROM employee_rename_columns
      WHERE atttypid NOT IN ('text'::regtype,'varchar'::regtype,'bpchar'::regtype)) THEN
    RAISE EXCEPTION 'Unsupported employee-ID column type; rename rolled back.';
  END IF;
  IF EXISTS (SELECT 1 FROM employee_rename_columns GROUP BY schema_name,table_name HAVING count(*)>1) THEN
    RAISE EXCEPTION 'Multiple employee-ID columns in one table require explicit review.';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid
      WHERE n.nspname IN ('public','app_private') AND c.relkind='m'
        AND a.attnum>0 AND NOT a.attisdropped
        AND a.attname IN ('employee_id','employeeId','assigned_employee_id')) THEN
    RAISE EXCEPTION 'Employee-ID materialized views need an explicit refresh plan; rename rolled back.';
  END IF;
  IF EXISTS (SELECT 1 FROM employee_rename_foreign_keys WHERE confupdtype='r') THEN
    RAISE EXCEPTION 'A RESTRICT foreign key needs explicit review before this rename.';
  END IF;
  -- All referencing FKs must be represented in our locked/updateable tables.
  IF EXISTS (SELECT 1 FROM employee_rename_foreign_keys f WHERE NOT EXISTS (
      SELECT 1 FROM employee_rename_columns refs
      WHERE refs.schema_name=f.schema_name AND refs.table_name=f.table_name)) THEN
    RAISE EXCEPTION 'Unrecognized employee foreign-key table; rename rolled back.';
  END IF;

  FOR r IN SELECT * FROM employee_rename_columns ORDER BY schema_name,table_name LOOP
    EXECUTE format('SELECT count(*) FROM %I.%I WHERE %I=$1',
      r.schema_name,r.table_name,r.column_name) INTO target_count USING new_employee;
    IF target_count<>0 THEN
      RAISE EXCEPTION 'Target ID % already has records in %.%; no records were merged.',
        new_employee,r.schema_name,r.table_name;
    END IF;
    ignored:=ARRAY[r.column_name];
    IF r.schema_name='app_private' AND r.table_name='late_report_reviews' THEN
      ignored:=ignored||ARRAY['event_fingerprint','event_snapshot'];
    END IF;
    EXECUTE format('SELECT count(*),md5(coalesce(string_agg((to_jsonb(t)-$2::text[])::text,E''\n'' ORDER BY (to_jsonb(t)-$2::text[])::text),'''')) FROM %I.%I t WHERE %I=$1',
      r.schema_name,r.table_name,r.column_name) INTO source_count,digest USING old_employee,ignored;
    IF source_count>0 AND r.table_name<>'late_report_reviews' AND EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema=r.schema_name AND c.table_name=r.table_name
        AND (c.column_name LIKE '%fingerprint%' OR c.column_name LIKE '%signature%')) THEN
      RAISE EXCEPTION 'Signed records in %.% need an application-aware rename; transaction rolled back.',
        r.schema_name,r.table_name;
    END IF;
    UPDATE employee_rename_columns SET old_rows=source_count,row_digest=digest
      WHERE schema_name=r.schema_name AND table_name=r.table_name;
  END LOOP;

  IF to_regclass('app_private.late_report_reviews') IS NOT NULL THEN
    FOR r IN SELECT * FROM app_private.late_report_reviews WHERE employee_id=old_employee LOOP
      IF r.event_fingerprint IS DISTINCT FROM pg_temp.employee_rename_review_hash(
          r.branch_id,old_employee,r.event_snapshot) THEN
        RAISE EXCEPTION 'Late review % uses an unsupported signature; rename rolled back.',r.id;
      END IF;
    END LOOP;
  END IF;

  -- Temporarily defer integrity checks; never drop or disable foreign keys.
  FOR r IN SELECT * FROM employee_rename_foreign_keys LOOP
    EXECUTE format('ALTER TABLE %I.%I ALTER CONSTRAINT %I DEFERRABLE INITIALLY DEFERRED',
      r.schema_name,r.table_name,r.conname);
  END LOOP;
  SET CONSTRAINTS ALL DEFERRED;
  -- ID-only maintenance must not recalculate payroll increments, salary
  -- settings or attendance shift snapshots. Table locks block concurrent writes.
  FOR t IN SELECT * FROM employee_rename_triggers WHERE tgenabled<>'D' LOOP
    EXECUTE format('ALTER TABLE %I.%I DISABLE TRIGGER %I',t.schema_name,t.table_name,t.tgname);
  END LOOP;

  -- Move children first with deferred FKs, then the employee. This avoids
  -- duplicate increment snapshots during ON UPDATE CASCADE processing.
  FOR r IN SELECT * FROM employee_rename_columns
      ORDER BY (schema_name='public' AND table_name='employees'),schema_name,table_name LOOP
    EXECUTE format('UPDATE %I.%I SET %I=$1 WHERE %I=$2',
      r.schema_name,r.table_name,r.column_name,r.column_name) USING new_employee,old_employee;
  END LOOP;

  IF to_regclass('app_private.late_report_reviews') IS NOT NULL THEN
    FOR r IN SELECT * FROM app_private.late_report_reviews WHERE employee_id=new_employee LOOP
      new_fingerprint:=pg_temp.employee_rename_review_hash(r.branch_id,new_employee,r.event_snapshot);
      UPDATE app_private.late_report_reviews
        SET event_fingerprint=new_fingerprint,
            event_snapshot=event_snapshot||jsonb_build_object(
              'fingerprint',new_fingerprint,
              'employee_id_rename',jsonb_build_object('old_id',old_employee,'new_id',new_employee,
                'previous_fingerprint',r.event_fingerprint,
                'previous_rename',r.event_snapshot->'employee_id_rename'))
        WHERE id=r.id;
    END LOOP;
  END IF;

  -- Verify every linked-row count and every non-ID value before committing.
  FOR r IN SELECT * FROM employee_rename_columns LOOP
    ignored:=ARRAY[r.column_name];
    IF r.schema_name='app_private' AND r.table_name='late_report_reviews' THEN
      ignored:=ignored||ARRAY['event_fingerprint','event_snapshot'];
    END IF;
    EXECUTE format('SELECT count(*) FROM %I.%I WHERE %I=$1',
      r.schema_name,r.table_name,r.column_name) INTO remaining USING old_employee;
    EXECUTE format('SELECT count(*),md5(coalesce(string_agg((to_jsonb(t)-$2::text[])::text,E''\n'' ORDER BY (to_jsonb(t)-$2::text[])::text),'''')) FROM %I.%I t WHERE %I=$1',
      r.schema_name,r.table_name,r.column_name) INTO target_count,digest USING new_employee,ignored;
    IF remaining<>0 OR target_count<>r.old_rows OR digest IS DISTINCT FROM r.row_digest THEN
      RAISE EXCEPTION 'Verification failed for %.%; rename rolled back.',r.schema_name,r.table_name;
    END IF;
  END LOOP;
  SET CONSTRAINTS ALL IMMEDIATE;
  FOR r IN SELECT * FROM employee_rename_foreign_keys LOOP
    EXECUTE format('ALTER TABLE %I.%I ALTER CONSTRAINT %I %s',r.schema_name,r.table_name,r.conname,
      CASE WHEN NOT r.condeferrable THEN 'NOT DEFERRABLE'
           WHEN r.condeferred THEN 'DEFERRABLE INITIALLY DEFERRED'
           ELSE 'DEFERRABLE INITIALLY IMMEDIATE' END);
  END LOOP;
  FOR t IN SELECT * FROM employee_rename_triggers WHERE tgenabled<>'D' LOOP
    EXECUTE format('ALTER TABLE %I.%I %s TRIGGER %I',t.schema_name,t.table_name,
      CASE t.tgenabled WHEN 'A' THEN 'ENABLE ALWAYS' WHEN 'R' THEN 'ENABLE REPLICA' ELSE 'ENABLE' END,t.tgname);
  END LOOP;
END $rename$;

SELECT schema_name||'.'||table_name AS table_name,column_name,old_rows AS renamed_rows
FROM employee_rename_columns WHERE old_rows>0 ORDER BY schema_name,table_name;
COMMIT;
