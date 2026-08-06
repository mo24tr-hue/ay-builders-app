-- AY Builders feature update — run in Supabase SQL Editor

-- Phase admin notes
alter table public.phases add column if not exists admin_notes text;

-- Media type on photos (image | video)
alter table public.photos add column if not exists media_type text default 'image';

-- Project files (plans, PDFs, etc.)
create table if not exists public.project_files (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  storage_path text not null,
  public_url text,
  file_name text,
  file_type text,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.project_files enable row level security;

drop policy if exists "project_files_select" on public.project_files;
create policy "project_files_select" on public.project_files
  for select to authenticated
  using (
    exists (
      select 1 from public.projects p
      where p.id = project_files.project_id
        and p.company_id = public.my_company_id()
    )
  );

drop policy if exists "project_files_insert" on public.project_files;
create policy "project_files_insert" on public.project_files
  for insert to authenticated
  with check (
    public.is_admin()
    or (select role from public.profiles where id = auth.uid()) = 'team'
  );

drop policy if exists "project_files_delete" on public.project_files;
create policy "project_files_delete" on public.project_files
  for delete to authenticated
  using (public.is_admin());

-- Team members assigned to projects (lock team to allowed projects)
create table if not exists public.project_team (
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (project_id, user_id)
);

alter table public.project_team enable row level security;

drop policy if exists "project_team_select" on public.project_team;
create policy "project_team_select" on public.project_team
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or (select role from public.profiles where id = auth.uid()) = 'team'
  );

drop policy if exists "project_team_admin" on public.project_team;
create policy "project_team_admin" on public.project_team
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Temp password / OTP on invites
alter table public.company_invites add column if not exists temp_password text;

-- Photo delete policy for admin
drop policy if exists "photos_delete" on public.photos;
create policy "photos_delete" on public.photos
  for delete to authenticated
  using (public.is_admin());

-- Phase delete already covered by phases_write_admin if exists; ensure admin can delete
drop policy if exists "phases_delete" on public.phases;
create policy "phases_delete" on public.phases
  for delete to authenticated
  using (public.is_admin());

-- Helper: can team user see this project?
create or replace function public.can_team_view_project(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin()
    or exists (
      select 1 from public.project_team pt
      where pt.project_id = p_id and pt.user_id = auth.uid()
    )
    or exists (
      select 1 from public.project_customers pc
      where pc.project_id = p_id and pc.user_id = auth.uid()
    )
    or (
      (select role from public.profiles where id = auth.uid()) in ('admin', 'team')
      and not exists (select 1 from public.project_team pt2 where pt2.project_id = p_id)
      and (select company_id from public.projects where id = p_id) = public.my_company_id()
    );
$$;

-- Note: if a project has NO project_team rows, all company team/admin can see it (backward compatible).
-- Once admin assigns team members, only those assigned (+ admin + customers) see it.
