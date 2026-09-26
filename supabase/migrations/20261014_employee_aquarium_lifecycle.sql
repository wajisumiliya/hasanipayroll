alter table public.employee_aquariums
  add column if not exists dead_fish_count integer not null default 0
    check (dead_fish_count between 0 and 10),
  add column if not exists fish_birth_dates jsonb not null default '[]'::jsonb,
  add column if not exists last_login_at timestamptz,
  add column if not exists last_decay_at timestamptz,
  add column if not exists reward_login_days integer not null default 0,
  add column if not exists last_reward_login_date date;

alter table public.employee_aquariums
  drop constraint if exists employee_aquariums_fish_count_check;
alter table public.employee_aquariums
  add constraint employee_aquariums_fish_count_check
  check (fish_count between 0 and 10);

update public.employee_aquariums
set fish_count = greatest(fish_count, 5),
    fish_birth_dates = case
      when jsonb_array_length(fish_birth_dates) = 0 then jsonb_build_array(
        (current_date - 60)::text,
        (current_date - 48)::text,
        (current_date - 36)::text,
        (current_date - 15)::text,
        current_date::text
      )
      else fish_birth_dates
    end,
    last_login_at = coalesce(last_login_at, now()),
    last_decay_at = coalesce(last_decay_at, now());

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

revoke all on function public.apply_employee_aquarium_decay(text) from public;

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
  v_employee_id := public.current_employee_id();
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
  v_employee_id := public.current_employee_id();
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
  v_employee_id := public.current_employee_id();
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

revoke all on function public.record_employee_aquarium_login() from public;
revoke all on function public.get_employee_aquarium() from public;
revoke all on function public.clean_employee_aquarium() from public;
grant execute on function public.record_employee_aquarium_login() to authenticated;
grant execute on function public.get_employee_aquarium() to authenticated;
grant execute on function public.clean_employee_aquarium() to authenticated;
