create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null,
  employee_name text not null,
  branch_id text not null,
  department text,
  designation text,
  leave_type text not null check (leave_type in ('Annual Leave', 'Unpaid Leave', 'Emergency Leave', 'Replacement Leave')),
  start_date date not null,
  end_date date not null,
  total_days integer not null check (total_days > 0),
  reason text not null,
  address_during_leave text,
  emergency_phone text,
  status text not null default 'pending_branch'
    check (status in ('pending_branch', 'pending_admin', 'approved', 'rejected')),
  branch_remarks text,
  branch_approved_at timestamptz,
  branch_approved_by uuid references auth.users(id),
  branch_approved_name text,
  admin_remarks text,
  admin_approved_at timestamptz,
  admin_approved_by uuid references auth.users(id),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint leave_requests_date_order check (end_date >= start_date)
);

create index if not exists leave_requests_employee_idx
  on public.leave_requests (employee_id, submitted_at desc);
create index if not exists leave_requests_branch_status_idx
  on public.leave_requests (lower(trim(branch_id)), status, submitted_at desc);

alter table public.leave_requests enable row level security;

create policy leave_requests_employee_read on public.leave_requests
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );

create policy leave_requests_employee_insert on public.leave_requests
  for insert to authenticated
  with check (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
    and status = 'pending_branch'
    and branch_approved_at is null
    and admin_approved_at is null
    and exists (
      select 1 from public.employees e
      where e.employee_id = leave_requests.employee_id
        and lower(trim(e.branch_id)) = lower(trim(leave_requests.branch_id))
        and upper(coalesce(e.address, '')) not like '%FRN%'
    )
  );

create policy leave_requests_branch_read on public.leave_requests
  for select to authenticated
  using (
    public.current_app_role() = 'branch'
    and lower(trim(branch_id)) = lower(trim(public.current_branch_id()))
  );

create policy leave_requests_branch_update on public.leave_requests
  for update to authenticated
  using (
    public.current_app_role() = 'branch'
    and lower(trim(branch_id)) = lower(trim(public.current_branch_id()))
    and status = 'pending_branch'
  )
  with check (
    lower(trim(branch_id)) = lower(trim(public.current_branch_id()))
    and status in ('pending_admin', 'rejected')
    and admin_approved_at is null
    and admin_approved_by is null
  );

create policy leave_requests_admin_all on public.leave_requests
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');

create or replace function public.enforce_leave_request_approval()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  if new.status = 'pending_admin' then
    if old.status <> 'pending_branch' or new.branch_approved_at is null
       or new.branch_approved_by is null or trim(coalesce(new.branch_approved_name, '')) = '' then
      raise exception 'Complete branch approval is required';
    end if;
  elsif new.status = 'approved' then
    if old.status <> 'pending_admin' or new.admin_approved_at is null
       or new.admin_approved_by is null then
      raise exception 'Branch approval is required before admin approval';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_leave_request_approval_trigger on public.leave_requests;
create trigger enforce_leave_request_approval_trigger
before update on public.leave_requests
for each row execute function public.enforce_leave_request_approval();
