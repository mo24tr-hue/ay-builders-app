-- Phase-level plans/files (admin + team only via app filtering; RLS company-scoped)
create table if not exists public.phase_files (
  id uuid primary key default gen_random_uuid(),
  phase_id uuid not null references public.phases(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  storage_path text not null,
  public_url text,
  file_name text,
  file_type text,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists phase_files_phase_id_idx on public.phase_files(phase_id);

alter table public.phase_files enable row level security;

drop policy if exists "phase_files_select" on public.phase_files;
create policy "phase_files_select" on public.phase_files
  for select to authenticated
  using (
    exists (
      select 1 from public.projects p
      where p.id = phase_files.project_id
        and p.company_id = public.my_company_id()
        and public.current_role() in ('admin', 'team')
    )
  );

drop policy if exists "phase_files_write" on public.phase_files;
create policy "phase_files_write" on public.phase_files
  for all to authenticated
  using (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'team'
      and exists (
        select 1 from public.phase_team pt
        where pt.phase_id = phase_files.phase_id and pt.user_id = auth.uid()
      )
    )
  )
  with check (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'team'
      and exists (
        select 1 from public.phase_team pt
        where pt.phase_id = phase_files.phase_id and pt.user_id = auth.uid()
      )
    )
  );

-- Ensure phase_team exists
create table if not exists public.phase_team (
  phase_id uuid not null references public.phases(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (phase_id, user_id)
);
alter table public.phase_team enable row level security;
drop policy if exists "phase_team_select" on public.phase_team;
create policy "phase_team_select" on public.phase_team for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists "phase_team_admin" on public.phase_team;
create policy "phase_team_admin" on public.phase_team for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
