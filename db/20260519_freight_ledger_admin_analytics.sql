alter table if exists public.freights
  add column if not exists company_name text,
  add column if not exists party_name text,
  add column if not exists bill_date date,
  add column if not exists dispatch_date date,
  add column if not exists vehicle_type text,
  add column if not exists source_branch text,
  add column if not exists ack_status text not null default 'pending',
  add column if not exists ack_received_at timestamp with time zone;

alter table if exists public.invoices
  add column if not exists party_name text,
  add column if not exists bill_date date,
  add column if not exists dispatch_date date,
  add column if not exists lr_number text,
  add column if not exists vehicle_number text,
  add column if not exists vehicle_type text,
  add column if not exists remarks text;

alter table if exists public.freight_charges
  add column if not exists invoice_id uuid references public.invoices(id) on delete cascade;

create table if not exists public.freight_product_lines (
  id uuid primary key default gen_random_uuid(),
  freight_id uuid not null references public.freights(id) on delete cascade,
  product_name text not null,
  quantity numeric not null default 0,
  created_at timestamp with time zone not null default now()
);

alter table if exists public.freight_product_lines enable row level security;

create index if not exists freights_company_bill_date_idx
  on public.freights (company_name, bill_date desc);

create index if not exists freights_ack_status_idx
  on public.freights (ack_status);

create index if not exists invoices_freight_bill_idx
  on public.invoices (freight_id, bill_date);

create index if not exists freight_charges_invoice_idx
  on public.freight_charges (invoice_id);

create index if not exists freight_product_lines_freight_idx
  on public.freight_product_lines (freight_id);

drop policy if exists "product lines staff all" on public.freight_product_lines;
create policy "product lines staff all"
on public.freight_product_lines
for all
to authenticated
using (
  public."current_role"()::text = any (array['admin', 'logistics_manager', 'accountant'])
)
with check (
  public."current_role"()::text = any (array['admin', 'logistics_manager', 'accountant'])
);

drop policy if exists "product lines transporter read own" on public.freight_product_lines;
create policy "product lines transporter read own"
on public.freight_product_lines
for select
to authenticated
using (
  exists (
    select 1
    from public.freights f
    where f.id = freight_product_lines.freight_id
      and f.winner_profile_id = (select auth.uid())
  )
);

create or replace view public.admin_freight_ledger_view
with (security_invoker = true)
as
with charge_totals as (
  select
    freight_id,
    sum(amount) filter (where kind = 'freight') as freight_amount,
    sum(amount) filter (where kind = 'extra_freight') as extra_freight,
    sum(amount) filter (where kind = 'labour') as labour,
    sum(amount) filter (where kind = 'detention') as detention,
    sum(amount) filter (where kind = 'toll_tax') as toll_tax,
    sum(amount) filter (where kind = 'point_charge') as point_charge,
    sum(amount) filter (where kind = 'out_route') as out_route,
    sum(amount) filter (where kind = 'deduction') as deduction,
    sum(amount) filter (where kind = 'other') as other,
    coalesce(sum(case when kind = 'deduction' then -amount else amount end), 0) as charges_total
  from public.freight_charges
  group by freight_id
),
product_totals as (
  select
    freight_id,
    string_agg(product_name || ':' || quantity::text, ', ' order by product_name) as product_breakdown
  from public.freight_product_lines
  group by freight_id
)
select
  f.id as freight_id,
  i.id as invoice_id,
  f.created_by,
  f.company_name,
  coalesce(i.party_name, f.party_name) as party_name,
  coalesce(i.bill_date, f.bill_date) as bill_date,
  coalesce(i.dispatch_date, f.dispatch_date, f.dispatched_at::date) as dispatch_date,
  case
    when coalesce(i.bill_date, f.bill_date) is not null
     and coalesce(i.dispatch_date, f.dispatch_date, f.dispatched_at::date) is not null
    then coalesce(i.dispatch_date, f.dispatch_date, f.dispatched_at::date) - coalesce(i.bill_date, f.bill_date)
    else null
  end as delay_days,
  i.invoice_number,
  i.e_way_bill_number,
  coalesce(i.lr_number, i.gr_number) as lr_gr_number,
  f.origin,
  coalesce(i.town, f.destination_town) as town,
  coalesce(i.cases, f.cases, 0) as cases,
  coalesce(i.weight_kg, f.weight_kg, 0) as weight_kg,
  coalesce(i.vehicle_number, f.vehicle_number) as vehicle_number,
  coalesce(i.vehicle_type, f.vehicle_type) as vehicle_type,
  coalesce(i.transporter_id, f.winner_profile_id) as transporter_id,
  coalesce(tp.business_name, tp.full_name, tp.email) as transporter_name,
  coalesce(i.base_freight, ct.freight_amount, f.internal_calling_bid, 0) as freight,
  coalesce(ct.extra_freight, 0) as extra_freight,
  coalesce(ct.labour, 0) as labour,
  coalesce(ct.detention, 0) as detention,
  coalesce(ct.toll_tax, 0) as toll_tax,
  coalesce(ct.point_charge, 0) as point_charge,
  coalesce(ct.out_route, 0) as out_route,
  coalesce(ct.deduction, 0) as deduction,
  coalesce(ct.other, 0) as other,
  coalesce(i.base_freight, ct.freight_amount, f.internal_calling_bid, 0)
    + coalesce(ct.extra_freight, 0)
    + coalesce(ct.labour, 0)
    + coalesce(ct.detention, 0)
    + coalesce(ct.toll_tax, 0)
    + coalesce(ct.point_charge, 0)
    + coalesce(ct.out_route, 0)
    + coalesce(ct.other, 0)
    - coalesce(ct.deduction, 0) as total_freight,
  case
    when coalesce(i.weight_kg, f.weight_kg, 0) > 0
    then (
      coalesce(i.base_freight, ct.freight_amount, f.internal_calling_bid, 0)
      + coalesce(ct.extra_freight, 0)
      + coalesce(ct.labour, 0)
      + coalesce(ct.detention, 0)
      + coalesce(ct.toll_tax, 0)
      + coalesce(ct.point_charge, 0)
      + coalesce(ct.out_route, 0)
      + coalesce(ct.other, 0)
      - coalesce(ct.deduction, 0)
    ) / coalesce(i.weight_kg, f.weight_kg, 0)
    else null
  end as pmt,
  f.ack_status,
  f.ack_received_at,
  coalesce(i.remarks, f.remarks) as remarks,
  pt.product_breakdown,
  f.status,
  f.created_at
from public.freights f
left join public.invoices i on i.freight_id = f.id
left join public.profiles tp on tp.id = coalesce(i.transporter_id, f.winner_profile_id)
left join charge_totals ct on ct.freight_id = f.id
left join product_totals pt on pt.freight_id = f.id;

create or replace view public.admin_transporter_summary_view
with (security_invoker = true)
as
select
  transporter_id,
  coalesce(transporter_name, 'Unassigned') as transporter_name,
  count(distinct freight_id) as freight_count,
  coalesce(sum(cases), 0) as cases,
  coalesce(sum(weight_kg), 0) as weight_kg,
  coalesce(sum(freight), 0) as freight,
  coalesce(sum(extra_freight), 0) as extra_freight,
  coalesce(sum(labour), 0) as labour,
  coalesce(sum(detention), 0) as detention,
  coalesce(sum(deduction), 0) as deduction,
  coalesce(sum(total_freight), 0) as total_freight,
  case when coalesce(sum(weight_kg), 0) > 0
    then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0)
    else null
  end as pmt,
  count(*) filter (where ack_status = 'received') as ack_received,
  count(*) filter (where ack_status <> 'received') as ack_pending
from public.admin_freight_ledger_view
group by transporter_id, transporter_name;

create or replace view public.admin_company_summary_view
with (security_invoker = true)
as
select
  coalesce(company_name, 'Unassigned') as company_name,
  count(distinct freight_id) as freight_count,
  coalesce(sum(cases), 0) as cases,
  coalesce(sum(weight_kg), 0) as weight_kg,
  coalesce(sum(total_freight), 0) as total_freight,
  case when coalesce(sum(weight_kg), 0) > 0
    then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0)
    else null
  end as pmt,
  count(*) filter (where ack_status = 'received') as ack_received,
  count(*) filter (where ack_status <> 'received') as ack_pending
from public.admin_freight_ledger_view
group by company_name;

create or replace view public.admin_town_summary_view
with (security_invoker = true)
as
select
  coalesce(town, 'Unknown') as town,
  count(distinct vehicle_number) filter (where vehicle_number is not null and vehicle_number <> '') as vehicle_count,
  count(distinct freight_id) as freight_count,
  coalesce(sum(weight_kg), 0) as weight_kg,
  coalesce(sum(total_freight), 0) as total_freight,
  coalesce(sum(extra_freight), 0) as extra_freight,
  case when coalesce(sum(weight_kg), 0) > 0
    then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0)
    else null
  end as pmt
from public.admin_freight_ledger_view
group by town;

create or replace view public.admin_ack_summary_view
with (security_invoker = true)
as
select
  ack_status,
  count(*) as row_count,
  count(distinct freight_id) as freight_count,
  coalesce(sum(total_freight), 0) as total_freight
from public.admin_freight_ledger_view
group by ack_status;

grant select on
  public.admin_freight_ledger_view,
  public.admin_transporter_summary_view,
  public.admin_company_summary_view,
  public.admin_town_summary_view,
  public.admin_ack_summary_view
to authenticated;

grant select, insert, update, delete on public.freight_product_lines to authenticated;
