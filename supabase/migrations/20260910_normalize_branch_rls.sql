-- Canonical branch matching for standard and FRN branch logins.
-- The JWT may contain a branch name or a configured login alias, while business
-- tables store the canonical branch name.
create or replace function public.normalized_branch_key(value text)
returns text
language sql
immutable
set search_path = public
as $$
  select case regexp_replace(lower(trim(coalesce(value, ''))), '[^a-z0-9]', '', 'g')
    when 'hbsp' then 'sungaipetani'
    when 'hpspfrn' then 'sungaipetani'
    when 'hbspfrn' then 'sungaipetani'
    when 'hbamj' then 'amanjaya'
    when 'hbamjfrn' then 'amanjaya'
    when 'hbas' then 'alorsetar'
    when 'hbasfrn' then 'alorsetar'
    when 'hbastana' then 'astana'
    when 'hbastanafrn' then 'astana'
    when 'hbgurun' then 'gurun'
    when 'hbgurunfrn' then 'gurun'
    when 'hbjitra' then 'jitra'
    when 'hbjitrafrn' then 'jitra'
    when 'hbperai' then 'prai'
    when 'hbperaifrn' then 'prai'
    when 'hbkulim' then 'kulim'
    when 'hbkulimfrn' then 'kulim'
    when 'hblkw' then 'langkawi'
    when 'hblkwfrn' then 'langkawi'
    else regexp_replace(lower(trim(coalesce(value, ''))), '[^a-z0-9]', '', 'g')
  end;
$$;

revoke all on function public.normalized_branch_key(text) from public;
grant execute on function public.normalized_branch_key(text) to authenticated;

drop policy if exists monthly_rosters_branch_all on public.monthly_rosters;
create policy monthly_rosters_branch_all on public.monthly_rosters
  for all to authenticated
  using (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  )
  with check (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  );

-- Keep branch logs consistent with the same alias rules.
drop policy if exists branch_logs_branch_insert on public.branch_activity_logs;
drop policy if exists branch_logs_branch_update on public.branch_activity_logs;

create policy branch_logs_branch_insert on public.branch_activity_logs
  for insert to authenticated
  with check (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  );

create policy branch_logs_branch_update on public.branch_activity_logs
  for update to authenticated
  using (
    public.current_app_role() = 'branch'
    and public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  )
  with check (
    public.normalized_branch_key(branch_id) =
        public.normalized_branch_key(public.current_branch_id())
  );