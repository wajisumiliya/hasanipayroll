CREATE TABLE IF NOT EXISTS app_private.anniversary_wishes (
  employee_id text NOT NULL,
  anniversary_year integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (employee_id, anniversary_year)
);
REVOKE ALL ON app_private.anniversary_wishes FROM PUBLIC, anon, authenticated;
