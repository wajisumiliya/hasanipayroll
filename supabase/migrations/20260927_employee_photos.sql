alter table public.employees
  add column if not exists photo_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'employee-photos',
  'employee-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists employee_photos_public_read on storage.objects;
create policy employee_photos_public_read on storage.objects
  for select
  using (bucket_id = 'employee-photos');

drop policy if exists employee_photos_admin_insert on storage.objects;
create policy employee_photos_admin_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'employee-photos'
    and public.current_app_role() in ('admin', 'administrator')
  );

drop policy if exists employee_photos_admin_update on storage.objects;
create policy employee_photos_admin_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'employee-photos'
    and public.current_app_role() in ('admin', 'administrator')
  )
  with check (
    bucket_id = 'employee-photos'
    and public.current_app_role() in ('admin', 'administrator')
  );

drop policy if exists employee_photos_admin_delete on storage.objects;
create policy employee_photos_admin_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'employee-photos'
    and public.current_app_role() in ('admin', 'administrator')
  );
