-- Tasks (admin creates, team completes with photos) + notification delete

-- Allow users to delete their own notifications
drop policy if exists "notifications_delete" on public.notifications;
create policy "notifications_delete" on public.notifications
  for delete to authenticated
  using (user_id = auth.uid());

-- Tasks
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'open', -- open | done
  created_by uuid references public.profiles(id),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists tasks_project_id_idx on public.tasks(project_id);

create table if not exists public.task_photos (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  storage_path text not null,
  public_url text,
  caption text,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists task_photos_task_id_idx on public.task_photos(task_id);

alter table public.tasks enable row level security;
alter table public.task_photos enable row level security;

-- Admin full access; team can see tasks on projects they're assigned to (via phase_team)
drop policy if exists "tasks_select" on public.tasks;
create policy "tasks_select" on public.tasks
  for select to authenticated
  using (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'team'
      and exists (
        select 1 from public.phases ph
        join public.phase_team pt on pt.phase_id = ph.id
        where ph.project_id = tasks.project_id
          and pt.user_id = auth.uid()
      )
    )
  );

drop policy if exists "tasks_insert" on public.tasks;
create policy "tasks_insert" on public.tasks
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "tasks_update" on public.tasks;
create policy "tasks_update" on public.tasks
  for update to authenticated
  using (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'team'
      and exists (
        select 1 from public.phases ph
        join public.phase_team pt on pt.phase_id = ph.id
        where ph.project_id = tasks.project_id
          and pt.user_id = auth.uid()
      )
    )
  )
  with check (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'team'
      and exists (
        select 1 from public.phases ph
        join public.phase_team pt on pt.phase_id = ph.id
        where ph.project_id = tasks.project_id
          and pt.user_id = auth.uid()
      )
    )
  );

drop policy if exists "tasks_delete" on public.tasks;
create policy "tasks_delete" on public.tasks
  for delete to authenticated
  using (public.is_admin());

drop policy if exists "task_photos_select" on public.task_photos;
create policy "task_photos_select" on public.task_photos
  for select to authenticated
  using (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'team'
      and exists (
        select 1 from public.tasks t
        join public.phases ph on ph.project_id = t.project_id
        join public.phase_team pt on pt.phase_id = ph.id
        where t.id = task_photos.task_id
          and pt.user_id = auth.uid()
      )
    )
  );

drop policy if exists "task_photos_insert" on public.task_photos;
create policy "task_photos_insert" on public.task_photos
  for insert to authenticated
  with check (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'team'
      and exists (
        select 1 from public.tasks t
        join public.phases ph on ph.project_id = t.project_id
        join public.phase_team pt on pt.phase_id = ph.id
        where t.id = task_photos.task_id
          and pt.user_id = auth.uid()
      )
    )
  );

drop policy if exists "task_photos_delete" on public.task_photos;
create policy "task_photos_delete" on public.task_photos
  for delete to authenticated
  using (public.is_admin() or uploaded_by = auth.uid());

-- Notify team when admin creates a task (optional helper)
create or replace function public.notify_project_team(
  p_company_id uuid,
  p_project_id uuid,
  p_title text,
  p_body text,
  p_kind text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (company_id, user_id, project_id, title, body, kind)
  select distinct p_company_id, pt.user_id, p_project_id, p_title, p_body, p_kind
  from public.phases ph
  join public.phase_team pt on pt.phase_id = ph.id
  where ph.project_id = p_project_id;
end;
$$;

grant execute on function public.notify_project_team(uuid, uuid, text, text, text) to authenticated;
