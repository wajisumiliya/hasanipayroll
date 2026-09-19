create table if not exists public.notification_reads (
  notification_id uuid not null references public.app_notifications(id) on delete cascade,
  employee_id text not null,
  read_at timestamptz not null default now(),
  primary key (notification_id, employee_id)
);

alter table public.notification_reads enable row level security;

drop policy if exists app_notifications_employee_read on public.app_notifications;
create policy app_notifications_employee_read on public.app_notifications
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and audience = 'employee'
    and employee_id = public.current_employee_id()
  );

drop policy if exists notification_reads_employee_read on public.notification_reads;
create policy notification_reads_employee_read on public.notification_reads
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );

drop policy if exists notification_reads_employee_insert on public.notification_reads;
create policy notification_reads_employee_insert on public.notification_reads
  for insert to authenticated
  with check (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
    and exists (
      select 1 from public.app_notifications n
      where n.id = notification_reads.notification_id
        and n.audience = 'employee'
        and n.employee_id = notification_reads.employee_id
    )
  );

drop policy if exists notification_reads_employee_update on public.notification_reads;
create policy notification_reads_employee_update on public.notification_reads
  for update to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  )
  with check (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );

grant select on public.app_notifications to authenticated;
grant select, insert, update on public.notification_reads to authenticated;
