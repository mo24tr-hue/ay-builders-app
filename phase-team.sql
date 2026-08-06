-- Phase-level team access
-- Team users only see phases (and parent projects) they are assigned to.

create table if not exists public.phase_team (
  phase_id uuid not null references public.phases(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (phase_id, user_id)
);

alter table public.phase_team enable row level security;

drop policy if exists "phase_team_select" on public.phase_team;
create policy "phase_team_select" on public.phase_team
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
  );

drop policy if exists "phase_team_admin" on public.phase_team;
create policy "phase_team_admin" on public.phase_team
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Optional: migrate existing project_team rows is not automatic
-- (admin should assign team per phase going forward)
