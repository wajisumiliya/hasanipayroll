-- Remove the legacy permissive employee_requests policy superseded by
-- role-scoped Admin and Branch policies in the RLS lockdown migration.
-- Anonymous users must not read or mutate employee onboarding requests.

drop policy if exists "employee request app access"
  on public.employee_requests;

revoke all on table public.employee_requests from anon;

-- Approval is an authenticated Admin RPC; the function itself verifies the
-- trusted app_metadata role before changing employee/request data.
revoke execute on function public.approve_employee_request(uuid, text)
  from public, anon;
grant execute on function public.approve_employee_request(uuid, text)
  to authenticated;
