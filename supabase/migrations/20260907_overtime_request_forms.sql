create extension if not exists pgcrypto;

create table if not exists public.overtime_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null,
  employee_name text not null,
  branch_id text not null,
  department text not null default '',
  overtime_date date not null,
  shift_start time,
  shift_end time,
  overtime_start time not null,
  overtime_end time not null,
  requested_minutes integer not null check (requested_minutes between 1 and 1440),
  reason text not null check (length(trim(reason)) > 0),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  approved_minutes integer check (approved_minutes is null or approved_minutes between 0 and 1440),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  unique (employee_id, branch_id, overtime_date)
);

create index if not exists overtime_requests_status_submitted_idx
  on public.overtime_requests (status, submitted_at desc);
create index if not exists overtime_requests_employee_date_idx
  on public.overtime_requests (employee_id, overtime_date desc);

alter table public.overtime_requests enable row level security;
revoke all on table public.overtime_requests from anon;

create policy overtime_requests_admin_all on public.overtime_requests
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');

create policy overtime_requests_employee_read on public.overtime_requests
  for select to authenticated
  using (public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id());

create policy overtime_requests_employee_insert on public.overtime_requests
  for insert to authenticated
  with check (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
    and status = 'pending'
    and approved_minutes is null
    and reviewed_at is null
    and reviewed_by is null
    and exists (
      select 1 from public.employees e
      where e.employee_id = overtime_requests.employee_id
        and e.branch_id = overtime_requests.branch_id
    )
  );

create or replace function public.apply_approved_overtime_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'approved' then
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

drop trigger if exists overtime_request_apply_approval on public.overtime_requests;
create trigger overtime_request_apply_approval
after update of status, approved_minutes on public.overtime_requests
for each row execute function public.apply_approved_overtime_request();

revoke all on function public.apply_approved_overtime_request() from public;
