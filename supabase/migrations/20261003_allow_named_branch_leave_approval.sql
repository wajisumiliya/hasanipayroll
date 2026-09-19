-- Branch portal accounts may not have an auth.users UUID. The recorded
-- approver name, mandatory remarks and timestamp provide the branch audit.
create or replace function public.enforce_leave_request_approval()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();

  if new.status = 'pending_admin' then
    if old.status <> 'pending_branch'
       or new.branch_approved_at is null
       or nullif(trim(new.branch_approved_name), '') is null
       or nullif(trim(new.branch_remarks), '') is null then
      raise exception 'Complete branch approval is required';
    end if;
  elsif new.status = 'approved' then
    if old.status <> 'pending_admin'
       or new.admin_approved_at is null
       or nullif(trim(new.admin_remarks), '') is null then
      raise exception 'Complete admin approval is required';
    end if;
  elsif new.status = 'rejected' then
    if old.status = 'pending_branch'
       and nullif(trim(new.branch_remarks), '') is null then
      raise exception 'Branch remarks are required';
    elsif old.status = 'pending_admin'
       and nullif(trim(new.admin_remarks), '') is null then
      raise exception 'Admin remarks are required';
    end if;
  end if;

  return new;
end;
$$;
