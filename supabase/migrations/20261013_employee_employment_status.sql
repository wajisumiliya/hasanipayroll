-- Support employee statuses beyond the legacy active/resigned boolean.
-- Vacation remains active. Transferred is inactive but is never auto-deleted.

alter table public.employees
  add column if not exists employment_status text;

update public.employees
set employment_status = case when is_active then 'active' else 'resigned' end
where employment_status is null;

alter table public.employees
  alter column employment_status set default 'active',
  alter column employment_status set not null;

alter table public.employees
  drop constraint if exists employees_employment_status_check;

alter table public.employees
  add constraint employees_employment_status_check
  check (employment_status in ('active', 'resigned', 'transferred', 'vacation'));

comment on column public.employees.employment_status is
  'Employment state: active, resigned, transferred, or vacation.';

create or replace function public.sync_employee_resigned_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- Preserve compatibility with callers that still update only is_active.
  if tg_op = 'UPDATE'
     and new.is_active is distinct from old.is_active
     and new.employment_status is not distinct from old.employment_status then
    new.employment_status := case when new.is_active then 'active' else 'resigned' end;
  end if;

  new.is_active := new.employment_status in ('active', 'vacation');

  if new.employment_status = 'resigned' then
    if tg_op = 'INSERT'
       or old.employment_status is distinct from 'resigned'
       or old.resigned_at is null then
      new.resigned_at := now();
    end if;
  else
    new.resigned_at := null;
  end if;

  return new;
end;
$$;

drop index if exists public.employees_resigned_purge_idx;
create index employees_resigned_purge_idx
  on public.employees (resigned_at)
  where employment_status = 'resigned' and resigned_at is not null;

