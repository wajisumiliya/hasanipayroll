-- Branch-specific Daily Report PIN. The one-time default is 2026.
create extension if not exists pgcrypto;

create table if not exists public.daily_report_branch_pins (
  branch_id text primary key,
  pin_hash text not null,
  changed_at timestamptz not null default now()
);

alter table public.daily_report_branch_pins enable row level security;
revoke all on table public.daily_report_branch_pins from anon, authenticated;

create or replace function public.verify_daily_report_pin(p_pin text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare stored_hash text;
begin
  if public.current_app_role() <> 'branch' or public.current_branch_id() = '' then
    raise exception 'Branch access required';
  end if;
  select pin_hash into stored_hash from public.daily_report_branch_pins
  where lower(trim(branch_id)) = lower(trim(public.current_branch_id()));
  if stored_hash is null then
    return jsonb_build_object('valid', p_pin = '2026',
      'must_change', p_pin = '2026');
  end if;
  return jsonb_build_object('valid', crypt(p_pin, stored_hash) = stored_hash,
    'must_change', false);
end;
$$;

create or replace function public.change_daily_report_pin(
  p_current_pin text, p_new_pin text
) returns void language plpgsql security definer
set search_path = public, extensions as $$
declare
  stored_hash text;
  canonical_branch_id text := trim(public.current_branch_id());
begin
  if public.current_app_role() <> 'branch' or canonical_branch_id = '' then
    raise exception 'Branch access required';
  end if;
  if p_new_pin !~ '^[0-9]{4}$' then
    raise exception 'The new PIN must contain exactly 4 digits';
  end if;
  if p_new_pin = '2026' then
    raise exception 'The default PIN cannot be reused';
  end if;
  select pin_hash into stored_hash from public.daily_report_branch_pins
  where lower(trim(branch_id)) = lower(canonical_branch_id) for update;
  if (stored_hash is null and p_current_pin <> '2026') or
     (stored_hash is not null and crypt(p_current_pin, stored_hash) <> stored_hash) then
    raise exception 'Incorrect current PIN';
  end if;
  insert into public.daily_report_branch_pins(branch_id, pin_hash, changed_at)
  values (canonical_branch_id, crypt(p_new_pin, gen_salt('bf')), now())
  on conflict (branch_id) do update set
    pin_hash = excluded.pin_hash, changed_at = excluded.changed_at;
end;
$$;

revoke all on function public.verify_daily_report_pin(text) from public;
revoke all on function public.change_daily_report_pin(text, text) from public;
grant execute on function public.verify_daily_report_pin(text) to authenticated;
grant execute on function public.change_daily_report_pin(text, text) to authenticated;
