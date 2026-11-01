CREATE TABLE IF NOT EXISTS app_private.birthday_wishes (
  employee_id text NOT NULL,
  birthday_year integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (employee_id, birthday_year)
);
REVOKE ALL ON app_private.birthday_wishes FROM PUBLIC;
-- Fresh Neon/PostgreSQL installs may not have the legacy browser roles yet.
-- Revoke existing roles without requiring or creating cluster-global roles.
DO $$
DECLARE role_name text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=role_name) THEN
      EXECUTE format('REVOKE ALL ON app_private.birthday_wishes FROM %I', role_name);
    END IF;
  END LOOP;
END $$;
