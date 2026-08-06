# AY Builders – Multi-company project tracker

React + Vite + Supabase app. Each company has its own admins, team, customers, and projects.

## Setup

1. Install Node.js 18+ from https://nodejs.org
2. Open a terminal in this folder
3. Copy env (already filled for your project if `.env` exists):

```bash
cp .env.example .env
# Edit .env with your Supabase URL + publishable key
```

4. Install and run:

```bash
npm install
npm run dev
```

5. Open the local URL shown (usually http://localhost:5173)

## Supabase extras (invites)

Run this in SQL Editor once:

```sql
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

create policy "invites_admin" on public.company_invites for all to authenticated
  using (
    company_id = public.my_company_id() and public.is_admin()
  )
  with check (
    company_id = public.my_company_id() and public.is_admin()
  );

-- Allow a signing-up user to read their own invite by email (before they have company_id)
create policy "invites_read_own_email" on public.company_invites for select to authenticated
  using (email = auth.jwt() ->> 'email');

create policy "invites_delete_own" on public.company_invites for delete to authenticated
  using (email = auth.jwt() ->> 'email' or (company_id = public.my_company_id() and public.is_admin()));
```

## Deploy (later)

```bash
npm run build
```

Deploy the `dist/` folder to Vercel, Netlify, or similar. Set the same `VITE_` env vars in the host dashboard.

## Roles

| Role | Access |
|------|--------|
| admin | Full control within their company |
| team | View company projects, upload photos |
| customer | Only assigned projects; view photos, trade, progress |
