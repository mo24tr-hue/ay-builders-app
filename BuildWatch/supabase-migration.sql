-- Run in Supabase SQL Editor on project kqvkgmraztpszjoqcvvf
-- Adds fields used by the latest app version

-- Company branding
alter table public.companies
  add column if not exists logo_url text,
  add column if not exists app_share_url text;

-- Project admin notes + ensure company_id exists (from multi-company schema)
alter table public.projects
  add column if not exists admin_notes text;

-- Custom project types per company (JSON map of key -> { label, phases[] })
create table if not exists public.company_styles (
  company_id uuid primary key references public.companies(id) on delete cascade,
  styles jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now()
);

alter table public.company_styles enable row level security;

drop policy if exists "styles_select" on public.company_styles;
create policy "styles_select" on public.company_styles for select to authenticated
  using (company_id = public.my_company_id());

drop policy if exists "styles_admin" on public.company_styles;
create policy "styles_admin" on public.company_styles for all to authenticated
  using (company_id = public.my_company_id() and public.is_admin())
  with check (company_id = public.my_company_id() and public.is_admin());

-- Invites (if not already created)
create table if not exists public.company_invites (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  email text not null,
  role text not null default 'team' check (role in ('admin', 'team', 'customer')),
  name text,
  invited_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (company_id, email)
);

alter table public.company_invites enable row level security;

drop policy if exists "invites_admin" on public.company_invites;
create policy "invites_admin" on public.company_invites for all to authenticated
  using (company_id = public.my_company_id() and public.is_admin())
  with check (company_id = public.my_company_id() and public.is_admin());

drop policy if exists "invites_read_own_email" on public.company_invites;
create policy "invites_read_own_email" on public.company_invites for select to authenticated
  using (email = auth.jwt() ->> 'email');

drop policy if exists "invites_delete_own" on public.company_invites;
create policy "invites_delete_own" on public.company_invites for delete to authenticated
  using (
    email = auth.jwt() ->> 'email'
    or (company_id = public.my_company_id() and public.is_admin())
  );
