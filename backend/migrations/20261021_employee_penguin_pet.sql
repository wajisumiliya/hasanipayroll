-- Private, server-owned pet state. No direct client grants.
CREATE SCHEMA IF NOT EXISTS app_private;
CREATE TABLE IF NOT EXISTS app_private.employee_penguin_pets (
 employee_id text PRIMARY KEY REFERENCES public.employees(employee_id) ON DELETE CASCADE,
 adopted_at timestamptz NOT NULL DEFAULT now(),
 nickname text NOT NULL DEFAULT 'Pingu',
 last_fed_at timestamptz,
 last_played_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON app_private.employee_penguin_pets FROM PUBLIC, anon, authenticated;
