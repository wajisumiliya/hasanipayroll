alter table public.employees
  add column if not exists birthday date;

comment on column public.employees.birthday is
  'Employee date of birth used for upcoming birthday reminders.';
