-- Allow the two new public-holiday attendance categories used by the app.
-- This supports both deployments where attendance.status is text + CHECK and
-- deployments where it is backed by a PostgreSQL enum.

do $$
declare
  status_type_kind "char";
  status_type_schema text;
  status_type_name text;
  status_attribute_number smallint;
  constraint_record record;
begin
  select
    type_row.typtype,
    type_namespace.nspname,
    type_row.typname,
    attribute_row.attnum
  into
    status_type_kind,
    status_type_schema,
    status_type_name,
    status_attribute_number
  from pg_attribute as attribute_row
  join pg_type as type_row
    on type_row.oid = attribute_row.atttypid
  join pg_namespace as type_namespace
    on type_namespace.oid = type_row.typnamespace
  where attribute_row.attrelid = 'public.attendance'::regclass
    and attribute_row.attname = 'status'
    and not attribute_row.attisdropped;

  if status_attribute_number is null then
    raise exception 'public.attendance.status does not exist';
  end if;

  if status_type_kind = 'e' then
    execute format(
      'alter type %I.%I add value if not exists %L',
      status_type_schema,
      status_type_name,
      'PH-OFF'
    );
    execute format(
      'alter type %I.%I add value if not exists %L',
      status_type_schema,
      status_type_name,
      'PH-SPL'
    );
  else
    -- Remove the prior status allow-list regardless of its generated name.
    for constraint_record in
      select constraint_row.conname
      from pg_constraint as constraint_row
      where constraint_row.conrelid = 'public.attendance'::regclass
        and constraint_row.contype = 'c'
        and constraint_row.conkey @> array[status_attribute_number]
        and pg_get_constraintdef(constraint_row.oid) ilike '%status%'
    loop
      execute format(
        'alter table public.attendance drop constraint %I',
        constraint_record.conname
      );
    end loop;

    alter table public.attendance
      add constraint attendance_status_check
      check (
        status in (
          'Present',
          'Late',
          'Early Out',
          'Late + Early Out',
          'Absent',
          'OFF',
          'MC',
          'PL',
          'AL',
          'EL',
          'PH',
          'PH-OFF',
          'PH-SPL',
          'UNPAID'
        )
      ) not valid;

    alter table public.attendance
      validate constraint attendance_status_check;
  end if;
end;
$$;
