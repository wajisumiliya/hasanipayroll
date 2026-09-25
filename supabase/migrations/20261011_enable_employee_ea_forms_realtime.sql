do $$
begin
  alter publication supabase_realtime
    add table public.employee_ea_forms;
exception
  when duplicate_object then null;
end
$$;
