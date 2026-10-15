-- Garden courtyard API. Existing engagement history is retained while the
-- public contract now describes garden care and feature unlocks.
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

revoke all on function public.get_employee_garden() from public, anon;
revoke all on function public.record_employee_garden_visit() from public, anon;
revoke all on function public.tend_employee_garden() from public, anon;
grant execute on function public.get_employee_garden() to authenticated;
grant execute on function public.record_employee_garden_visit() to authenticated;
grant execute on function public.tend_employee_garden() to authenticated;
