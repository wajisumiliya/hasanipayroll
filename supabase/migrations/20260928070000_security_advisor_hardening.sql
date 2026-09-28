-- Security Advisor hardening: revoke anonymous execution from SECURITY DEFINER
-- RPCs intended for signed-in application roles, and add covering
-- indexes for leave-request approval foreign keys.
-- No payroll calculation logic is changed.

revoke execute on function public.apply_employee_aquarium_decay(text) from public, anon;
revoke execute on function public.change_daily_report_pin(text, text) from public, anon;
revoke execute on function public.clean_employee_aquarium() from public, anon;
revoke execute on function public.feed_employee_aquarium() from public, anon;
revoke execute on function public.get_employee_aquarium() from public, anon;
revoke execute on function public.record_employee_aquarium_login() from public, anon;
revoke execute on function public.verify_daily_report_pin(text) from public, anon;

grant execute on function public.apply_employee_aquarium_decay(text) to authenticated;
grant execute on function public.change_daily_report_pin(text, text) to authenticated;
grant execute on function public.clean_employee_aquarium() to authenticated;
grant execute on function public.feed_employee_aquarium() to authenticated;
grant execute on function public.get_employee_aquarium() to authenticated;
grant execute on function public.record_employee_aquarium_login() to authenticated;
grant execute on function public.verify_daily_report_pin(text) to authenticated;

create index if not exists leave_requests_branch_approved_by_idx
  on public.leave_requests (branch_approved_by);
create index if not exists leave_requests_admin_approved_by_idx
  on public.leave_requests (admin_approved_by);
