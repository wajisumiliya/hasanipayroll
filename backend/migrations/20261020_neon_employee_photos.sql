-- Photo bytes are available only through the authenticated backend, never /api/data.
CREATE TABLE IF NOT EXISTS app_private.employee_photos (
  employee_id text PRIMARY KEY REFERENCES public.employees(employee_id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg','image/png','image/webp')),
  photo_bytes bytea NOT NULL CHECK (octet_length(photo_bytes) BETWEEN 1 AND 524288),
  updated_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON app_private.employee_photos FROM PUBLIC, anon, authenticated;
