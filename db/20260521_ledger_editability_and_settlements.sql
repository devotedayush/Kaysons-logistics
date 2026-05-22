alter table if exists public.invoices
  add column if not exists delivery_reference text;

create table if not exists public.transporter_ledger_settlements (
  id uuid primary key default gen_random_uuid(),
  company_name text not null,
  transporter_id uuid references public.profiles(id) on delete set null,
  period_month date not null,
  last_month_balance numeric not null default 0,
  payment_amount numeric not null default 0,
  deduction_amount numeric not null default 0,
  remarks text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  unique (company_name, transporter_id, period_month)
);

alter table public.transporter_ledger_settlements enable row level security;

create index if not exists transporter_ledger_settlements_lookup_idx
  on public.transporter_ledger_settlements (company_name, transporter_id, period_month);

drop policy if exists "staff manage transporter settlements" on public.transporter_ledger_settlements;
create policy "staff manage transporter settlements"
on public.transporter_ledger_settlements
for all
to authenticated
using (
  public."current_role"()::text = any (array['admin', 'accountant', 'logistics_manager'])
)
with check (
  public."current_role"()::text = any (array['admin', 'accountant', 'logistics_manager'])
);

grant select, insert, update, delete on public.transporter_ledger_settlements to authenticated;

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
),
ledger_rows as (
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
    f.created_at,
    i.delivery_reference
  from public.freights f
  left join public.invoices i on i.freight_id = f.id
  left join public.profiles tp on tp.id = coalesce(i.transporter_id, f.winner_profile_id)
  left join charge_totals ct on ct.freight_id = f.id
  left join product_totals pt on pt.freight_id = f.id
)
select
  lr.*,
  date_trunc('month', coalesce(lr.bill_date, lr.created_at::date))::date as period_month,
  coalesce(s.last_month_balance, 0) as last_month_balance,
  coalesce(s.payment_amount, 0) as payment_amount,
  coalesce(s.deduction_amount, 0) as settlement_deduction,
  coalesce(s.last_month_balance, 0)
    + lr.total_freight
    - coalesce(s.payment_amount, 0)
    - coalesce(s.deduction_amount, 0) as balance,
  s.remarks as settlement_remarks
from ledger_rows lr
left join public.transporter_ledger_settlements s
  on s.company_name = lr.company_name
 and s.transporter_id is not distinct from lr.transporter_id
 and s.period_month = date_trunc('month', coalesce(lr.bill_date, lr.created_at::date))::date;

create or replace view public.admin_company_transporter_summary_view
with (security_invoker = true)
as
select
  period_month,
  coalesce(company_name, 'Unassigned') as company_name,
  transporter_id,
  coalesce(transporter_name, 'Unassigned') as transporter_name,
  count(distinct freight_id) as freight_count,
  coalesce(sum(cases), 0) as cases,
  coalesce(sum(weight_kg), 0) as weight_kg,
  coalesce(sum(freight), 0) as freight,
  coalesce(sum(extra_freight), 0) as extra_freight,
  coalesce(sum(labour), 0) as labour,
  coalesce(sum(detention), 0) as detention,
  coalesce(sum(deduction), 0) as freight_deductions,
  coalesce(sum(total_freight), 0) as total_freight,
  max(last_month_balance) as last_month_balance,
  max(payment_amount) as payment_amount,
  max(settlement_deduction) as settlement_deduction,
  max(last_month_balance) + coalesce(sum(total_freight), 0) - max(payment_amount) - max(settlement_deduction) as balance,
  case when coalesce(sum(weight_kg), 0) > 0
    then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0)
    else null
  end as pmt,
  count(*) filter (where ack_status = 'received') as ack_received,
  count(*) filter (where ack_status <> 'received') as ack_pending
from public.admin_freight_ledger_view
group by period_month, company_name, transporter_id, transporter_name;

grant select on public.admin_company_transporter_summary_view to authenticated;
