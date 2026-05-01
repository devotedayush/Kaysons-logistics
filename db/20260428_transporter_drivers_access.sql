alter table public.drivers
  add column if not exists updated_at timestamp with time zone not null default now(),
  add column if not exists status text not null default 'active';

alter table public.drivers enable row level security;

drop policy if exists "transporters_can_read_own_drivers" on public.drivers;
create policy "transporters_can_read_own_drivers"
on public.drivers
for select
to authenticated
using (transporter_id = (select auth.uid()));

drop policy if exists "transporters_can_insert_own_drivers" on public.drivers;
create policy "transporters_can_insert_own_drivers"
on public.drivers
for insert
to authenticated
with check (transporter_id = (select auth.uid()));

drop policy if exists "transporters_can_update_own_drivers" on public.drivers;
create policy "transporters_can_update_own_drivers"
on public.drivers
for update
to authenticated
using (transporter_id = (select auth.uid()))
with check (transporter_id = (select auth.uid()));

drop policy if exists "transporters_can_delete_own_drivers" on public.drivers;
create policy "transporters_can_delete_own_drivers"
on public.drivers
for delete
to authenticated
using (transporter_id = (select auth.uid()));

grant select, insert, update, delete on public.drivers to authenticated;

create index if not exists drivers_transporter_updated_idx
  on public.drivers (transporter_id, updated_at desc);
