-- Remove the shared/default Daily Report PIN fallback.
-- A branch must have a stored branch-specific PIN before verification/change is allowed.

create or replace function public.verify_daily_report_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'extensions'
as $function$
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
    return jsonb_build_object('valid', true);
  end if;

  insert into public.daily_report_pin_attempts(branch_id, failed_attempts, last_attempt_at, locked_until)
  values (branch_key, 1, now_at, null)
  on conflict (branch_id) do update
    set failed_attempts = public.daily_report_pin_attempts.failed_attempts + 1,
        last_attempt_at = now_at,
        locked_until = case when public.daily_report_pin_attempts.failed_attempts + 1 >= 5
          then now_at + interval '15 minutes' else null end;
  return jsonb_build_object('valid', false);
end;
$function$;

create or replace function public.change_daily_report_pin(p_current_pin text, p_new_pin text)
returns void
language plpgsql
security definer
set search_path = 'public', 'extensions'
as $function$
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
$function$;
