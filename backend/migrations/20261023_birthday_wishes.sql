CREATE TABLE IF NOT EXISTS app_private.birthday_wishes (
  employee_id text NOT NULL,
  birthday_year integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (employee_id, birthday_year)
);
REVOKE ALL ON app_private.birthday_wishes FROM PUBLIC, anon, authenticated;
