-- Harden privileged helper/trigger function execution privileges.
-- Trigger functions should never be directly callable by API roles.
-- Admin RPCs remain authenticated-only and enforce their own trusted JWT role checks.

revoke execute on function public.apply_approved_overtime_request()
  from public, anon, authenticated;

revoke execute on function public.audit_branch_data_change()
  from public, anon, authenticated;

revoke execute on function public.apply_employee_aquarium_decay(text)
  from public, anon, authenticated;

revoke execute on function public.admin_branch_activity_logs(
  text, timestamptz, timestamptz, integer
) from public, anon;
grant execute on function public.admin_branch_activity_logs(
  text, timestamptz, timestamptz, integer
) to authenticated;

revoke execute on function public.transfer_staff(text, text, date, text)
  from public, anon;
grant execute on function public.transfer_staff(text, text, date, text)
  to authenticated;

revoke execute on function public.set_employee_active_status(text, boolean)
  from public, anon;
grant execute on function public.set_employee_active_status(text, boolean)
  to authenticated;
