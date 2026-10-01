-- Attendance-only admin account used for the dedicated attendance dashboard.
-- Username: account
-- Password: attacc
-- Access: admin-level attendance editing across all branches, but no other dashboard sections.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

do $$
declare
  password_hash text := extensions.crypt(
    'attacc',
    extensions.gen_salt('bf', 12)
  );
  uses_prisma_layout boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_user'
      and column_name = 'employeeId'
  ) into uses_prisma_layout;

  if uses_prisma_layout then
    insert into public."app_user" (
      "id",
      "employeeId",
      "username",
      "email",
      "passwordHash",
      "role",
      "isActive",
      "mustChangePassword",
      "passwordChangedAt",
      "createdAt",
      "updatedAt"
    )
    values (
      'attendance-account',
      null,
      'account',
      'account@attendance.local',
      password_hash,
      'ADMIN',
      true,
      false,
      null,
      now(),
      now()
    )
    on conflict ("email") do update
    set
      "username" = excluded."username",
      "passwordHash" = excluded."passwordHash",
      "role" = excluded."role",
      "isActive" = excluded."isActive",
      "mustChangePassword" = excluded."mustChangePassword",
      "passwordChangedAt" = excluded."passwordChangedAt",
      "updatedAt" = now();
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_user'
      and column_name = 'employee_id'
  ) then
    insert into public.app_user (
      username,
      role,
      branch_id,
      employee_id,
      display_name,
      is_active,
      first_login,
      email,
      "passwordHash",
      created_at,
      updated_at
    )
    values (
      'account',
      'admin',
      null,
      null,
      'Attendance Admin',
      true,
      false,
      'account@attendance.local',
      password_hash,
      now(),
      now()
    )
    on conflict (username) do update
    set
      role = excluded.role,
      branch_id = excluded.branch_id,
      employee_id = excluded.employee_id,
      display_name = excluded.display_name,
      is_active = excluded.is_active,
      first_login = excluded.first_login,
      email = excluded.email,
      "passwordHash" = excluded."passwordHash",
      updated_at = now();
  else
    raise exception 'Unsupported public.app_user column layout';
  end if;
end;
$$;
