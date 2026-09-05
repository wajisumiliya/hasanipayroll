-- Keep the employee table aligned with employee requests and application models.
alter table public.employees
  add column if not exists phone text;
