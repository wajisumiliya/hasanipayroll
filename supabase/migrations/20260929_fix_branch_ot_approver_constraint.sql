create or replace function public.ensure_branch_ot_approver_name()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  prior_name text;
begin
  if tg_op = 'UPDATE' then
    prior_name := nullif(trim(old.branch_approved_name), '');
  end if;
  if new.branch_approved_at is not null
     and nullif(trim(new.branch_approved_name), '') is null then
    new.branch_approved_name := coalesce(
      prior_name,
      nullif(trim(new.branch_id), ''),
      'Branch approver'
    );
  end if;
  return new;
end;
$$;

revoke execute on function public.ensure_branch_ot_approver_name()
  from public, anon, authenticated;

drop trigger if exists overtime_request_ensure_branch_approver_name
  on public.overtime_requests;

create trigger overtime_request_ensure_branch_approver_name
before insert or update of branch_approved_at, branch_approved_name
on public.overtime_requests
for each row execute function public.ensure_branch_ot_approver_name();

update public.overtime_requests
set branch_approved_name = coalesce(
  nullif(trim(branch_approved_name), ''),
  nullif(trim(branch_id), ''),
  'Branch approver'
)
where branch_approved_at is not null
  and nullif(trim(branch_approved_name), '') is null;
