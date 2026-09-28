-- Defense-in-depth for employee-facing SECURITY DEFINER RPCs.
-- Require a real authenticated user plus the existing trusted employee claims.
-- Business behavior is unchanged.

create or replace function public.require_employee_identity()
returns text
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  employee_key text;
begin
  if auth.uid() is null or public.current_app_role() <> 'employee' then
    raise exception 'Employee access required';
  end if;

  employee_key := trim(public.current_employee_id());
  if employee_key = '' then
    raise exception 'Employee identity is missing';
  end if;

  return employee_key;
end;
$$;

revoke all on function public.require_employee_identity() from public, anon;
grant execute on function public.require_employee_identity() to authenticated, service_role;

-- Inject the common identity guard into the existing RPCs without changing
-- their aquarium/company-tree calculations.
do $$
declare
  fn_name text;
  fn_oid oid;
  fn_def text;
  guarded_def text;
begin
  foreach fn_name in array array[
    'clean_employee_aquarium',
    'feed_employee_aquarium',
    'get_employee_aquarium',
    'record_employee_aquarium_login',
    'record_company_tree_login'
  ]
  loop
    select p.oid
      into fn_oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = fn_name
       and pg_get_function_identity_arguments(p.oid) = '';

    if fn_oid is null then
      raise exception 'Expected RPC public.%() was not found', fn_name;
    end if;

    fn_def := pg_get_functiondef(fn_oid);

    -- Existing functions all declare an employee identity variable. Replace
    -- assignment from current_employee_id() with the stricter common guard.
    guarded_def := replace(
      fn_def,
      'public.current_employee_id()',
      'public.require_employee_identity()'
    );

    if guarded_def = fn_def then
      raise exception 'RPC public.%() did not contain the expected identity lookup', fn_name;
    end if;

    execute guarded_def;

    execute format('revoke all on function public.%I() from public, anon', fn_name);
    execute format('grant execute on function public.%I() to authenticated, service_role', fn_name);
  end loop;
end
$$;
