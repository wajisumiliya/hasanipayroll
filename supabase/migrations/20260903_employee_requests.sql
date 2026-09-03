create extension if not exists pgcrypto;

create table if not exists public.employee_requests (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null,
  name text not null,
  designation text,
  department text,
  email text,
  new_ic_no text,
  bank_code text,
  bank_account text,
  phone text,
  address text,
  joining_date date,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  assigned_employee_id text,
  admin_note text,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists employee_requests_status_requested_idx
  on public.employee_requests (status, requested_at desc);

create index if not exists employee_requests_branch_idx
  on public.employee_requests (branch_id, requested_at desc);

alter table public.employee_requests enable row level security;

create policy "employee request app access"
  on public.employee_requests
  for all
  to anon, authenticated
  using (true)
  with check (true);

create or replace function public.approve_employee_request(
  request_id uuid,
  new_employee_id text
)
returns public.employees
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.employee_requests;
  created_employee public.employees;
  clean_employee_id text := upper(trim(new_employee_id));
begin
  if clean_employee_id = '' then
    raise exception 'Employee ID is required.';
  end if;

  select * into request_row
  from public.employee_requests
  where id = request_id
  for update;

  if not found then
    raise exception 'Employee request was not found.';
  end if;

  if request_row.status <> 'PENDING' then
    raise exception 'Employee request has already been reviewed.';
  end if;

  insert into public.employees (
    employee_id, name, designation, department, email, new_ic_no,
    bank_code, bank_account, phone, address, joining_date,
    is_active, branch_id
  ) values (
    clean_employee_id, request_row.name, request_row.designation,
    request_row.department, request_row.email, request_row.new_ic_no,
    request_row.bank_code, request_row.bank_account, request_row.phone,
    request_row.address, request_row.joining_date, true,
    request_row.branch_id
  ) returning * into created_employee;

  update public.employee_requests
  set status = 'APPROVED',
      assigned_employee_id = clean_employee_id,
      reviewed_at = now()
  where id = request_id;

  return created_employee;
end;
$$;

grant execute on function public.approve_employee_request(uuid, text)
  to anon, authenticated;
