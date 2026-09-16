create table if not exists public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  employee_id text,
  branch_id text,
  platform text not null default 'unknown',
  updated_at timestamptz not null default now()
);

create index if not exists notification_devices_employee_idx
  on public.notification_devices (employee_id);
create index if not exists notification_devices_branch_idx
  on public.notification_devices (branch_id);

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  notification_type text not null default 'information',
  audience text not null check (audience in ('all', 'branch', 'employee')),
  branch_id text,
  employee_id text,
  created_at timestamptz not null default now()
);

alter table public.notification_devices enable row level security;
alter table public.app_notifications enable row level security;

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
begin
  insert into public.notification_devices (
    token, employee_id, branch_id, platform, updated_at
  ) values (
    p_token, nullif(trim(p_employee_id), ''), nullif(trim(p_branch_id), ''),
    p_platform, now()
  )
  on conflict (token) do update set
    employee_id = excluded.employee_id,
    branch_id = excluded.branch_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;

grant execute on function public.register_notification_device(text, text, text, text)
  to anon, authenticated;

revoke all on public.notification_devices from anon, authenticated;
revoke all on public.app_notifications from anon, authenticated;
