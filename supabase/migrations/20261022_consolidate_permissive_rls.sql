-- Consolidate permissive RLS policies without changing application role access.
-- Mirrors the reviewed live policy state after the 2026-09-28 RLS performance audit.

-- Rosters
drop policy if exists daily_rosters_admin_all on public.daily_rosters;
drop policy if exists daily_rosters_branch_all on public.daily_rosters;
drop policy if exists daily_rosters_employee_read on public.daily_rosters;
drop policy if exists daily_rosters_write on public.daily_rosters;
drop policy if exists daily_rosters_read on public.daily_rosters;
drop policy if exists daily_rosters_insert on public.daily_rosters;
drop policy if exists daily_rosters_update on public.daily_rosters;
drop policy if exists daily_rosters_delete on public.daily_rosters;
create policy daily_rosters_read on public.daily_rosters for select to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy daily_rosters_insert on public.daily_rosters for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);
create policy daily_rosters_update on public.daily_rosters for update to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
) with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);
create policy daily_rosters_delete on public.daily_rosters for delete to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

drop policy if exists monthly_rosters_admin_all on public.monthly_rosters;
drop policy if exists monthly_rosters_branch_all on public.monthly_rosters;
drop policy if exists monthly_rosters_employee_read on public.monthly_rosters;
drop policy if exists monthly_rosters_write on public.monthly_rosters;
drop policy if exists monthly_rosters_read on public.monthly_rosters;
drop policy if exists monthly_rosters_insert on public.monthly_rosters;
drop policy if exists monthly_rosters_update on public.monthly_rosters;
drop policy if exists monthly_rosters_delete on public.monthly_rosters;
create policy monthly_rosters_read on public.monthly_rosters for select to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy monthly_rosters_insert on public.monthly_rosters for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);
create policy monthly_rosters_update on public.monthly_rosters for update to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
) with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);
create policy monthly_rosters_delete on public.monthly_rosters for delete to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

-- Daily reports
drop policy if exists daily_reports_admin_read on public.daily_reports;
drop policy if exists daily_reports_branch_read on public.daily_reports;
drop policy if exists daily_reports_read on public.daily_reports;
create policy daily_reports_read on public.daily_reports for select to authenticated using (
  public.current_app_role() in ('admin','request_admin')
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())))
);

-- EA forms
drop policy if exists employee_ea_forms_admin_all on public.employee_ea_forms;
drop policy if exists employee_ea_forms_self_read on public.employee_ea_forms;
drop policy if exists employee_ea_forms_read on public.employee_ea_forms;
drop policy if exists employee_ea_forms_insert on public.employee_ea_forms;
drop policy if exists employee_ea_forms_update on public.employee_ea_forms;
drop policy if exists employee_ea_forms_delete on public.employee_ea_forms;
create policy employee_ea_forms_read on public.employee_ea_forms for select to authenticated using (
  public.current_app_role() in ('admin','foreign_admin')
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy employee_ea_forms_insert on public.employee_ea_forms for insert to authenticated with check (public.current_app_role() in ('admin','foreign_admin'));
create policy employee_ea_forms_update on public.employee_ea_forms for update to authenticated using (public.current_app_role() in ('admin','foreign_admin')) with check (public.current_app_role() in ('admin','foreign_admin'));
create policy employee_ea_forms_delete on public.employee_ea_forms for delete to authenticated using (public.current_app_role() in ('admin','foreign_admin'));

-- Salary defaults
drop policy if exists employee_salary_defaults_admin_all on public.employee_salary_defaults;
drop policy if exists employee_salary_defaults_role_read on public.employee_salary_defaults;
drop policy if exists employee_salary_defaults_read on public.employee_salary_defaults;
drop policy if exists employee_salary_defaults_insert on public.employee_salary_defaults;
drop policy if exists employee_salary_defaults_update on public.employee_salary_defaults;
drop policy if exists employee_salary_defaults_delete on public.employee_salary_defaults;
create policy employee_salary_defaults_read on public.employee_salary_defaults for select to authenticated using (
  public.current_app_role() in ('admin','administrator')
  or (public.current_app_role()='branch' and exists (
    select 1 from public.employees e
    where e.employee_id=employee_salary_defaults.employee_id
      and public.normalized_branch_key(e.branch_id)=public.normalized_branch_key(public.current_branch_id())
  ))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy employee_salary_defaults_insert on public.employee_salary_defaults for insert to authenticated with check (public.current_app_role() in ('admin','administrator'));
create policy employee_salary_defaults_update on public.employee_salary_defaults for update to authenticated using (public.current_app_role() in ('admin','administrator')) with check (public.current_app_role() in ('admin','administrator'));
create policy employee_salary_defaults_delete on public.employee_salary_defaults for delete to authenticated using (public.current_app_role() in ('admin','administrator'));

-- Payroll
drop policy if exists payroll_admin_all on public.payroll;
drop policy if exists payroll_branch_read on public.payroll;
drop policy if exists payroll_self_read on public.payroll;
drop policy if exists payroll_read on public.payroll;
drop policy if exists payroll_insert on public.payroll;
drop policy if exists payroll_update on public.payroll;
drop policy if exists payroll_delete on public.payroll;
create policy payroll_read on public.payroll for select to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and exists (
    select 1 from public.employees e where e.employee_id=payroll.employee_id and e.branch_id=public.current_branch_id()
  ))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy payroll_insert on public.payroll for insert to authenticated with check (public.current_app_role()='admin');
create policy payroll_update on public.payroll for update to authenticated using (public.current_app_role()='admin') with check (public.current_app_role()='admin');
create policy payroll_delete on public.payroll for delete to authenticated using (public.current_app_role()='admin');

-- Employee requests
drop policy if exists employee_requests_admin_all on public.employee_requests;
drop policy if exists employee_requests_branch_insert on public.employee_requests;
drop policy if exists employee_requests_branch_read on public.employee_requests;
drop policy if exists employee_requests_read on public.employee_requests;
drop policy if exists employee_requests_insert on public.employee_requests;
drop policy if exists employee_requests_update on public.employee_requests;
drop policy if exists employee_requests_delete on public.employee_requests;
create policy employee_requests_read on public.employee_requests for select to authenticated using (
  public.current_app_role()='admin' or (public.current_app_role()='branch' and branch_id=public.current_branch_id())
);
create policy employee_requests_insert on public.employee_requests for insert to authenticated with check (
  public.current_app_role()='admin' or (public.current_app_role()='branch' and branch_id=public.current_branch_id())
);
create policy employee_requests_update on public.employee_requests for update to authenticated using (public.current_app_role()='admin') with check (public.current_app_role()='admin');
create policy employee_requests_delete on public.employee_requests for delete to authenticated using (public.current_app_role()='admin');

-- Employees
drop policy if exists employees_admin_all on public.employees;
drop policy if exists employees_branch_read on public.employees;
drop policy if exists employees_self_read on public.employees;
drop policy if exists employees_branch_update on public.employees;
drop policy if exists employees_read on public.employees;
drop policy if exists employees_insert on public.employees;
drop policy if exists employees_update on public.employees;
drop policy if exists employees_delete on public.employees;
create policy employees_read on public.employees for select to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and branch_id=public.current_branch_id() and (
    (public.current_is_frn() and coalesce(address,'') ilike '%FRN%')
    or ((not public.current_is_frn()) and coalesce(address,'') not ilike '%FRN%')
  ))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy employees_insert on public.employees for insert to authenticated with check (public.current_app_role()='admin');
create policy employees_update on public.employees for update to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and branch_id=public.current_branch_id() and (
    (public.current_is_frn() and coalesce(address,'') ilike '%FRN%')
    or ((not public.current_is_frn()) and coalesce(address,'') not ilike '%FRN%')
  ))
) with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and branch_id=public.current_branch_id() and (
    (public.current_is_frn() and coalesce(address,'') ilike '%FRN%')
    or ((not public.current_is_frn()) and coalesce(address,'') not ilike '%FRN%')
  ))
);
create policy employees_delete on public.employees for delete to authenticated using (public.current_app_role()='admin');

-- Leave requests
drop policy if exists leave_requests_admin_all on public.leave_requests;
drop policy if exists leave_requests_employee_insert on public.leave_requests;
drop policy if exists leave_request_admin_reviewer_read on public.leave_requests;
drop policy if exists leave_requests_branch_read on public.leave_requests;
drop policy if exists leave_requests_employee_read on public.leave_requests;
drop policy if exists leave_request_admin_reviewer_update on public.leave_requests;
drop policy if exists leave_requests_branch_update on public.leave_requests;
drop policy if exists leave_requests_insert on public.leave_requests;
drop policy if exists leave_requests_read on public.leave_requests;
drop policy if exists leave_requests_update on public.leave_requests;
drop policy if exists leave_requests_delete on public.leave_requests;
create policy leave_requests_insert on public.leave_requests for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id() and status='pending_branch'
      and branch_approved_at is null and admin_approved_at is null
      and exists (select 1 from public.employees e where e.employee_id=leave_requests.employee_id and lower(trim(e.branch_id))=lower(trim(leave_requests.branch_id))))
);
create policy leave_requests_read on public.leave_requests for select to authenticated using (
  public.current_app_role()='admin' or public.current_app_role()='request_admin'
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy leave_requests_update on public.leave_requests for update to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='request_admin' and status='pending_admin')
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())) and status='pending_branch')
) with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='request_admin' and status in ('approved','rejected'))
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id()))
      and status in ('pending_admin','rejected') and admin_approved_at is null and admin_approved_by is null)
);
create policy leave_requests_delete on public.leave_requests for delete to authenticated using (public.current_app_role()='admin');

-- Overtime requests
drop policy if exists overtime_requests_admin_all on public.overtime_requests;
drop policy if exists overtime_requests_employee_insert on public.overtime_requests;
drop policy if exists ot_request_admin_reviewer_read on public.overtime_requests;
drop policy if exists overtime_requests_branch_read on public.overtime_requests;
drop policy if exists overtime_requests_employee_read on public.overtime_requests;
drop policy if exists ot_request_admin_reviewer_update on public.overtime_requests;
drop policy if exists overtime_requests_branch_update on public.overtime_requests;
drop policy if exists overtime_requests_insert on public.overtime_requests;
drop policy if exists overtime_requests_read on public.overtime_requests;
drop policy if exists overtime_requests_update on public.overtime_requests;
drop policy if exists overtime_requests_delete on public.overtime_requests;
create policy overtime_requests_insert on public.overtime_requests for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id() and status='pending_branch'
      and approved_minutes is null and branch_approved_at is null and branch_approved_by is null
      and admin_approved_at is null and admin_approved_by is null and reviewed_at is null and reviewed_by is null
      and exists (select 1 from public.employees e where e.employee_id=overtime_requests.employee_id and e.branch_id=overtime_requests.branch_id))
);
create policy overtime_requests_read on public.overtime_requests for select to authenticated using (
  public.current_app_role()='admin' or public.current_app_role()='request_admin'
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);
create policy overtime_requests_update on public.overtime_requests for update to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='request_admin' and status='pending_admin')
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())) and status='pending_branch')
) with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='request_admin' and status in ('approved','rejected'))
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id()))
      and status in ('pending_admin','rejected') and approved_minutes is null and admin_approved_at is null and admin_approved_by is null)
);
create policy overtime_requests_delete on public.overtime_requests for delete to authenticated using (public.current_app_role()='admin');
