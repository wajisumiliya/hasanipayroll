-- Harden employee-facing SECURITY DEFINER RPC identity checks.
-- Keeps the existing RPC business logic intact while centralizing authentication,
-- employee-role and non-empty employee identity validation.

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
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if public.current_app_role() <> 'employee' then
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

do $$
declare
  function_name text;
  function_oid regprocedure;
  original_definition text;
  hardened_definition text;
begin
  foreach function_name in array array[
    'clean_employee_aquarium',
    'feed_employee_aquarium',
    'get_employee_aquarium',
    'record_employee_aquarium_login',
    'record_company_tree_login'
  ]
  loop
    function_oid := to_regprocedure(format('public.%I()', function_name));

    if function_oid is null then
      raise exception 'Expected function public.%() was not found', function_name;
    end if;

    original_definition := pg_get_functiondef(function_oid);
    hardened_definition := replace(
      original_definition,
      'public.current_employee_id()',
      'public.require_employee_identity()'
    );

    if hardened_definition = original_definition then
      raise exception 'Identity lookup was not found in public.%()', function_name;
    end if;

    execute hardened_definition;

    execute format(
      'revoke all on function public.%I() from public, anon',
      function_name
    );
    execute format(
      'grant execute on function public.%I() to authenticated, service_role',
      function_name
    );
  end loop;
end;
$$;
