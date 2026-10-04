-- An administrator's publish action approves a payslip for release. Employees
-- may only read it from 21:00 Malaysia time on the fifth day of the following
-- month. The notification job runs at that same instant (13:00 UTC).

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
    and now() >= (
      date_trunc('month', period::timestamp)
      + interval '1 month 4 days 21 hours'
    ) at time zone 'Asia/Kuala_Lumpur'
  )
);

comment on column public.payroll.is_published is
  'Admin approval for scheduled employee release at 21:00 MYT on the fifth day of the following month.';

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
  '0 13 5 * *',
  $$select public.release_monthly_payslip_notifications();$$
);
