-- Branch portal accounts can record a human approver name even when their
-- session has no auth.users UUID. Treat that name and approval timestamp as
-- the branch audit evidence required before final admin approval.

update public.overtime_requests
set branch_approved_at = coalesce(
      branch_approved_at,
      reviewed_at,
      submitted_at,
      now()
    ),
    branch_approved_name = coalesce(
      nullif(trim(branch_approved_name), ''),
      nullif(trim(branch_id), ''),
      'Branch approver'
    )
where status in ('pending_admin', 'approved');

create or replace function public.apply_approved_overtime_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'approved' then
    if old.status <> 'pending_admin' and old.status <> 'approved' then
      raise exception 'Branch approval is required before admin approval';
    end if;
    if new.branch_approved_at is null
       or nullif(trim(new.branch_approved_name), '') is null then
      raise exception 'Branch approval details are required';
    end if;
    if new.approved_minutes is null then
      raise exception 'Approved OT minutes are required';
    end if;

    update public.attendance
    set ot_requested = true,
        ot_authorized = true,
        approved_ot_minutes = new.approved_minutes
    where employee_id = new.employee_id
      and branch_id = new.branch_id
      and attendance_date = new.overtime_date;

    if not found then
      raise exception 'Attendance record not found for employee % on %',
        new.employee_id, new.overtime_date;
    end if;
  elsif new.status = 'rejected' then
    update public.attendance
    set ot_requested = false,
        ot_authorized = false,
        approved_ot_minutes = null
    where employee_id = new.employee_id
      and branch_id = new.branch_id
      and attendance_date = new.overtime_date;
  end if;
  return new;
end;
$$;

revoke execute on function public.apply_approved_overtime_request()
  from public, anon, authenticated;
