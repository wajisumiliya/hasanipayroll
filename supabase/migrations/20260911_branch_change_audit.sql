-- Reliable database-level audit trail for every branch data change.
alter table public.branch_activity_logs enable row level security;
grant select, insert, update on table public.branch_activity_logs to authenticated;

drop policy if exists branch_logs_admin_read on public.branch_activity_logs;
create policy branch_logs_admin_read on public.branch_activity_logs
  for select to authenticated
  using (public.current_app_role() in ('admin', 'administrator'));

create or replace function public.audit_branch_data_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  old_row jsonb := case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end;
  new_row jsonb := case when tg_op = 'DELETE' then '{}'::jsonb else to_jsonb(new) end;
  source_row jsonb := case when tg_op = 'DELETE' then old_row else new_row end;
  changed_fields jsonb;
  audit_branch text;
  audit_employee_id text;
  audit_employee_name text;
begin
  if public.current_app_role() <> 'branch' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  audit_branch := coalesce(nullif(source_row ->> 'branch_id', ''), public.current_branch_id());
  audit_employee_id := nullif(source_row ->> 'employee_id', '');
  audit_employee_name := coalesce(
    nullif(source_row ->> 'employee_name', ''),
    nullif(source_row ->> 'name', '')
  );

  select coalesce(jsonb_agg(key order by key), '[]'::jsonb)
    into changed_fields
    from (
      select key from jsonb_object_keys(old_row || new_row) as keys(key)
      where old_row -> key is distinct from new_row -> key
        and key not in ('updated_at', 'created_at')
    ) changed;

  insert into public.branch_activity_logs (
    branch_id,
    action,
    employee_id,
    employee_name,
    opened_at,
    closed_at,
    details
  ) values (
    audit_branch,
    upper(tg_table_name || '_' || tg_op),
    audit_employee_id,
    audit_employee_name,
    now(),
    now(),
    jsonb_build_object(
      'table', tg_table_name,
      'operation', tg_op,
      'changed_fields', changed_fields,
      'attendance_date', source_row ->> 'attendance_date',
      'roster_year', source_row ->> 'roster_year',
      'roster_month', source_row ->> 'roster_month',
      'week_number', source_row ->> 'week_number',
      'overtime_date', source_row ->> 'overtime_date',
      'status', source_row ->> 'status'
    )
  );

  return case when tg_op = 'DELETE' then old else new end;
exception
  when others then
    raise warning 'Unable to write branch audit log for %.%: %', tg_table_name, tg_op, sqlerrm;
    return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function public.audit_branch_data_change() from public, anon, authenticated;

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'attendance',
    'monthly_rosters',
    'employees',
    'overtime_requests',
    'employee_requests'
  ] loop
    if to_regclass('public.' || target_table) is not null then
      execute format('drop trigger if exists branch_audit_change on public.%I', target_table);
      execute format(
        'create trigger branch_audit_change after insert or update or delete on public.%I for each row execute function public.audit_branch_data_change()',
        target_table
      );
    end if;
  end loop;
end;
$$;