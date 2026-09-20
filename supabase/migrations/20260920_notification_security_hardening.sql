-- Harden notification device registration.
-- Device ownership/branch scope must come from trusted JWT app_metadata, never
-- from caller-supplied employee or branch identifiers.

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
  v_employee_id text := nullif(public.current_employee_id(), '');
  v_branch_id text := nullif(public.current_branch_id(), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if nullif(trim(p_token), '') is null then
    raise exception 'Notification token is required.';
  end if;

  if v_role = 'employee' and v_employee_id is null then
    raise exception 'Employee identity is missing.';
  end if;

  if v_role = 'branch' and v_branch_id is null then
    raise exception 'Branch identity is missing.';
  end if;

  if v_role not in ('admin', 'branch', 'employee') then
    raise exception 'Notification registration is not permitted.';
  end if;

  insert into public.notification_devices (
    token,
    employee_id,
    branch_id,
    platform,
    updated_at
  ) values (
    trim(p_token),
    case when v_role = 'employee' then v_employee_id else null end,
    case when v_role = 'branch' then v_branch_id else null end,
    left(coalesce(nullif(trim(p_platform), ''), 'unknown'), 40),
    now()
  )
  on conflict (token) do update set
    employee_id = excluded.employee_id,
    branch_id = excluded.branch_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;

revoke all on function public.register_notification_device(text, text, text, text)
  from public, anon;
grant execute on function public.register_notification_device(text, text, text, text)
  to authenticated, service_role;
