-- Preserve existing status policies while accepting UL and the corrected label.
DO $$
DECLARE
  target record;
  attr record;
  constraint_row record;
  expr text;
  correct_exists boolean;
  legacy_exists boolean;
BEGIN
  FOR target IN SELECT * FROM (VALUES ('attendance','status'),('daily_rosters','assignment_type')) AS t(table_name,column_name)
  LOOP
    SELECT a.attnum,t.typtype,n.nspname,t.typname INTO attr
    FROM pg_attribute a JOIN pg_type t ON t.oid=a.atttypid JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE a.attrelid=to_regclass('public.'||target.table_name) AND a.attname=target.column_name AND NOT a.attisdropped;
    IF NOT FOUND THEN CONTINUE; END IF;
    IF attr.typtype='e' THEN
      SELECT EXISTS(SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid JOIN pg_namespace n ON n.oid=t.typnamespace
        WHERE n.nspname=attr.nspname AND t.typname=attr.typname AND e.enumlabel='PH-GANTI') INTO correct_exists;
      SELECT EXISTS(SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid JOIN pg_namespace n ON n.oid=t.typnamespace
        WHERE n.nspname=attr.nspname AND t.typname=attr.typname AND e.enumlabel='PH-GUNTI') INTO legacy_exists;
      IF legacy_exists AND NOT correct_exists THEN
        EXECUTE format('ALTER TYPE %I.%I RENAME VALUE %L TO %L',attr.nspname,attr.typname,'PH-GUNTI','PH-GANTI');
      ELSIF legacy_exists AND correct_exists THEN
        EXECUTE format('UPDATE public.%I SET %I=%L WHERE %I::text=%L',target.table_name,target.column_name,'PH-GANTI',target.column_name,'PH-GUNTI');
      END IF;
      EXECUTE format('ALTER TYPE %I.%I ADD VALUE IF NOT EXISTS %L',attr.nspname,attr.typname,'PH-GANTI');
      EXECUTE format('ALTER TYPE %I.%I ADD VALUE IF NOT EXISTS %L',attr.nspname,attr.typname,'UL');
      -- Avoid using newly added enum values before the migration transaction commits.
    ELSE
      FOR constraint_row IN SELECT c.conname,c.conbin,c.conrelid FROM pg_constraint c
        WHERE c.conrelid=to_regclass('public.'||target.table_name) AND c.contype='c'
          AND c.conkey=ARRAY[attr.attnum]::smallint[]
      LOOP
        expr=pg_get_expr(constraint_row.conbin,constraint_row.conrelid);
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I',target.table_name,constraint_row.conname);
        EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I CHECK ((%s) OR %I IN (%L,%L)) NOT VALID',
          target.table_name,constraint_row.conname,expr,target.column_name,'UL','PH-GANTI');
        EXECUTE format('ALTER TABLE public.%I VALIDATE CONSTRAINT %I',target.table_name,constraint_row.conname);
      END LOOP;
      EXECUTE format('UPDATE public.%I SET %I=%L WHERE %I=%L',target.table_name,target.column_name,'PH-GANTI',target.column_name,'PH-GUNTI');
    END IF;
  END LOOP;
END $$;
