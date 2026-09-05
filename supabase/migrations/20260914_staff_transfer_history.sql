create extension if not exists pgcrypto;
create table if not exists public.staff_transfer_history (
  id uuid primary key default gen_random_uuid(), employee_id text not null,
  employee_name text, from_branch_id text not null, to_branch_id text not null,
  effective_date date not null default current_date, reason text,
  transferred_at timestamptz not null default now(), transferred_by text not null
);
create index if not exists staff_transfer_history_employee_idx on public.staff_transfer_history (employee_id, transferred_at desc);
alter table public.staff_transfer_history enable row level security;
drop policy if exists staff_transfer_history_admin_read on public.staff_transfer_history;
create policy staff_transfer_history_admin_read on public.staff_transfer_history for select to authenticated using (public.current_app_role() in ('admin','administrator'));
grant select on public.staff_transfer_history to authenticated;
create or replace function public.transfer_staff(p_employee_id text, p_to_branch_id text, p_effective_date date default current_date, p_reason text default null)
returns public.staff_transfer_history language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.employees; h public.staff_transfer_history; eid text:=trim(coalesce(p_employee_id,'')); destination text:=trim(coalesce(p_to_branch_id,''));
begin
 if public.current_app_role() not in ('admin','administrator') then raise exception 'Administrator access required'; end if;
 if eid='' or destination='' then raise exception 'Employee and destination branch are required'; end if;
 select * into e from public.employees where employee_id=eid for update;
 if not found then raise exception 'Employee % was not found',eid; end if;
 if public.normalized_branch_key(e.branch_id)=public.normalized_branch_key(destination) then raise exception 'Employee already belongs to this branch'; end if;
 update public.employees set branch_id=destination where employee_id=eid;
 insert into public.staff_transfer_history(employee_id,employee_name,from_branch_id,to_branch_id,effective_date,reason,transferred_by)
 values(eid,e.name,e.branch_id,destination,coalesce(p_effective_date,current_date),nullif(trim(p_reason),''),coalesce(auth.jwt()->>'sub','admin')) returning * into h;
 return h;
end; $$;
revoke all on function public.transfer_staff(text,text,date,text) from public;
grant execute on function public.transfer_staff(text,text,date,text) to authenticated;