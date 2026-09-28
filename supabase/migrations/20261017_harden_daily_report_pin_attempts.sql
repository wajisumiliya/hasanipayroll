-- Harden Daily Report PIN verification against online guessing.
-- Keeps the existing first-use flow compatible while rate-limiting failures
-- per authenticated branch.

create table if not exists public.daily_report_pin_attempts (
  branch_id text primary key,
  failed_attempts integer not null default 0 check (failed_attempts >= 0),
  window_started_at timestamptz not null default now(),
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.daily_report_pin_attempts enable row level security;
revoke all on public.daily_report_pin_attempts from public, anon, authenticated;

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

revoke all on function public.verify_daily_report_pin(text)
  from public, anon;
grant execute on function public.verify_daily_report_pin(text)
  to authenticated;

-- Ensure changing the PIN also clears any stale failed-attempt state.
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

revoke all on function public.change_daily_report_pin(text, text)
  from public, anon;
grant execute on function public.change_daily_report_pin(text, text)
  to authenticated;
