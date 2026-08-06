
-- Enable Realtime for live updates (run in Supabase SQL Editor)
-- If a line errors with "already member", ignore it.

begin;

-- Ensure publication exists (Supabase creates supabase_realtime by default)
alter publication supabase_realtime add table public.projects;
alter publication supabase_realtime add table public.phases;
alter publication supabase_realtime add table public.photos;
alter publication supabase_realtime add table public.change_orders;
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.task_photos;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.project_files;
alter publication supabase_realtime add table public.phase_files;
alter publication supabase_realtime add table public.phase_team;
alter publication supabase_realtime add table public.project_customers;
alter publication supabase_realtime add table public.activity;

commit;
