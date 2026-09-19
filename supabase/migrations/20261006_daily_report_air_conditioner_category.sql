-- Air Conditioner records a category/description, not a numeric count.
-- Preserve current numeric values as text while allowing category input.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'daily_reports'
      and column_name = 'air_conditioner'
      and data_type <> 'text'
  ) then
    alter table public.daily_reports
      alter column air_conditioner drop default,
      alter column air_conditioner type text using air_conditioner::text,
      alter column air_conditioner set default '';
  end if;
end;
$$;
