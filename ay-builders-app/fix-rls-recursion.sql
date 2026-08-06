-- Fix: infinite recursion in projects / project_customers policies
-- Run once in Supabase SQL Editor

-- Helper: can this user see this project? (bypasses RLS to avoid recursion)
create or replace function public.can_view_project(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = p_id
      and p.company_id = (select company_id from public.profiles where id = auth.uid())
      and (
        (select role from public.profiles where id = auth.uid()) in ('admin', 'team')
        or exists (
          select 1 from public.project_customers pc
          where pc.project_id = p.id and pc.user_id = auth.uid()
        )
      )
  );
$$;

create or replace function public.can_admin_company()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and company_id is not null
  );
$$;

-- Recreate projects policies without recursive subqueries on RLS tables
drop policy if exists "projects_select" on public.projects;
drop policy if exists "projects_admin_write" on public.projects;
drop policy if exists "projects_insert" on public.projects;
drop policy if exists "projects_update" on public.projects;
drop policy if exists "projects_delete" on public.projects;

create policy "projects_select" on public.projects
  for select to authenticated
  using (public.can_view_project(id));

create policy "projects_insert" on public.projects
  for insert to authenticated
  with check (
    company_id = public.my_company_id()
    and public.can_admin_company()
  );

create policy "projects_update" on public.projects
  for update to authenticated
  using (company_id = public.my_company_id() and public.can_admin_company())
  with check (company_id = public.my_company_id() and public.can_admin_company());

create policy "projects_delete" on public.projects
  for delete to authenticated
  using (company_id = public.my_company_id() and public.can_admin_company());

-- project_customers: use helper instead of selecting projects under RLS
drop policy if exists "pc_select" on public.project_customers;
drop policy if exists "pc_admin_write" on public.project_customers;

create policy "pc_select" on public.project_customers
  for select to authenticated
  using (public.can_view_project(project_id));

create policy "pc_insert" on public.project_customers
  for insert to authenticated
  with check (public.can_admin_company() and public.can_view_project(project_id));

create policy "pc_update" on public.project_customers
  for update to authenticated
  using (public.can_admin_company())
  with check (public.can_admin_company());

create policy "pc_delete" on public.project_customers
  for delete to authenticated
  using (public.can_admin_company());

-- phases: avoid recursion via helper
drop policy if exists "phases_select" on public.phases;
drop policy if exists "phases_admin_write" on public.phases;

create policy "phases_select" on public.phases
  for select to authenticated
  using (public.can_view_project(project_id));

create policy "phases_insert" on public.phases
  for insert to authenticated
  with check (public.can_admin_company() and public.can_view_project(project_id));

create policy "phases_update" on public.phases
  for update to authenticated
  using (public.can_admin_company() and public.can_view_project(project_id))
  with check (public.can_admin_company() and public.can_view_project(project_id));

create policy "phases_delete" on public.phases
  for delete to authenticated
  using (public.can_admin_company() and public.can_view_project(project_id));
