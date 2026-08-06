
-- Move tasks to phase level
alter table public.tasks add column if not exists phase_id uuid references public.phases(id) on delete cascade;
create index if not exists tasks_phase_id_idx on public.tasks(phase_id);

-- Team can no longer mark done via RLS (only update status if admin)
-- Optional: tighten update so team can only touch nothing status-related — keep team able to not update status
-- Simpler: leave app-enforced mark done; team still can update for future if needed
