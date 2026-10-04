-- Distinguish an Admin-entered OT value from an automatically calculated one.
-- A manual value of zero is intentional and disables automatic OT for that day.

alter table public.attendance
  add column if not exists ot_manual_override boolean not null default false;

comment on column public.attendance.ot_manual_override is
  'True when approved_ot_minutes was explicitly entered by Admin and must override automatic OT, including a zero-minute override.';
