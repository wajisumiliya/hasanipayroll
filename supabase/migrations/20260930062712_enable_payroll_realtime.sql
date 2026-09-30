do $$
begin
  alter publication supabase_realtime
    add table public.payroll;
exception
  when duplicate_object then null;
end
$$;
