create table if not exists public.daily_reports (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null,
  report_date date not null,
  attendance integer not null default 0,
  unpaid_leave integer not null default 0,
  weekly_leave integer not null default 0,
  annual_leave integer not null default 0,
  air_conditioner integer not null default 0,
  maintenance_total integer not null default 0,
  working_condition integer not null default 0,
  service_repair integer not null default 0,
  maintenance_report text,
  orsanco jsonb not null default '{}'::jsonb,
  report_crew text,
  recommendation text,
  reported_by text not null,
  branch_stamp text,
  hq_comment text,
  reviewed_at timestamptz,
  reviewed_by text,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, report_date)
);

create index if not exists daily_reports_date_idx
  on public.daily_reports (report_date desc, branch_id);

alter table public.daily_reports enable row level security;
revoke all on public.daily_reports from anon, authenticated;
grant select, insert, update on public.daily_reports to authenticated;

create policy daily_reports_branch_read on public.daily_reports for select to authenticated
using (public.current_app_role() = 'branch' and lower(trim(branch_id)) = lower(trim(public.current_branch_id())));
create policy daily_reports_branch_insert on public.daily_reports for insert to authenticated
with check (public.current_app_role() = 'branch' and lower(trim(branch_id)) = lower(trim(public.current_branch_id())) and reviewed_at is null);
create policy daily_reports_admin_read on public.daily_reports for select to authenticated
using (public.current_app_role() in ('admin', 'request_admin'));
create policy daily_reports_admin_update on public.daily_reports for update to authenticated
using (public.current_app_role() in ('admin', 'request_admin'))
with check (public.current_app_role() in ('admin', 'request_admin'));

create policy ot_request_admin_reviewer_read on public.overtime_requests for select to authenticated
using (public.current_app_role() = 'request_admin');
create policy ot_request_admin_reviewer_update on public.overtime_requests for update to authenticated
using (public.current_app_role() = 'request_admin' and status = 'pending_admin')
with check (public.current_app_role() = 'request_admin' and status in ('approved', 'rejected'));
create policy leave_request_admin_reviewer_read on public.leave_requests for select to authenticated
using (public.current_app_role() = 'request_admin');
create policy leave_request_admin_reviewer_update on public.leave_requests for update to authenticated
using (public.current_app_role() = 'request_admin' and status = 'pending_admin')
with check (public.current_app_role() = 'request_admin' and status in ('approved', 'rejected'));

insert into public."app_user" ("id", "username", "email", "passwordHash", "role", "isActive", "mustChangePassword", "passwordChangedAt", "createdAt", "updatedAt")
values (gen_random_uuid()::text, 'hbreq', 'hbreq', '$2b$12$O6sRmPbMDpF8iovrfIHJeOox6ud51yD3vcE9hygO7iETQPJ.R9l/W', 'ADMIN', true, false, now(), now(), now())
on conflict ("email") do update set "username" = excluded."username", "passwordHash" = excluded."passwordHash", "role" = 'ADMIN', "isActive" = true, "mustChangePassword" = false, "passwordChangedAt" = now(), "updatedAt" = now();
