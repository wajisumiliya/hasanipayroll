-- Remove the shared/default Daily Report PIN fallback after the PIN and
-- rate-limit tables have been created by the 20261009 and 20261017 migrations.

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
    raise exception 'Daily Report PIN is not configured for this branch';
  end if;

  is_valid := crypt(p_pin, stored_hash) = stored_hash;

  if is_valid then
    delete from public.daily_report_pin_attempts
    where lower(trim(branch_id)) = lower(branch_key);
    return jsonb_build_object('valid', true, 'must_change', false);
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

revoke all on function public.verify_daily_report_pin(text) from public, anon;
grant execute on function public.verify_daily_report_pin(text) to authenticated;

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

  if p_new_pin !~ '^[0-9]{4}$' then
    raise exception 'Choose a new four-digit PIN';
  end if;

  select pin_hash into stored_hash
  from public.daily_report_branch_pins
  where lower(trim(branch_id)) = lower(branch_key)
  for update;

  if stored_hash is null then
    raise exception 'Daily Report PIN is not configured for this branch';
  end if;

  if crypt(p_current_pin, stored_hash) <> stored_hash then
    raise exception 'Incorrect current PIN';
  end if;

  update public.daily_report_branch_pins
  set pin_hash = crypt(p_new_pin, gen_salt('bf')), changed_at = now()
  where lower(trim(branch_id)) = lower(branch_key);

  delete from public.daily_report_pin_attempts
  where lower(trim(branch_id)) = lower(branch_key);
end;
$$;

revoke all on function public.change_daily_report_pin(text, text) from public, anon;
grant execute on function public.change_daily_report_pin(text, text) to authenticated;
