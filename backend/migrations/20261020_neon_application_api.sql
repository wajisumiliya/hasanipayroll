-- Restore the application API over the imported Neon schema.
-- Apply with the backend database owner. No payroll rows are rewritten.
BEGIN;
DO $roles$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $roles$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER
 SET search_path=pg_catalog AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
CREATE OR REPLACE FUNCTION auth.user_id() RETURNS text LANGUAGE sql STABLE SECURITY INVOKER
 SET search_path=pg_catalog AS $$ SELECT nullif(auth.jwt()->>'sub','') $$;
REVOKE ALL ON SCHEMA auth FROM PUBLIC;
GRANT USAGE ON SCHEMA auth, public TO authenticated;
GRANT EXECUTE ON FUNCTION auth.jwt(), auth.user_id() TO authenticated;
-- The HTTP adapter supplies verified claims and SET LOCAL ROLE inside one
-- transaction. Clients cannot run SQL or set their own database claims.
DO $member$ BEGIN EXECUTE format('GRANT authenticated TO %I',current_user); END $member$;


-- Source: supabase/migrations/20260903_security_rls_lockdown.sql
create or replace function public.current_app_role()
returns text language sql stable as $$
  select lower(coalesce(
    auth.jwt() -> 'app_metadata' ->> 'app_role',
    auth.jwt() -> 'app_metadata' ->> 'role',
    ''
  ));
$$;

-- Source: supabase/migrations/20260903_security_rls_lockdown.sql
create or replace function public.current_branch_id()
returns text language sql stable as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'branch_id', '');
$$;

-- Source: supabase/migrations/20260903_security_rls_lockdown.sql
create or replace function public.current_employee_id()
returns text language sql stable as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'employee_id', '');
$$;

-- Source: supabase/migrations/20260903_security_rls_lockdown.sql
create or replace function public.current_is_frn()
returns boolean language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'is_frn')::boolean, false);
$$;

-- Source: supabase/migrations/20260910_normalize_branch_rls.sql
create or replace function public.normalized_branch_key(value text)
returns text
language sql
immutable
set search_path = public
as $$
  select case regexp_replace(lower(trim(coalesce(value, ''))), '[^a-z0-9]', '', 'g')
    when 'hbsp' then 'sungaipetani'
    when 'hpspfrn' then 'sungaipetani'
    when 'hbspfrn' then 'sungaipetani'
    when 'hbamj' then 'amanjaya'
    when 'hbamjfrn' then 'amanjaya'
    when 'hbas' then 'alorsetar'
    when 'hbasfrn' then 'alorsetar'
    when 'hbastana' then 'astana'
    when 'hbastanafrn' then 'astana'
    when 'hbgurun' then 'gurun'
    when 'hbgurunfrn' then 'gurun'
    when 'hbjitra' then 'jitra'
    when 'hbjitrafrn' then 'jitra'
    when 'hbperai' then 'prai'
    when 'hbperaifrn' then 'prai'
    when 'hbkulim' then 'kulim'
    when 'hbkulimfrn' then 'kulim'
    when 'hblkw' then 'langkawi'
    when 'hblkwfrn' then 'langkawi'
    else regexp_replace(lower(trim(coalesce(value, ''))), '[^a-z0-9]', '', 'g')
  end;
$$;

-- Source: supabase/migrations/20261023_harden_employee_rpc_identity.sql
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
  if auth.user_id() is null then
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

-- Source: supabase/migrations/20261014_employee_aquarium_lifecycle.sql
create or replace function public.apply_employee_aquarium_decay(p_employee_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_progress public.employee_aquariums;
  v_weeks integer;
  v_deaths integer;
begin
  if public.current_app_role() <> 'employee'
     or public.current_employee_id() <> p_employee_id then
    raise exception 'Employee access required';
  end if;

  select * into v_progress from public.employee_aquariums
  where employee_id = p_employee_id for update;
  if not found or v_progress.last_login_at is null then return; end if;

  v_weeks := floor(extract(epoch from
    (now() - greatest(v_progress.last_login_at,
      coalesce(v_progress.last_decay_at, v_progress.last_login_at))))
    / 604800)::integer;
  v_deaths := least(greatest(v_weeks, 0), v_progress.fish_count);
  if v_deaths > 0 then
    update public.employee_aquariums
    set fish_count = fish_count - v_deaths,
        dead_fish_count = least(10, dead_fish_count + v_deaths),
        fish_birth_dates = coalesce((
          select jsonb_agg(item.value order by item.ordinality)
          from jsonb_array_elements(employee_aquariums.fish_birth_dates)
            with ordinality as item(value, ordinality)
          where item.ordinality <=
            jsonb_array_length(employee_aquariums.fish_birth_dates) - v_deaths
        ), '[]'::jsonb),
        last_decay_at = coalesce(last_decay_at, last_login_at)
          + make_interval(weeks => v_deaths)
    where employee_id = p_employee_id;
  end if;
end;
$$;

-- Source: supabase/migrations/20261014_employee_aquarium_lifecycle.sql
create or replace function public.record_employee_aquarium_login()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id text;
  v_progress public.employee_aquariums;
  v_today date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
  v_new_day boolean := false;
  v_awarded boolean := false;
begin
  if public.current_app_role() <> 'employee' then raise exception 'Employee access required'; end if;
  v_employee_id := public.require_employee_identity();
  if coalesce(trim(v_employee_id), '') = '' then raise exception 'Employee identity is missing'; end if;

  insert into public.employee_aquariums
    (employee_id, fish_count, fish_birth_dates, last_login_at, last_decay_at)
  values (v_employee_id, 5, jsonb_build_array(
    (v_today - 60)::text, (v_today - 48)::text, (v_today - 36)::text,
    (v_today - 15)::text, v_today::text), now(), now())
  on conflict (employee_id) do nothing;

  perform public.apply_employee_aquarium_decay(v_employee_id);
  select * into v_progress from public.employee_aquariums
  where employee_id = v_employee_id for update;
  v_new_day := v_progress.last_reward_login_date is distinct from v_today;

  if v_new_day then
    insert into public.employee_aquarium_logins (employee_id) values (v_employee_id);
    update public.employee_aquariums
    set available_food = available_food + 1,
        reward_login_days = reward_login_days + 1,
        last_reward_login_date = v_today,
        last_login_at = now(),
        last_decay_at = now(),
        updated_at = now()
    where employee_id = v_employee_id returning * into v_progress;

    if v_progress.reward_login_days % 4 = 0 and v_progress.fish_count < 10 then
      update public.employee_aquariums
      set fish_count = fish_count + 1,
          fish_birth_dates = fish_birth_dates || jsonb_build_array(v_today::text)
      where employee_id = v_employee_id returning * into v_progress;
      v_awarded := true;
    end if;
  else
    update public.employee_aquariums set last_login_at = now(), updated_at = now()
    where employee_id = v_employee_id returning * into v_progress;
  end if;

  return jsonb_build_object(
    'employee_id', v_employee_id, 'total_feed', v_progress.total_feed,
    'available_food', v_progress.available_food, 'fish_count', v_progress.fish_count,
    'weekly_logins', v_progress.reward_login_days,
    'logins_until_next_fish', case when v_progress.fish_count >= 10 then 0
      else 4 - (v_progress.reward_login_days % 4) end,
    'fish_awarded', v_awarded, 'dead_fish_count', v_progress.dead_fish_count,
    'fish_birth_dates', v_progress.fish_birth_dates
  );
end;
$$;

-- Source: supabase/migrations/20261013_expand_employee_aquarium_to_ten_fish.sql
create or replace function public.feed_employee_aquarium()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id text;
  v_progress public.employee_aquariums;
  v_weekly_logins integer;
  v_fed boolean := false;
begin
  if public.current_app_role() <> 'employee' then
    raise exception 'Employee access required';
  end if;
  v_employee_id := public.require_employee_identity();

  update public.employee_aquariums
  set available_food = available_food - 1,
      total_feed = total_feed + 1,
      updated_at = now()
  where employee_id = v_employee_id and available_food > 0
  returning * into v_progress;

  if found then
    v_fed := true;
  else
    select * into v_progress from public.employee_aquariums
    where employee_id = v_employee_id;
  end if;

  select count(*)::integer into v_weekly_logins
  from public.employee_aquarium_logins
  where employee_id = v_employee_id
    and logged_in_at >= (date_trunc('week', now() at time zone 'Asia/Kuala_Lumpur')
      at time zone 'Asia/Kuala_Lumpur');

  return jsonb_build_object(
    'employee_id', v_employee_id,
    'total_feed', coalesce(v_progress.total_feed, 0),
    'available_food', coalesce(v_progress.available_food, 0),
    'fish_count', coalesce(v_progress.fish_count, 2),
    'weekly_logins', v_weekly_logins,
    'logins_until_next_fish', case
      when coalesce(v_progress.fish_count, 2) >= 10 then 0
      when v_weekly_logins % 4 = 0 and v_weekly_logins > 0 then 4
      else 4 - (v_weekly_logins % 4)
    end,
    'fish_awarded', false,
    'fed', v_fed
  );
end;
$$;

-- Source: supabase/migrations/20261014_employee_aquarium_lifecycle.sql
create or replace function public.get_employee_aquarium()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id text;
  v_progress public.employee_aquariums;
  v_today date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
begin
  if public.current_app_role() <> 'employee' then raise exception 'Employee access required'; end if;
  v_employee_id := public.require_employee_identity();
  insert into public.employee_aquariums
    (employee_id, fish_count, fish_birth_dates, last_login_at, last_decay_at)
  values (v_employee_id, 5, jsonb_build_array(
    (v_today - 60)::text, (v_today - 48)::text, (v_today - 36)::text,
    (v_today - 15)::text, v_today::text), now(), now())
  on conflict (employee_id) do nothing;
  perform public.apply_employee_aquarium_decay(v_employee_id);
  select * into v_progress from public.employee_aquariums where employee_id = v_employee_id;
  return jsonb_build_object(
    'employee_id', v_employee_id, 'total_feed', v_progress.total_feed,
    'available_food', v_progress.available_food, 'fish_count', v_progress.fish_count,
    'weekly_logins', v_progress.reward_login_days,
    'logins_until_next_fish', case when v_progress.fish_count >= 10 then 0
      else 4 - (v_progress.reward_login_days % 4) end,
    'fish_awarded', false, 'dead_fish_count', v_progress.dead_fish_count,
    'fish_birth_dates', v_progress.fish_birth_dates
  );
end;
$$;

-- Source: supabase/migrations/20261014_employee_aquarium_lifecycle.sql
create or replace function public.clean_employee_aquarium()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id text;
  v_progress public.employee_aquariums;
begin
  if public.current_app_role() <> 'employee' then raise exception 'Employee access required'; end if;
  v_employee_id := public.require_employee_identity();
  update public.employee_aquariums set dead_fish_count = 0, updated_at = now()
  where employee_id = v_employee_id returning * into v_progress;
  return jsonb_build_object(
    'employee_id', v_employee_id, 'total_feed', coalesce(v_progress.total_feed, 0),
    'available_food', coalesce(v_progress.available_food, 0),
    'fish_count', coalesce(v_progress.fish_count, 0),
    'weekly_logins', coalesce(v_progress.reward_login_days, 0),
    'logins_until_next_fish', case when coalesce(v_progress.fish_count, 0) >= 10 then 0
      else 4 - (coalesce(v_progress.reward_login_days, 0) % 4) end,
    'fish_awarded', false, 'dead_fish_count', 0,
    'fish_birth_dates', coalesce(v_progress.fish_birth_dates, '[]'::jsonb)
  );
end;
$$;

-- Source: supabase/migrations/20261015090000_employee_garden_courtyard.sql
create or replace function public.get_employee_garden()
returns jsonb
language sql
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'employee_id', data->>'employee_id',
    'total_care', coalesce((data->>'total_feed')::integer, 0),
    'available_care', coalesce((data->>'available_food')::integer, 0),
    'garden_level', coalesce((data->>'fish_count')::integer, 1),
    'weekly_visits', coalesce((data->>'weekly_logins')::integer, 0),
    'visits_until_next_unlock', coalesce((data->>'logins_until_next_fish')::integer, 4),
    'feature_awarded', coalesce((data->>'fish_awarded')::boolean, false),
    'neglected_count', coalesce((data->>'dead_fish_count')::integer, 0),
    'plant_dates', coalesce(data->'fish_birth_dates', '[]'::jsonb)
  )
  from (select public.get_employee_aquarium() as data) source;
$$;

-- Source: supabase/migrations/20261015090000_employee_garden_courtyard.sql
create or replace function public.record_employee_garden_visit()
returns jsonb
language sql
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'employee_id', data->>'employee_id',
    'total_care', coalesce((data->>'total_feed')::integer, 0),
    'available_care', coalesce((data->>'available_food')::integer, 0),
    'garden_level', coalesce((data->>'fish_count')::integer, 1),
    'weekly_visits', coalesce((data->>'weekly_logins')::integer, 0),
    'visits_until_next_unlock', coalesce((data->>'logins_until_next_fish')::integer, 4),
    'feature_awarded', coalesce((data->>'fish_awarded')::boolean, false),
    'neglected_count', coalesce((data->>'dead_fish_count')::integer, 0),
    'plant_dates', coalesce(data->'fish_birth_dates', '[]'::jsonb)
  )
  from (select public.record_employee_aquarium_login() as data) source;
$$;

-- Source: supabase/migrations/20261015090000_employee_garden_courtyard.sql
create or replace function public.tend_employee_garden()
returns jsonb
language sql
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'employee_id', data->>'employee_id',
    'total_care', coalesce((data->>'total_feed')::integer, 0),
    'available_care', coalesce((data->>'available_food')::integer, 0),
    'garden_level', coalesce((data->>'fish_count')::integer, 1),
    'weekly_visits', coalesce((data->>'weekly_logins')::integer, 0),
    'visits_until_next_unlock', coalesce((data->>'logins_until_next_fish')::integer, 4),
    'feature_awarded', coalesce((data->>'fish_awarded')::boolean, false),
    'neglected_count', coalesce((data->>'dead_fish_count')::integer, 0),
    'plant_dates', coalesce(data->'fish_birth_dates', '[]'::jsonb),
    'tended', coalesce((data->>'fed')::boolean, false)
  )
  from (select public.feed_employee_aquarium() as data) source;
$$;

-- Source: supabase/migrations/20260912_branch_logs_rpc.sql
create or replace function public.admin_branch_activity_logs(
  p_branch_id text default null,
  p_start timestamptz default null,
  p_end timestamptz default null,
  p_limit integer default 500
)
returns setof public.branch_activity_logs
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.current_app_role() not in ('admin', 'administrator') then
    raise exception 'Administrator access required';
  end if;

  return query
  select logs.*
  from public.branch_activity_logs logs
  where (nullif(trim(p_branch_id), '') is null
      or public.normalized_branch_key(logs.branch_id) = public.normalized_branch_key(p_branch_id))
    and (p_start is null or logs.opened_at >= p_start)
    and (p_end is null or logs.opened_at < p_end)
  order by logs.opened_at desc
  limit greatest(1, least(coalesce(p_limit, 500), 2000));
end;
$$;

-- Source: supabase/migrations/20260920_fix_employee_active_status_columns.sql
create or replace function public.set_employee_active_status(
  p_employee_id text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  wanted_employee_id text := trim(coalesce(p_employee_id, ''));
  account_employee_column text;
  account_active_column text;
  account_updated_column text;
  updated_assignment text := '';
begin
  if public.current_app_role() not in ('admin', 'administrator') then
    raise exception 'Administrator access required';
  end if;

  if wanted_employee_id = '' or p_is_active is null then
    raise exception 'Employee ID and active status are required';
  end if;

  update public.employees
     set is_active = p_is_active
   where upper(trim(employee_id)) = upper(wanted_employee_id);

  if not found then
    raise exception 'Employee % was not found', wanted_employee_id;
  end if;

  select case
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'employee_id'
           ) then 'employee_id'
           else 'employeeId'
         end,
         case
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'is_active'
           ) then 'is_active'
           else 'isActive'
         end,
         case
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'updated_at'
           ) then 'updated_at'
           when exists (
             select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'app_user'
                and column_name = 'updatedAt'
           ) then 'updatedAt'
           else null
         end
    into account_employee_column, account_active_column, account_updated_column;

  if account_updated_column is not null then
    updated_assignment := format(', %I = now()', account_updated_column);
  end if;

  execute format(
    'update public.app_user set %I = $1%s '
    'where upper(trim(coalesce(%I::text, ''''))) = upper($2)',
    account_active_column,
    updated_assignment,
    account_employee_column
  ) using p_is_active, wanted_employee_id;
end;
$$;

-- Source: supabase/migrations/20260914_staff_transfer_history.sql
create or replace function public.transfer_staff(p_employee_id text, p_to_branch_id text, p_effective_date date default current_date, p_reason text default null)
returns public.staff_transfer_history language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.employees; h public.staff_transfer_history; eid text:=trim(coalesce(p_employee_id,'')); destination text:=trim(coalesce(p_to_branch_id,''));
begin
 if public.current_app_role() not in ('admin','administrator') then raise exception 'Administrator access required'; end if;
 if eid='' or destination='' then raise exception 'Employee and destination branch are required'; end if;
 select * into e from public.employees where employee_id=eid for update;
 if not found then raise exception 'Employee % was not found',eid; end if;
 if public.normalized_branch_key(e.branch_id)=public.normalized_branch_key(destination) then raise exception 'Employee already belongs to this branch'; end if;
 update public.employees set branch_id=destination where employee_id=eid;
 insert into public.staff_transfer_history(employee_id,employee_name,from_branch_id,to_branch_id,effective_date,reason,transferred_by)
 values(eid,e.name,e.branch_id,destination,coalesce(p_effective_date,current_date),nullif(trim(p_reason),''),coalesce(auth.jwt()->>'sub','admin')) returning * into h;
 return h;
end; $$;

-- Source: supabase/migrations/20260903_security_rls_lockdown.sql
create or replace function public.approve_employee_request(request_id uuid, new_employee_id text)
returns public.employees
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() <> 'admin' then
    raise exception 'Administrator access required.';
  end if;
  return public.approve_employee_request_internal(request_id, new_employee_id);
end;
$$;

-- Source: supabase/migrations/20261017_harden_daily_report_pin_attempts.sql
create or replace function public.verify_daily_report_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  stored_hash text;
  branch_key text := trim(public.current_branch_id());
  attempt public.daily_report_pin_attempts;
  is_valid boolean := false;
  now_at timestamptz := now();
begin
  if public.current_app_role() <> 'branch' or branch_key = '' then
    raise exception 'Branch access required';
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    raise exception 'A four-digit PIN is required';
  end if;

  select * into attempt
  from public.daily_report_pin_attempts
  where lower(trim(branch_id)) = lower(branch_key)
  for update;

  if found and attempt.locked_until is not null and attempt.locked_until > now_at then
    raise exception 'Too many incorrect attempts. Try again later.';
  end if;

  select pin_hash into stored_hash
  from public.daily_report_branch_pins
  where lower(trim(branch_id)) = lower(branch_key);

  if stored_hash is null then
    is_valid := p_pin = '2026';
  else
    is_valid := crypt(p_pin, stored_hash) = stored_hash;
  end if;

  if is_valid then
    delete from public.daily_report_pin_attempts
    where lower(trim(branch_id)) = lower(branch_key);
    return jsonb_build_object(
      'valid', true,
      'must_change', stored_hash is null
    );
  end if;

  insert into public.daily_report_pin_attempts (
    branch_id, failed_attempts, window_started_at, locked_until, updated_at
  ) values (
    branch_key, 1, now_at, null, now_at
  )
  on conflict (branch_id) do update set
    failed_attempts = case
      when daily_report_pin_attempts.window_started_at < now_at - interval '15 minutes'
        then 1
      else daily_report_pin_attempts.failed_attempts + 1
    end,
    window_started_at = case
      when daily_report_pin_attempts.window_started_at < now_at - interval '15 minutes'
        then now_at
      else daily_report_pin_attempts.window_started_at
    end,
    locked_until = case
      when (
        case
          when daily_report_pin_attempts.window_started_at < now_at - interval '15 minutes'
            then 1
          else daily_report_pin_attempts.failed_attempts + 1
        end
      ) >= 5 then now_at + interval '15 minutes'
      else null
    end,
    updated_at = now_at;

  return jsonb_build_object('valid', false, 'must_change', false);
end;
$$;

-- Source: supabase/migrations/20261017_harden_daily_report_pin_attempts.sql
create or replace function public.change_daily_report_pin(
  p_current_pin text,
  p_new_pin text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  stored_hash text;
  branch_key text := trim(public.current_branch_id());
begin
  if public.current_app_role() <> 'branch' or branch_key = '' then
    raise exception 'Branch access required';
  end if;
  if p_new_pin !~ '^[0-9]{4}$' or p_new_pin = '2026' then
    raise exception 'Choose a new four-digit PIN';
  end if;

  select pin_hash into stored_hash
  from public.daily_report_branch_pins
  where lower(trim(branch_id)) = lower(branch_key)
  for update;

  if (stored_hash is null and p_current_pin <> '2026') or
      (stored_hash is not null and crypt(p_current_pin, stored_hash) <> stored_hash) then
    raise exception 'Incorrect current PIN';
  end if;

  insert into public.daily_report_branch_pins(branch_id, pin_hash)
  values (branch_key, crypt(p_new_pin, gen_salt('bf')))
  on conflict (branch_id) do update
    set pin_hash = excluded.pin_hash, changed_at = now();

  delete from public.daily_report_pin_attempts
  where lower(trim(branch_id)) = lower(branch_key);
end;
$$;

-- Source: supabase/migrations/20261015_harden_notification_device_registration.sql
create or replace function public.register_notification_device(
  p_token text,
  p_employee_id text default null,
  p_branch_id text default null,
  p_platform text default 'unknown'
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := public.current_app_role();
  v_employee_id text := null;
  v_branch_id text := null;
  v_token text := trim(coalesce(p_token, ''));
  v_platform text := left(trim(coalesce(p_platform, 'unknown')), 32);
begin
  if auth.user_id() is null then
    raise exception 'Authentication required.';
  end if;

  if length(v_token) < 20 or length(v_token) > 4096 then
    raise exception 'Invalid notification token.';
  end if;

  if v_role = 'employee' then
    v_employee_id := nullif(public.current_employee_id(), '');
    v_branch_id := nullif(public.current_branch_id(), '');
    if v_employee_id is null then
      raise exception 'Employee identity is missing.';
    end if;
  elsif v_role = 'branch' then
    v_branch_id := nullif(public.current_branch_id(), '');
    if v_branch_id is null then
      raise exception 'Branch identity is missing.';
    end if;
  elsif v_role = 'admin' then
    v_employee_id := null;
    v_branch_id := null;
  else
    raise exception 'Authorized application role required.';
  end if;

  insert into public.notification_devices (
    token, employee_id, branch_id, platform, updated_at
  ) values (
    v_token, v_employee_id, v_branch_id, v_platform, now()
  )
  on conflict (token) do update set
    employee_id = excluded.employee_id,
    branch_id = excluded.branch_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;

-- Source: supabase/migrations/20261025150000_schedule_payslip_publication_with_increment_notifications.sql
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

-- Source: supabase/migrations/20261025150000_schedule_payslip_publication_with_increment_notifications.sql
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
    auth.user_id()::text,
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

DO $lockdown$ DECLARE t text; p record; BEGIN
 FOREACH t IN ARRAY ARRAY['employees','payroll','attendance','employee_requests','branch_activity_logs','employee_salary_defaults','monthly_rosters','daily_rosters','overtime_requests','leave_requests','employee_ea_forms','app_notifications','notification_reads','daily_reports','staff_transfer_history','branches'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated',t);
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
   EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,t);
  END LOOP;
  EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON public.%I TO authenticated',t);
 END LOOP;
END $lockdown$;

-- Source: supabase/migrations/20261002_employee_notification_inbox.sql
create policy app_notifications_employee_read on public.app_notifications
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and audience = 'employee'
    and employee_id = public.current_employee_id()
  );

-- Source: supabase/migrations/20260903_security_rls_lockdown.sql
create policy attendance_admin_all on public.attendance
  for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');

-- Source: supabase/migrations/20261021_consolidate_attendance_branch_rls.sql
create policy attendance_delete on public.attendance
  for delete to authenticated
  using (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  );

-- Source: supabase/migrations/20261021_consolidate_attendance_branch_rls.sql
create policy attendance_insert on public.attendance
  for insert to authenticated
  with check (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  );

-- Source: supabase/migrations/20260903_security_rls_lockdown.sql
create policy attendance_self_read on public.attendance
  for select to authenticated
  using (public.current_app_role() = 'employee' and employee_id = public.current_employee_id());

-- Source: supabase/migrations/20261021_consolidate_attendance_branch_rls.sql
create policy attendance_update on public.attendance
  for update to authenticated
  using (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  )
  with check (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'branch'
      and branch_id = public.current_branch_id()
      and exists (
        select 1 from public.employees e
        where e.employee_id = attendance.employee_id
          and e.branch_id = public.current_branch_id()
      )
    )
  );

-- Source: supabase/migrations/20260911_branch_change_audit.sql
create policy branch_logs_admin_read on public.branch_activity_logs
  for select to authenticated
  using (public.current_app_role() in ('admin', 'administrator'));

-- Source: supabase/migrations/20260910_normalize_branch_rls.sql
create policy branch_logs_branch_insert on public.branch_activity_logs
  for insert to authenticated
  with check (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  );

-- Source: supabase/migrations/20260910_normalize_branch_rls.sql
create policy branch_logs_branch_update on public.branch_activity_logs
  for update to authenticated
  using (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  )
  with check (
    public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  );

-- Source: supabase/migrations/20261004_daily_reports_request_admin.sql
create policy daily_reports_admin_update on public.daily_reports for update to authenticated
using (public.current_app_role() in ('admin', 'request_admin'))
with check (public.current_app_role() in ('admin', 'request_admin'));

-- Source: supabase/migrations/20261004_daily_reports_request_admin.sql
create policy daily_reports_branch_insert on public.daily_reports for insert to authenticated
with check (public.current_app_role() = 'branch' and lower(trim(branch_id)) = lower(trim(public.current_branch_id())) and reviewed_at is null);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy daily_reports_read on public.daily_reports for select to authenticated using (
  public.current_app_role() in ('admin','request_admin')
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy daily_rosters_delete on public.daily_rosters for delete to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy daily_rosters_insert on public.daily_rosters for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy daily_rosters_read on public.daily_rosters for select to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy daily_rosters_update on public.daily_rosters for update to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
) with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_ea_forms_delete on public.employee_ea_forms for delete to authenticated using (public.current_app_role() in ('admin','foreign_admin'));

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_ea_forms_insert on public.employee_ea_forms for insert to authenticated with check (public.current_app_role() in ('admin','foreign_admin'));

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_ea_forms_read on public.employee_ea_forms for select to authenticated using (
  public.current_app_role() in ('admin','foreign_admin')
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_ea_forms_update on public.employee_ea_forms for update to authenticated using (public.current_app_role() in ('admin','foreign_admin')) with check (public.current_app_role() in ('admin','foreign_admin'));

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_requests_delete on public.employee_requests for delete to authenticated using (public.current_app_role()='admin');

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_requests_insert on public.employee_requests for insert to authenticated with check (
  public.current_app_role()='admin' or (public.current_app_role()='branch' and branch_id=public.current_branch_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_requests_read on public.employee_requests for select to authenticated using (
  public.current_app_role()='admin' or (public.current_app_role()='branch' and branch_id=public.current_branch_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_requests_update on public.employee_requests for update to authenticated using (public.current_app_role()='admin') with check (public.current_app_role()='admin');

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_salary_defaults_delete on public.employee_salary_defaults for delete to authenticated using (public.current_app_role() in ('admin','administrator'));

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_salary_defaults_insert on public.employee_salary_defaults for insert to authenticated with check (public.current_app_role() in ('admin','administrator'));

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_salary_defaults_read on public.employee_salary_defaults for select to authenticated using (
  public.current_app_role() in ('admin','administrator')
  or (public.current_app_role()='branch' and exists (
    select 1 from public.employees e
    where e.employee_id=employee_salary_defaults.employee_id
      and public.normalized_branch_key(e.branch_id)=public.normalized_branch_key(public.current_branch_id())
  ))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employee_salary_defaults_update on public.employee_salary_defaults for update to authenticated using (public.current_app_role() in ('admin','administrator')) with check (public.current_app_role() in ('admin','administrator'));

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employees_delete on public.employees for delete to authenticated using (public.current_app_role()='admin');

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employees_insert on public.employees for insert to authenticated with check (public.current_app_role()='admin');

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy employees_read on public.employees for select to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and branch_id=public.current_branch_id() and (
    (public.current_is_frn() and coalesce(address,'') ilike '%FRN%')
    or ((not public.current_is_frn()) and coalesce(address,'') not ilike '%FRN%')
  ))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
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

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy leave_requests_delete on public.leave_requests for delete to authenticated using (public.current_app_role()='admin');

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy leave_requests_insert on public.leave_requests for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id() and status='pending_branch'
      and branch_approved_at is null and admin_approved_at is null
      and exists (select 1 from public.employees e where e.employee_id=leave_requests.employee_id and lower(trim(e.branch_id))=lower(trim(leave_requests.branch_id))))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy leave_requests_read on public.leave_requests for select to authenticated using (
  public.current_app_role()='admin' or public.current_app_role()='request_admin'
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
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

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy monthly_rosters_delete on public.monthly_rosters for delete to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy monthly_rosters_insert on public.monthly_rosters for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy monthly_rosters_read on public.monthly_rosters for select to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy monthly_rosters_update on public.monthly_rosters for update to authenticated using (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
) with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='branch' and public.normalized_branch_key(branch_id)=public.normalized_branch_key(public.current_branch_id()))
);

-- Source: supabase/migrations/20261002_employee_notification_inbox.sql
create policy notification_reads_employee_insert on public.notification_reads
  for insert to authenticated
  with check (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
    and exists (
      select 1 from public.app_notifications n
      where n.id = notification_reads.notification_id
        and n.audience = 'employee'
        and n.employee_id = notification_reads.employee_id
    )
  );

-- Source: supabase/migrations/20261002_employee_notification_inbox.sql
create policy notification_reads_employee_read on public.notification_reads
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );

-- Source: supabase/migrations/20261002_employee_notification_inbox.sql
create policy notification_reads_employee_update on public.notification_reads
  for update to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  )
  with check (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy overtime_requests_delete on public.overtime_requests for delete to authenticated using (public.current_app_role()='admin');

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy overtime_requests_insert on public.overtime_requests for insert to authenticated with check (
  public.current_app_role()='admin'
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id() and status='pending_branch'
      and approved_minutes is null and branch_approved_at is null and branch_approved_by is null
      and admin_approved_at is null and admin_approved_by is null and reviewed_at is null and reviewed_by is null
      and exists (select 1 from public.employees e where e.employee_id=overtime_requests.employee_id and e.branch_id=overtime_requests.branch_id))
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy overtime_requests_read on public.overtime_requests for select to authenticated using (
  public.current_app_role()='admin' or public.current_app_role()='request_admin'
  or (public.current_app_role()='branch' and lower(trim(branch_id))=lower(trim(public.current_branch_id())))
  or (public.current_app_role()='employee' and employee_id=public.current_employee_id())
);

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
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

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy payroll_delete on public.payroll for delete to authenticated using (public.current_app_role()='admin');

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy payroll_insert on public.payroll for insert to authenticated with check (public.current_app_role()='admin');

-- Source: supabase/migrations/20261025150000_schedule_payslip_publication_with_increment_notifications.sql
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

-- Source: supabase/migrations/20261022_consolidate_permissive_rls.sql
create policy payroll_update on public.payroll for update to authenticated using (public.current_app_role()='admin') with check (public.current_app_role()='admin');

-- Source: supabase/migrations/20260914_staff_transfer_history.sql
create policy staff_transfer_history_admin_read on public.staff_transfer_history for select to authenticated using (public.current_app_role() in ('admin','administrator'));

CREATE POLICY branches_read ON public.branches FOR SELECT TO authenticated
 USING (public.current_app_role() IN ('admin','administrator','request_admin')
 OR public.normalized_branch_key(id)=public.normalized_branch_key(public.current_branch_id())
 OR EXISTS(SELECT 1 FROM public.employees e WHERE e.employee_id=public.current_employee_id() AND e.branch_id=branches.id));
CREATE POLICY branches_admin_insert ON public.branches FOR INSERT TO authenticated WITH CHECK(public.current_app_role()='admin');
CREATE POLICY branches_admin_update ON public.branches FOR UPDATE TO authenticated USING(public.current_app_role()='admin') WITH CHECK(public.current_app_role()='admin');
CREATE POLICY branches_admin_delete ON public.branches FOR DELETE TO authenticated USING(public.current_app_role()='admin');
-- Accounts, secrets, internal activity, and device tokens are never exposed by
-- the generic HTTP table interface. Only checked RPCs may touch them.
REVOKE ALL ON public.app_user, public.daily_report_branch_pins, public.daily_report_pin_attempts,
 public.notification_devices, public.employee_aquariums, public.employee_aquarium_logins,
 public.company_tree_daily_logins, public.payslip_release_schedules FROM PUBLIC,anon,authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;


DO $functions$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' LOOP
  EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',f.signature);
 END LOOP;
END $functions$;

DO $grants$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname=ANY(ARRAY['current_app_role','current_branch_id','current_employee_id','current_is_frn','normalized_branch_key','require_employee_identity','record_employee_aquarium_login','feed_employee_aquarium','get_employee_aquarium','clean_employee_aquarium','get_employee_garden','record_employee_garden_visit','tend_employee_garden','admin_branch_activity_logs','set_employee_active_status','transfer_staff','approve_employee_request','verify_daily_report_pin','change_daily_report_pin','register_notification_device','schedule_monthly_payslip_release']) LOOP
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.signature);
 END LOOP;
END $grants$;
COMMIT;
