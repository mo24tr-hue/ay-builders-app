-- Fix: admin can remove other users from the company
-- (update profiles.company_id without RLS recursion)

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.my_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select company_id from public.profiles where id = auth.uid();
$$;

-- Security-definer helper: admin removes a user from their company
create or replace function public.admin_remove_user_from_company(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_company uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_admin() then
    raise exception 'Only admins can remove users';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'You cannot remove yourself';
  end if;

  select company_id into admin_company
  from public.profiles
  where id = auth.uid();

  if admin_company is null then
    raise exception 'No company on admin profile';
  end if;

  -- Only remove if they belong to the same company
  update public.profiles
  set company_id = null,
      role = 'team'
  where id = target_user_id
    and company_id = admin_company;

  delete from public.project_customers
  where user_id = target_user_id;
end;
$$;

grant execute on function public.admin_remove_user_from_company(uuid) to authenticated;

-- Keep normal profile update policies for self-edit
drop policy if exists "profiles_update" on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;
drop policy if exists "profiles_update_admin" on public.profiles;

create policy "profiles_update_self" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
