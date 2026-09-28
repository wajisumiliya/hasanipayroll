-- Make employee photos private and authorize reads through Storage RLS.
-- Clients receive short-lived signed URLs instead of permanent public URLs.

update storage.buckets
set public = false
where id = 'employee-photos';

drop policy if exists employee_photos_public_read on storage.objects;
drop policy if exists employee_photos_authenticated_read on storage.objects;
create policy employee_photos_authenticated_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'employee-photos'
    and (
      public.current_app_role() in ('admin', 'administrator')
      or (
        public.current_app_role() = 'branch'
        and exists (
          select 1
          from public.employees e
          where e.employee_id = split_part(name, '/', 1)
            and e.branch_id = public.current_branch_id()
        )
      )
      or (
        public.current_app_role() = 'employee'
        and split_part(name, '/', 1) = public.current_employee_id()
      )
    )
  );

-- Keep write permissions restricted to administrators.
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
