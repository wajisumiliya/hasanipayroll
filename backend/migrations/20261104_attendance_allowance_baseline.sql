-- Record the configured entitlement before payroll removes the full allowance.
-- Historical rows stay NULL: current defaults cannot prove historical amounts.
ALTER TABLE public.payroll
  ADD COLUMN IF NOT EXISTS attendance_allowance_default numeric(12,2)
  CHECK (attendance_allowance_default >= 0);
