
-- Admin-initiated change order offers to customers
alter table public.change_orders add column if not exists origin text default 'customer_request';
-- values: customer_request | admin_offer

-- Allow admins to insert quoted offers with amount
-- (existing admin insert policy should already allow inserts)

-- Customers already can decide when status = quoted (change-order-quotes.sql)
