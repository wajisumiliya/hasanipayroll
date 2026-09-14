create table if not exists public.company_tree_daily_logins (
  employee_id text not null,
  login_date date not null,
  created_at timestamptz not null default now(),
  primary key (employee_id, login_date)
);

alter table public.company_tree_daily_logins enable row level security;

create or replace function public.get_company_login_tree()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'totalGrowth', count(*),
    'todayGrowth', count(*) filter (
      where login_date = (now() at time zone 'Asia/Kuala_Lumpur')::date
    ),
    'contributors', count(distinct employee_id),
    'asOfDate', (now() at time zone 'Asia/Kuala_Lumpur')::date
  )
  from public.company_tree_daily_logins;
$$;

create or replace function public.record_company_tree_login()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  employee_key text := upper(trim(public.current_employee_id()));
begin
  if public.current_app_role() <> 'employee' or employee_key = '' then
    raise exception 'An employee login is required';
  end if;

  insert into public.company_tree_daily_logins (employee_id, login_date)
  values (
    employee_key,
    (now() at time zone 'Asia/Kuala_Lumpur')::date
  )
  on conflict (employee_id, login_date) do nothing;

  return public.get_company_login_tree();
end;
$$;

revoke all on table public.company_tree_daily_logins from public, anon, authenticated;
revoke all on function public.get_company_login_tree() from public;
revoke all on function public.record_company_tree_login() from public, anon;
grant execute on function public.get_company_login_tree() to anon, authenticated;
grant execute on function public.record_company_tree_login() to authenticated;
