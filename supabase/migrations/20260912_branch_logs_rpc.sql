-- Reliable, role-checked API for reading branch audit logs.
create or replace function public.admin_branch_activity_logs(
  p_branch_id text default null,
  p_start timestamptz default null,
  p_end timestamptz default null,
  p_limit integer default 500
)
returns setof public.branch_activity_logs
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.current_app_role() not in ('admin', 'administrator') then
    raise exception 'Administrator access required';
  end if;

  return query
  select logs.*
  from public.branch_activity_logs logs
  where (nullif(trim(p_branch_id), '') is null
      or public.normalized_branch_key(logs.branch_id) = public.normalized_branch_key(p_branch_id))
    and (p_start is null or logs.opened_at >= p_start)
    and (p_end is null or logs.opened_at < p_end)
  order by logs.opened_at desc
  limit greatest(1, least(coalesce(p_limit, 500), 2000));
end;
$$;

revoke all on function public.admin_branch_activity_logs(text, timestamptz, timestamptz, integer) from public;
grant execute on function public.admin_branch_activity_logs(text, timestamptz, timestamptz, integer) to authenticated;