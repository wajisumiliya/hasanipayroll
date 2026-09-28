-- Prevent branch sessions from changing administrator/system-owned employee fields.
-- Branch UI may continue editing its existing profile fields; RLS still scopes rows.
create or replace function public.guard_branch_employee_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if public.current_app_role() = 'branch' then
    if new.employee_id is distinct from old.employee_id
       or new.branch_id is distinct from old.branch_id
       or new.payroll_branch_id is distinct from old.payroll_branch_id
       or new.epf_no is distinct from old.epf_no
       or new.socso_no is distinct from old.socso_no
       or new.is_management_staff is distinct from old.is_management_staff
       or new.is_temp_staff is distinct from old.is_temp_staff
       or new.is_other_staff is distinct from old.is_other_staff
       or new.is_support_staff is distinct from old.is_support_staff
       or new.created_at is distinct from old.created_at then
      raise exception 'Branch users cannot modify administrator-controlled employee fields';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_branch_employee_columns on public.employees;
create trigger guard_branch_employee_columns
before update on public.employees
for each row
execute function public.guard_branch_employee_columns();
