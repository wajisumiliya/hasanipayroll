-- Requested at 2026-10-23 06:39:11 UTC: reveal one hour later.
-- Keep the existing 72-hour API contract, so installed clients need no update.
UPDATE app_private.mystery_egg_campaign
SET started_at = timestamptz '2026-10-23 07:39:11+00' - interval '72 hours'
WHERE id = 1;

CREATE TABLE IF NOT EXISTS app_private.mystery_egg_reminders (
  hatch_at timestamptz PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON app_private.mystery_egg_reminders FROM PUBLIC, anon, authenticated;
