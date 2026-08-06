-- Change orders: visible to customers (and team/admin)
-- Documents requested changes so there is a written record.

create table if not exists public.change_orders (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  phase_id uuid references public.phases(id) on delete set null,
  title text not null,
  description text,
  storage_path text,
  public_url text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists change_orders_project_id_idx on public.change_orders(project_id);

alter table public.change_orders enable row level security;

drop policy if exists "change_orders_select" on public.change_orders;
create policy "change_orders_select" on public.change_orders
  for select to authenticated
  using (
    exists (
      select 1 from public.projects p
      where p.id = change_orders.project_id
        and p.company_id = public.my_company_id()
    )
  );

drop policy if exists "change_orders_insert" on public.change_orders;
create policy "change_orders_insert" on public.change_orders
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "change_orders_update" on public.change_orders;
create policy "change_orders_update" on public.change_orders
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "change_orders_delete" on public.change_orders;
create policy "change_orders_delete" on public.change_orders
  for delete to authenticated
  using (public.is_admin());

-- Ensure phase_team exists (team locked to assigned phases)
create table if not exists public.phase_team (
  phase_id uuid not null references public.phases(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (phase_id, user_id)
);

alter table public.phase_team enable row level security;

drop policy if exists "phase_team_select" on public.phase_team;
create policy "phase_team_select" on public.phase_team
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "phase_team_admin" on public.phase_team;
create policy "phase_team_admin" on public.phase_team
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
