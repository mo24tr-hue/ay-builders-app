-- Customer-requested change orders with admin approval

alter table public.change_orders
  add column if not exists status text not null default 'approved';

alter table public.change_orders
  add column if not exists decided_at timestamptz;

alter table public.change_orders
  add column if not exists decided_by uuid references public.profiles(id);

-- pending | approved | rejected
update public.change_orders set status = 'approved' where status is null or status = '';

drop policy if exists "change_orders_insert" on public.change_orders;
create policy "change_orders_insert" on public.change_orders
  for insert to authenticated
  with check (
    public.is_admin()
    or (
      (select role from public.profiles where id = auth.uid()) = 'customer'
      and exists (
        select 1 from public.project_customers pc
        where pc.project_id = change_orders.project_id
          and pc.user_id = auth.uid()
      )
      and status = 'pending'
      and created_by = auth.uid()
    )
  );

drop policy if exists "change_orders_update" on public.change_orders;
create policy "change_orders_update" on public.change_orders
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "change_orders_delete" on public.change_orders;
create policy "change_orders_delete" on public.change_orders
  for delete to authenticated
  using (public.is_admin());
