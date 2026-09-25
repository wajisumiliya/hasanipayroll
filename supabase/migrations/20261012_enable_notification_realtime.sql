do $$
begin
  alter publication supabase_realtime
    add table public.app_notifications;
exception
  when duplicate_object then null;
end
$$;
