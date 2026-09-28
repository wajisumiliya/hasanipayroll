-- Harden notification device registration.
-- Device ownership/scope is derived only from trusted JWT app_metadata claims.
-- Caller-supplied employee/branch identifiers remain in the signature for
-- client compatibility but are intentionally ignored.

create or replace function public.register_notification_device(
  p_token text,
  p_employee_id text default null,
  p_branch_id text default null,
  p_platform text default 'unknown'
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := public.current_app_role();
  v_employee_id text := null;
  v_branch_id text := null;
  v_token text := trim(coalesce(p_token, ''));
  v_platform text := left(trim(coalesce(p_platform, 'unknown')), 32);
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if length(v_token) < 20 or length(v_token) > 4096 then
    raise exception 'Invalid notification token.';
  end if;

  if v_role = 'employee' then
    v_employee_id := nullif(public.current_employee_id(), '');
    v_branch_id := nullif(public.current_branch_id(), '');
    if v_employee_id is null then
      raise exception 'Employee identity is missing.';
    end if;
  elsif v_role = 'branch' then
    v_branch_id := nullif(public.current_branch_id(), '');
    if v_branch_id is null then
      raise exception 'Branch identity is missing.';
    end if;
  elsif v_role = 'admin' then
    v_employee_id := null;
    v_branch_id := null;
  else
    raise exception 'Authorized application role required.';
  end if;

  insert into public.notification_devices (
    token, employee_id, branch_id, platform, updated_at
  ) values (
    v_token, v_employee_id, v_branch_id, v_platform, now()
  )
  on conflict (token) do update set
    employee_id = excluded.employee_id,
    branch_id = excluded.branch_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;

revoke execute on function public.register_notification_device(text, text, text, text)
  from public, anon;
grant execute on function public.register_notification_device(text, text, text, text)
  to authenticated;
