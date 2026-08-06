-- Full feature pack (no email verification required)

-- Projects: archive
alter table public.projects add column if not exists archived boolean not null default false;

-- Phases: schedule dates
alter table public.phases add column if not exists start_date date;
alter table public.phases add column if not exists end_date date;

-- Photos: before/after tag
alter table public.photos add column if not exists tag text; -- null | before | after

-- Activity: link to project
alter table public.activity add column if not exists project_id uuid references public.projects(id) on delete cascade;

-- In-app notifications for admins
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  project_id uuid references public.projects(id) on delete cascade,
  title text not null,
  body text,
  kind text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_idx on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "notifications_select" on public.notifications;
create policy "notifications_select" on public.notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "notifications_update" on public.notifications;
create policy "notifications_update" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "notifications_insert" on public.notifications;
create policy "notifications_insert" on public.notifications
  for insert to authenticated with check (
    public.is_admin() or company_id = public.my_company_id()
  );

-- Helper: notify all admins in company
create or replace function public.notify_company_admins(
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
  select p_company_id, pr.id, p_project_id, p_title, p_body, p_kind
  from public.profiles pr
  where pr.company_id = p_company_id and pr.role = 'admin';
end;
$$;

grant execute on function public.notify_company_admins(uuid, uuid, text, text, text) to authenticated;
