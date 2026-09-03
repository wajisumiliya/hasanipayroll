alter table public.attendance
  add column if not exists approved_ot_minutes integer
  check (approved_ot_minutes is null or approved_ot_minutes between 0 and 1440);

comment on column public.attendance.approved_ot_minutes is
  'OT duration approved by an administrator. Payroll must use this value only.';
