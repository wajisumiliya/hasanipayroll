-- Payslip notifications are released once per month instead of immediately
-- when payroll is generated. pg_cron uses UTC, so 09:15 UTC is 17:15 in
-- Malaysia (Asia/Kuala_Lumpur, UTC+8).

create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.release_monthly_payslip_notifications()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  malaysia_now timestamp := timezone('Asia/Kuala_Lumpur', now());
  payslip_month date;
  notification_body text;
  inserted_count integer := 0;
begin
  payslip_month := date_trunc('month', malaysia_now - interval '1 month')::date;
  notification_body := format(
    'Your %s payslip is ready to view.',
    to_char(payslip_month, 'FMMonth YYYY')
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
    notification_body,
    'payslip',
    'employee',
    null,
    trim(p.employee_id::text)
  from public.payroll p
  where date_trunc('month', p.period::timestamp)::date = payslip_month
    and p.is_published = true
    and nullif(trim(p.employee_id::text), '') is not null
    and not exists (
      select 1
      from public.app_notifications n
      where n.audience = 'employee'
        and n.notification_type = 'payslip'
        and n.employee_id = trim(p.employee_id::text)
        and n.body = notification_body
    );

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

comment on function public.release_monthly_payslip_notifications() is
  'Releases previous-month payslip notifications on the monthly payroll notification schedule.';

revoke all on function public.release_monthly_payslip_notifications()
  from public, anon, authenticated;
grant execute on function public.release_monthly_payslip_notifications()
  to service_role;

do $$
declare
  existing_job_id bigint;
begin
  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'release-monthly-payslip-notifications'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
end;
$$;

select cron.schedule(
  'release-monthly-payslip-notifications',
  '15 9 5 * *',
  $$select public.release_monthly_payslip_notifications();$$
);
