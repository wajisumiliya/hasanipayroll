alter table public.overtime_requests
  add column if not exists branch_approved_at timestamptz,
  add column if not exists branch_approved_by uuid references auth.users(id),
  add column if not exists admin_approved_at timestamptz,
  add column if not exists admin_approved_by uuid references auth.users(id);

alter table public.overtime_requests
  drop constraint if exists overtime_requests_status_check;

update public.overtime_requests
set status = 'pending_branch'
where status = 'pending';

alter table public.overtime_requests
  add constraint overtime_requests_status_check
  check (status in ('pending_branch', 'pending_admin', 'approved', 'rejected'));

alter table public.overtime_requests
  alter column status set default 'pending_branch';

drop policy if exists overtime_requests_employee_insert
  on public.overtime_requests;
create policy overtime_requests_employee_insert on public.overtime_requests
  for insert to authenticated
  with check (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
    and status = 'pending_branch'
    and approved_minutes is null
    and branch_approved_at is null
    and branch_approved_by is null
    and admin_approved_at is null
    and admin_approved_by is null
    and reviewed_at is null
    and reviewed_by is null
    and exists (
      select 1 from public.employees e
      where e.employee_id = overtime_requests.employee_id
        and e.branch_id = overtime_requests.branch_id
    )
  );

create policy overtime_requests_branch_read on public.overtime_requests
  for select to authenticated
  using (public.current_app_role() = 'branch'
    and branch_id = public.current_branch_id());

create policy overtime_requests_branch_update on public.overtime_requests
  for update to authenticated
  using (public.current_app_role() = 'branch'
    and branch_id = public.current_branch_id()
    and status = 'pending_branch')
  with check (
    branch_id = public.current_branch_id()
    and status in ('pending_admin', 'rejected')
    and approved_minutes is null
    and admin_approved_at is null
    and admin_approved_by is null
  );

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
    if new.branch_approved_at is null or new.branch_approved_by is null then
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
