create table if not exists public.employee_ea_forms (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.employees(employee_id) on delete cascade,
  tax_year integer not null check (tax_year between 2000 and 2100),
  form_data jsonb not null default '{}'::jsonb,
  generated_by text,
  generated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, tax_year)
);

create index if not exists employee_ea_forms_employee_year_idx
  on public.employee_ea_forms (employee_id, tax_year desc);

alter table public.employee_ea_forms enable row level security;

drop policy if exists employee_ea_forms_admin_all on public.employee_ea_forms;
create policy employee_ea_forms_admin_all on public.employee_ea_forms
  for all to authenticated
  using (public.current_app_role() in ('admin', 'foreign_admin'))
  with check (public.current_app_role() in ('admin', 'foreign_admin'));

drop policy if exists employee_ea_forms_self_read on public.employee_ea_forms;
create policy employee_ea_forms_self_read on public.employee_ea_forms
  for select to authenticated
  using (
    public.current_app_role() = 'employee'
    and employee_id = public.current_employee_id()
  );

grant select, insert, update, delete on public.employee_ea_forms to authenticated;
