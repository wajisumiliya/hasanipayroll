create table if not exists public.employee_aquariums (
  employee_id text primary key,
  total_feed integer not null default 0 check (total_feed >= 0),
  fish_count integer not null default 1 check (fish_count >= 1),
  updated_at timestamptz not null default now()
);

create table if not exists public.employee_aquarium_logins (
  id bigint generated always as identity primary key,
  employee_id text not null,
  logged_in_at timestamptz not null default now()
);

create index if not exists employee_aquarium_logins_employee_time_idx
  on public.employee_aquarium_logins (employee_id, logged_in_at desc);

alter table public.employee_aquariums enable row level security;
alter table public.employee_aquarium_logins enable row level security;

drop policy if exists employee_aquariums_own_read on public.employee_aquariums;
create policy employee_aquariums_own_read on public.employee_aquariums
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );

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
  v_progress public.employee_aquariums;
begin
  if public.current_app_role() <> 'employee' then
    raise exception 'Employee access required';
  end if;

  v_employee_id := public.current_employee_id();
  if coalesce(trim(v_employee_id), '') = '' then
    raise exception 'Employee identity is missing';
  end if;

  v_week_start := date_trunc(
    'week',
    now() at time zone 'Asia/Kuala_Lumpur'
  ) at time zone 'Asia/Kuala_Lumpur';
  select count(*)::integer into v_previous_weekly_logins
  from public.employee_aquarium_logins
  where employee_id = v_employee_id
    and logged_in_at >= v_week_start;

  insert into public.employee_aquarium_logins (employee_id)
  values (v_employee_id);

  v_weekly_logins := v_previous_weekly_logins + 1;

  insert into public.employee_aquariums (
    employee_id,
    total_feed,
    fish_count,
    updated_at
  ) values (
    v_employee_id,
    1,
    1 + case when v_weekly_logins % 5 = 0 then 1 else 0 end,
    now()
  )
  on conflict (employee_id) do update set
    total_feed = employee_aquariums.total_feed + 1,
    fish_count = employee_aquariums.fish_count
      + case when v_weekly_logins % 5 = 0 then 1 else 0 end,
    updated_at = now()
  returning * into v_progress;

  return jsonb_build_object(
    'employee_id', v_progress.employee_id,
    'total_feed', v_progress.total_feed,
    'fish_count', v_progress.fish_count,
    'weekly_logins', v_weekly_logins,
    'logins_until_next_fish', case
      when v_weekly_logins % 5 = 0 then 5
      else 5 - (v_weekly_logins % 5)
    end,
    'fish_awarded', v_weekly_logins % 5 = 0
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
  select * into v_progress
  from public.employee_aquariums
  where employee_id = v_employee_id;

  select count(*)::integer into v_weekly_logins
  from public.employee_aquarium_logins
  where employee_id = v_employee_id
    and logged_in_at >= (
      date_trunc('week', now() at time zone 'Asia/Kuala_Lumpur')
      at time zone 'Asia/Kuala_Lumpur'
    );

  return jsonb_build_object(
    'employee_id', v_employee_id,
    'total_feed', coalesce(v_progress.total_feed, 0),
    'fish_count', coalesce(v_progress.fish_count, 1),
    'weekly_logins', v_weekly_logins,
    'logins_until_next_fish', case
      when v_weekly_logins % 5 = 0 and v_weekly_logins > 0 then 5
      else 5 - (v_weekly_logins % 5)
    end,
    'fish_awarded', false
  );
end;
$$;

revoke all on function public.record_employee_aquarium_login() from public;
revoke all on function public.get_employee_aquarium() from public;
grant execute on function public.record_employee_aquarium_login() to authenticated;
grant execute on function public.get_employee_aquarium() to authenticated;
grant select on public.employee_aquariums to authenticated;
