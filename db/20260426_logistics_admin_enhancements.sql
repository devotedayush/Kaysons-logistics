alter table if exists public.profiles
  add column if not exists rc_number text,
  add column if not exists lorry_insurance_number text;

alter table if exists public.invoices
  add column if not exists e_way_bill_number text,
  add column if not exists verified_at timestamp with time zone default now();

create table if not exists public.admin_alerts (
  id uuid primary key default gen_random_uuid(),
  freight_id uuid references public.freights(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  category text not null,
  severity text not null default 'medium',
  title text not null,
  message text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  created_at timestamp with time zone not null default now(),
  resolved_at timestamp with time zone
);

create index if not exists admin_alerts_freight_idx
  on public.admin_alerts (freight_id);

create index if not exists admin_alerts_status_created_idx
  on public.admin_alerts (status, created_at desc);

alter table if exists public.admin_alerts enable row level security;

drop policy if exists "admins_and_lm_can_read_alerts" on public.admin_alerts;
create policy "admins_and_lm_can_read_alerts"
on public.admin_alerts
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'logistics_manager')
  )
);

drop policy if exists "admins_and_lm_can_write_alerts" on public.admin_alerts;
create policy "admins_and_lm_can_write_alerts"
on public.admin_alerts
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'logistics_manager')
  )
);

drop policy if exists "admins_can_update_alerts" on public.admin_alerts;
create policy "admins_can_update_alerts"
on public.admin_alerts
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
);
