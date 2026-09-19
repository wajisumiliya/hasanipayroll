alter table public.overtime_requests
  add column if not exists branch_approved_name text;

update public.overtime_requests
set branch_approved_name = branch_id
where branch_approved_at is not null
  and nullif(trim(branch_approved_name), '') is null;

alter table public.overtime_requests
  drop constraint if exists overtime_requests_branch_approver_name_check;

alter table public.overtime_requests
  add constraint overtime_requests_branch_approver_name_check
  check (
    branch_approved_at is null
    or nullif(trim(branch_approved_name), '') is not null
  );

comment on column public.overtime_requests.branch_approved_name is
  'Human-readable name entered by the branch staff member who reviewed the OT request.';
