
-- Notification delete (own only) + targeted notify helpers

drop policy if exists "notifications_delete" on public.notifications;
create policy "notifications_delete" on public.notifications
  for delete to authenticated
  using (user_id = auth.uid());

-- Admins only via notify_company_admins (already)
-- Team on project phases
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
  join public.profiles pr on pr.id = pt.user_id
  where ph.project_id = p_project_id
    and pr.role = 'team';
end;
$$;

-- Customers on a project only
create or replace function public.notify_project_customers(
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
  select distinct p_company_id, pc.user_id, p_project_id, p_title, p_body, p_kind
  from public.project_customers pc
  join public.profiles pr on pr.id = pc.user_id
  where pc.project_id = p_project_id
    and pr.role = 'customer';
end;
$$;

grant execute on function public.notify_project_team(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.notify_project_customers(uuid, uuid, text, text, text) to authenticated;

-- Ensure insert policy allows security definer inserts (function runs as owner)
-- Select remains user_id = auth.uid() so each person only sees their own rows
