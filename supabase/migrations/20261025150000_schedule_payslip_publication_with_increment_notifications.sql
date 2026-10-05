-- Allow Admin to approve a payroll month and choose its employee release time.
-- At release time, payslips become visible and both payslip and increment
-- notifications are inserted in the same database transaction.

create extension if not exists pg_cron with schema pg_catalog;

alter table public.payroll
  add column if not exists release_at timestamptz;

-- Preserve the previously configured fifth-day 21:00 MYT release for payroll
-- rows that were already approved before per-month scheduling was introduced.
update public.payroll
set release_at = (
  date_trunc('month', period::timestamp)
  + interval '1 month 4 days 21 hours'
) at time zone 'Asia/Kuala_Lumpur'
where is_published = true
  and release_at is null;

create index if not exists payroll_release_at_idx
  on public.payroll (release_at)
  where is_published = true;

comment on column public.payroll.release_at is
  'Exact time when an Admin-approved payslip becomes visible to the employee.';

create table if not exists public.payslip_release_schedules (
  id uuid primary key default gen_random_uuid(),
  payroll_month date not null unique,
  release_at timestamptz not null,
  increment_employees jsonb not null default '[]'::jsonb,
  scheduled_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  released_at timestamptz,
  constraint payslip_release_increment_employees_array
    check (jsonb_typeof(increment_employees) = 'array')
);

alter table public.payslip_release_schedules enable row level security;
revoke all on public.payslip_release_schedules from anon, authenticated;

create or replace function public.release_due_payslips(
  p_schedule_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  schedule_row public.payslip_release_schedules%rowtype;
  payslip_body text;
  increment_body text;
  inserted_count integer := 0;
  affected_count integer := 0;
begin
  for schedule_row in
    select s.*
    from public.payslip_release_schedules s
    where s.released_at is null
      and s.release_at <= now()
      and (p_schedule_id is null or s.id = p_schedule_id)
    order by s.release_at
    for update skip locked
  loop
    update public.payroll p
    set
      is_published = true,
      release_at = schedule_row.release_at,
      published_at = coalesce(p.published_at, now()),
      published_by = coalesce(p.published_by, schedule_row.scheduled_by),
      updated_at = now()
    where date_trunc('month', p.period::timestamp)::date =
      schedule_row.payroll_month;

    payslip_body := format(
      'Your %s payslip is ready to view.',
      to_char(schedule_row.payroll_month, 'FMMonth YYYY')
    );

    insert into public.app_notifications (
      title,
      body,
      notification_type,
      audience,
      branch_id,
      employee_id
    )
    select distinct
      'New Payslip Available',
      payslip_body,
      'payslip',
      'employee',
      null,
      trim(p.employee_id::text)
    from public.payroll p
    where date_trunc('month', p.period::timestamp)::date =
        schedule_row.payroll_month
      and p.is_published = true
      and p.release_at <= now()
      and nullif(trim(p.employee_id::text), '') is not null
      and not exists (
        select 1
        from public.app_notifications n
        where n.audience = 'employee'
          and n.notification_type = 'payslip'
          and n.employee_id = trim(p.employee_id::text)
          and n.body = payslip_body
      );

    get diagnostics affected_count = row_count;
    inserted_count := inserted_count + affected_count;

    insert into public.app_notifications (
      title,
      body,
      notification_type,
      audience,
      branch_id,
      employee_id
    )
    select distinct
      'Salary Increment Confirmed',
      format(
        'Your RM %s salary increment is reflected in your %s payslip.',
        to_char(increment.increment_amount, 'FM999999990.00'),
        to_char(schedule_row.payroll_month, 'FMMonth YYYY')
      ),
      'increment',
      'employee',
      null,
      trim(increment.employee_id)
    from jsonb_to_recordset(schedule_row.increment_employees) as increment(
      employee_id text,
      increment_amount numeric
    )
    where nullif(trim(increment.employee_id), '') is not null
      and increment.increment_amount between 50 and 1000
      and mod(increment.increment_amount, 50) = 0
      and exists (
        select 1
        from public.payroll p
        where date_trunc('month', p.period::timestamp)::date =
            schedule_row.payroll_month
          and trim(p.employee_id::text) = trim(increment.employee_id)
          and p.is_published = true
          and p.release_at <= now()
      )
      and not exists (
        select 1
        from public.app_notifications n
        where n.audience = 'employee'
          and n.notification_type = 'increment'
          and n.employee_id = trim(increment.employee_id)
          and n.body = format(
            'Your RM %s salary increment is reflected in your %s payslip.',
            to_char(increment.increment_amount, 'FM999999990.00'),
            to_char(schedule_row.payroll_month, 'FMMonth YYYY')
          )
      );

    get diagnostics affected_count = row_count;
    inserted_count := inserted_count + affected_count;

    update public.payslip_release_schedules
    set released_at = now(), updated_at = now()
    where id = schedule_row.id;
  end loop;

  return inserted_count;
end;
$$;

comment on function public.release_due_payslips(uuid) is
  'Atomically releases scheduled payslips and creates payslip plus increment notifications.';

revoke all on function public.release_due_payslips(uuid)
  from public, anon, authenticated;
grant execute on function public.release_due_payslips(uuid) to service_role;

create or replace function public.schedule_monthly_payslip_release(
  p_payroll_month date,
  p_release_at timestamptz,
  p_increment_employees jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_month date := date_trunc('month', p_payroll_month)::date;
  schedule_id uuid;
  payroll_count integer := 0;
  increment_count integer := 0;
  actor text := coalesce(
    nullif(auth.jwt() ->> 'email', ''),
    auth.uid()::text,
    'admin'
  );
begin
  if public.current_app_role() <> 'admin' then
    raise exception 'Administrator access required';
  end if;
  if p_release_at is null then
    raise exception 'A payslip release time is required';
  end if;
  if p_release_at < now() - interval '1 minute' then
    raise exception 'Payslip release time cannot be in the past';
  end if;
  if p_increment_employees is null
      or jsonb_typeof(p_increment_employees) <> 'array' then
    raise exception 'Increment employees must be a JSON array';
  end if;

  select count(*)::integer
  into payroll_count
  from public.payroll p
  where date_trunc('month', p.period::timestamp)::date = target_month;

  if payroll_count = 0 then
    raise exception 'No payroll records exist for %',
      to_char(target_month, 'FMMonth YYYY');
  end if;

  select count(*)::integer
  into increment_count
  from jsonb_to_recordset(p_increment_employees) as increment(
    employee_id text,
    increment_amount numeric
  )
  where nullif(trim(increment.employee_id), '') is not null
    and increment.increment_amount between 50 and 1000
    and mod(increment.increment_amount, 50) = 0;

  insert into public.payslip_release_schedules (
    payroll_month,
    release_at,
    increment_employees,
    scheduled_by,
    released_at
  ) values (
    target_month,
    p_release_at,
    p_increment_employees,
    actor,
    null
  )
  on conflict (payroll_month) do update
  set
    release_at = excluded.release_at,
    increment_employees = excluded.increment_employees,
    scheduled_by = excluded.scheduled_by,
    released_at = null,
    updated_at = now()
  returning id into schedule_id;

  update public.payroll p
  set
    is_published = true,
    release_at = p_release_at,
    published_at = coalesce(p.published_at, now()),
    published_by = actor,
    updated_at = now()
  where date_trunc('month', p.period::timestamp)::date = target_month;

  if p_release_at <= now() then
    perform public.release_due_payslips(schedule_id);
  end if;

  return jsonb_build_object(
    'schedule_id', schedule_id,
    'payroll_count', payroll_count,
    'increment_count', increment_count,
    'release_at', p_release_at,
    'released', p_release_at <= now()
  );
end;
$$;

comment on function public.schedule_monthly_payslip_release(date, timestamptz, jsonb) is
  'Admin RPC that schedules all payslips and increment notifications for one payroll month.';

revoke all on function public.schedule_monthly_payslip_release(date, timestamptz, jsonb)
  from public, anon;
grant execute on function public.schedule_monthly_payslip_release(date, timestamptz, jsonb)
  to authenticated;

drop policy if exists payroll_read on public.payroll;
create policy payroll_read on public.payroll
for select to authenticated
using (
  public.current_app_role() = 'admin'
  or (
    public.current_app_role() = 'branch'
    and exists (
      select 1
      from public.employees e
      where e.employee_id = payroll.employee_id
        and e.branch_id = public.current_branch_id()
    )
  )
  or (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
    and is_published = true
    and release_at is not null
    and now() >= release_at
  )
);

comment on column public.payroll.is_published is
  'Admin approval for employee release at the payroll release_at time.';

do $$
declare
  existing_job record;
begin
  for existing_job in
    select jobid
    from cron.job
    where jobname in (
      'release-monthly-payslip-notifications',
      'release-due-payslips'
    )
  loop
    perform cron.unschedule(existing_job.jobid);
  end loop;
end;
$$;

select cron.schedule(
  'release-due-payslips',
  '* * * * *',
  $$select public.release_due_payslips();$$
);

notify pgrst, 'reload schema';
