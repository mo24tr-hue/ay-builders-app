
alter table public.change_orders add column if not exists amount numeric(12,2);
alter table public.change_orders add column if not exists admin_reply text;

-- Customers can accept/decline a quote on their project
drop policy if exists "change_orders_customer_decide" on public.change_orders;
create policy "change_orders_customer_decide" on public.change_orders
  for update to authenticated
  using (
    (select role from public.profiles where id = auth.uid()) = 'customer'
    and exists (
      select 1 from public.project_customers pc
      where pc.project_id = change_orders.project_id
        and pc.user_id = auth.uid()
    )
    and status = 'quoted'
  )
  with check (
    (select role from public.profiles where id = auth.uid()) = 'customer'
    and status in ('approved', 'rejected')
    and exists (
      select 1 from public.project_customers pc
      where pc.project_id = change_orders.project_id
        and pc.user_id = auth.uid()
    )
  );
