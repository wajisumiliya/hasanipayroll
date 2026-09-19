-- Keep exactly one request-approval account so the backend's username/email
-- lookup cannot select an older conflicting row with a different password.
-- Some older databases had the obsolete plain-text password column removed
-- before the replacement hash column was added. Repair that schema first.
alter table public."app_user"
  add column if not exists "passwordHash" text;

delete from public."app_user"
where lower(trim(coalesce("username", ''))) = 'hbreq'
   or lower(trim(coalesce("email", ''))) = 'hbreq';

insert into public."app_user" (
  "username",
  "email",
  "passwordHash",
  "role"
)
select
  'hbreq',
  'hbreq',
  '$2b$12$O6sRmPbMDpF8iovrfIHJeOox6ud51yD3vcE9hygO7iETQPJ.R9l/W',
  "role"
from public."app_user"
where lower(trim("role"::text)) = 'admin'
limit 1;

do $$
begin
  if not exists (
    select 1
    from public."app_user"
    where lower(trim(coalesce("username", ''))) = 'hbreq'
      and "passwordHash" is not null
  ) then
    raise exception 'Unable to create hbreq: no existing admin role was available';
  end if;
end;
$$;
