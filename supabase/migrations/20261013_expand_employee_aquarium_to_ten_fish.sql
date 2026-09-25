alter table public.employee_aquariums
  drop constraint if exists employee_aquariums_fish_count_check;

alter table public.employee_aquariums
  add constraint employee_aquariums_fish_count_check
  check (fish_count between 2 and 10);

create or replace function public.record_employee_aquarium_login()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id text;
  v_week_start timestamptz;
  v_weekly_logins integer;
  v_previous_weekly_logins integer;
  v_previous_fish_count integer;
  v_progress public.employee_aquariums;
begin
  if public.current_app_role() <> 'employee' then
    raise exception 'Employee access required';
  end if;

  v_employee_id := public.current_employee_id();
  if coalesce(trim(v_employee_id), '') = '' then
    raise exception 'Employee identity is missing';
  end if;

  v_week_start := date_trunc('week', now() at time zone 'Asia/Kuala_Lumpur')
    at time zone 'Asia/Kuala_Lumpur';

  select count(*)::integer into v_previous_weekly_logins
  from public.employee_aquarium_logins
  where employee_id = v_employee_id and logged_in_at >= v_week_start;

  select fish_count into v_previous_fish_count
  from public.employee_aquariums
  where employee_id = v_employee_id;

  insert into public.employee_aquarium_logins (employee_id)
  values (v_employee_id);
  v_weekly_logins := v_previous_weekly_logins + 1;

  insert into public.employee_aquariums
    (employee_id, total_feed, available_food, fish_count, updated_at)
  values
    (v_employee_id, 0, 1,
      2 + case when v_weekly_logins % 4 = 0 then 1 else 0 end, now())
  on conflict (employee_id) do update set
    available_food = employee_aquariums.available_food + 1,
    fish_count = least(10, employee_aquariums.fish_count
      + case when v_weekly_logins % 4 = 0 then 1 else 0 end),
    updated_at = now()
  returning * into v_progress;

  return jsonb_build_object(
    'employee_id', v_progress.employee_id,
    'total_feed', v_progress.total_feed,
    'available_food', v_progress.available_food,
    'fish_count', v_progress.fish_count,
    'weekly_logins', v_weekly_logins,
    'logins_until_next_fish', case
      when v_progress.fish_count >= 10 then 0
      when v_weekly_logins % 4 = 0 then 4
      else 4 - (v_weekly_logins % 4)
    end,
    'fish_awarded', v_weekly_logins % 4 = 0
      and coalesce(v_previous_fish_count, 2) < 10
  );
end;
$$;

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
  v_employee_id := public.current_employee_id();

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

create or replace function public.get_employee_aquarium()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id text;
  v_weekly_logins integer;
  v_progress public.employee_aquariums;
begin
  if public.current_app_role() <> 'employee' then
    raise exception 'Employee access required';
  end if;
  v_employee_id := public.current_employee_id();

  select * into v_progress from public.employee_aquariums
  where employee_id = v_employee_id;

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
    'fish_awarded', false
  );
end;
$$;

revoke all on function public.record_employee_aquarium_login() from public;
revoke all on function public.feed_employee_aquarium() from public;
revoke all on function public.get_employee_aquarium() from public;
grant execute on function public.record_employee_aquarium_login() to authenticated;
grant execute on function public.feed_employee_aquarium() to authenticated;
grant execute on function public.get_employee_aquarium() to authenticated;
