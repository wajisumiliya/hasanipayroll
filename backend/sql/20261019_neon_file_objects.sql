-- Apply only to a reviewed Neon staging branch first.
-- Binary file storage is limited to 5 MiB per object in the application layer.
-- API must authenticate and authorize access; never expose this table directly.
CREATE TABLE IF NOT EXISTS public.payroll_file_objects (
  id uuid PRIMARY KEY,
  owner_employee_id text NOT NULL,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  file_bytes bytea NOT NULL CHECK (octet_length(file_bytes) BETWEEN 1 AND 5242880),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payroll_file_objects_owner_idx
  ON public.payroll_file_objects (owner_employee_id);
REVOKE ALL ON public.payroll_file_objects FROM PUBLIC;
