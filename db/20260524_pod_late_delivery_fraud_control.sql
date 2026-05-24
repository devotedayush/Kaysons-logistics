create unique index if not exists admin_alerts_open_late_pod_freight_idx
  on public.admin_alerts (freight_id, category)
  where category = 'late_pod' and status = 'open';

drop policy if exists "transporters write own late pod alerts" on public.admin_alerts;
create policy "transporters write own late pod alerts"
on public.admin_alerts
for insert
to authenticated
with check (
  category = 'late_pod'
  and exists (
    select 1
    from public.freights f
    where f.id = admin_alerts.freight_id
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
    i.delivery_reference,
    nullif(f.delivery_stages #>> '{delivered,submitted_at}', '')::timestamptz as pod_submitted_at
  from public.freights f
  left join public.invoices i on i.freight_id = f.id
  left join public.profiles tp on tp.id = coalesce(i.transporter_id, f.winner_profile_id)
  left join charge_totals ct on ct.freight_id = f.id
  left join product_totals pt on pt.freight_id = f.id
)
select
  lr.freight_id,
  lr.invoice_id,
  lr.created_by,
  lr.company_name,
  lr.party_name,
  lr.bill_date,
  lr.dispatch_date,
  lr.delay_days,
  lr.invoice_number,
  lr.e_way_bill_number,
  lr.lr_gr_number,
  lr.origin,
  lr.town,
  lr.cases,
  lr.weight_kg,
  lr.vehicle_number,
  lr.vehicle_type,
  lr.transporter_id,
  lr.transporter_name,
  lr.freight,
  lr.extra_freight,
  lr.labour,
  lr.detention,
  lr.toll_tax,
  lr.point_charge,
  lr.out_route,
  lr.deduction,
  lr.other,
  lr.total_freight,
  lr.pmt,
  lr.ack_status,
  lr.ack_received_at,
  lr.remarks,
  lr.product_breakdown,
  lr.status,
  lr.created_at,
  lr.delivery_reference,
  date_trunc('month', coalesce(lr.bill_date, lr.created_at::date))::date as period_month,
  coalesce(s.last_month_balance, 0) as last_month_balance,
  coalesce(s.payment_amount, 0) as payment_amount,
  coalesce(s.deduction_amount, 0) as settlement_deduction,
  coalesce(s.last_month_balance, 0)
    + lr.total_freight
    - coalesce(s.payment_amount, 0)
    - coalesce(s.deduction_amount, 0) as balance,
  s.remarks as settlement_remarks,
  lr.pod_submitted_at,
  case
    when lr.dispatch_date is not null and lr.pod_submitted_at is not null
    then lr.pod_submitted_at::date - lr.dispatch_date
    else null
  end as pod_delay_days,
  case
    when lr.dispatch_date is not null and lr.pod_submitted_at is not null
    then (lr.pod_submitted_at::date - lr.dispatch_date) > 3
    else false
  end as pod_late_flag,
  case
    when lr.dispatch_date is not null and lr.pod_submitted_at is null
    then (current_date - lr.dispatch_date) > 3
    else false
  end as pod_missing_overdue_flag
from ledger_rows lr
left join public.transporter_ledger_settlements s
  on s.company_name = lr.company_name
 and s.transporter_id is not distinct from lr.transporter_id
 and s.period_month = date_trunc('month', coalesce(lr.bill_date, lr.created_at::date))::date;

create or replace view public.clawd_delay_risk_view
with (security_invoker = true)
as
select
  f.freight_id,
  f.invoice_id,
  f.transporter_id,
  f.transporter_name,
  f.route_key,
  f.company_name,
  f.bill_date,
  f.dispatch_date,
  f.delay_days as bill_to_dispatch_delay_days,
  f.last_location,
  f.last_location_age_hours,
  f.ack_status,
  f.ack_pending_days,
  f.pod_missing_flag,
  (f.delay_days > 2) as dispatch_delay_flag,
  (f.last_location_age_hours > 24) as stale_location_flag,
  (f.ack_pending_days > 7) as ack_overdue_flag,
  l.pod_submitted_at,
  l.pod_delay_days,
  l.pod_late_flag,
  l.pod_missing_overdue_flag
from public.clawd_freight_fact_view f
left join public.admin_freight_ledger_view l
  on l.freight_id = f.freight_id
 and l.invoice_id is not distinct from f.invoice_id;

create or replace view public.clawd_anomaly_candidates_view
with (security_invoker = true)
as
select
  'eway_mismatch'::text as signal_type,
  'critical'::text as severity,
  'freight'::text as entity_type,
  freight_id,
  invoice_id,
  transporter_id,
  route_key,
  company_name,
  jsonb_build_object(
    'invoice_eway_bill_number', invoice_eway_bill_number,
    'transit_eway_bill_number', transit_eway_bill_number,
    'delivered_eway_bill_number', delivered_eway_bill_number,
    'lr_gr_number', lr_gr_number,
    'transit_gr_bilty_number', transit_gr_bilty_number,
    'delivered_gr_number', delivered_gr_number
  ) as evidence,
  jsonb_build_object('total_freight', total_freight) as metrics
from public.clawd_eway_reconciliation_view
where eway_mismatch_flag or gr_lr_mismatch_flag

union all

select
  'duplicate_eway'::text,
  'critical'::text,
  'freight'::text,
  freight_id,
  invoice_id,
  transporter_id,
  route_key,
  company_name,
  jsonb_build_object('e_way_bill_number', invoice_eway_bill_number, 'duplicate_count', duplicate_eway_count),
  jsonb_build_object('total_freight', total_freight)
from public.clawd_eway_reconciliation_view
where duplicate_eway_count > 1

union all

select
  'route_cost_spike'::text,
  case when f.pmt > b.median_pmt_90d * 2 then 'critical' else 'high' end,
  'freight'::text,
  f.freight_id,
  f.invoice_id,
  f.transporter_id,
  f.route_key,
  f.company_name,
  jsonb_build_object('route_key', f.route_key, 'transporter_name', f.transporter_name),
  jsonb_build_object(
    'pmt', f.pmt,
    'route_median_pmt_90d', b.median_pmt_90d,
    'cost_vs_baseline_ratio', case when b.median_pmt_90d > 0 then f.pmt / b.median_pmt_90d else null end,
    'total_freight', f.total_freight
  )
from public.clawd_freight_fact_view f
join public.clawd_route_cost_baseline_view b
  on b.route_key = f.route_key
where f.pmt is not null
  and b.median_pmt_90d is not null
  and b.ledger_rows >= 3
  and f.pmt > b.median_pmt_90d * 1.5

union all

select
  'high_extra_charge'::text,
  case when extra_charge_ratio > 0.5 then 'high' else 'medium' end,
  'freight'::text,
  freight_id,
  invoice_id,
  transporter_id,
  route_key,
  company_name,
  jsonb_build_object('transporter_name', transporter_name),
  jsonb_build_object(
    'accepted_freight_amount', accepted_freight_amount,
    'total_freight', total_freight,
    'extra_charge_ratio', extra_charge_ratio,
    'extra_freight', extra_freight,
    'labour', labour,
    'detention', detention,
    'other', other
  )
from public.clawd_charge_risk_view
where high_extra_charge_flag

union all

select
  'proof_or_ack_delay'::text,
  case
    when pod_late_flag or pod_missing_overdue_flag or ack_overdue_flag or pod_missing_flag then 'high'
    else 'medium'
  end,
  'freight'::text,
  freight_id,
  invoice_id,
  transporter_id,
  route_key,
  company_name,
  jsonb_build_object(
    'last_location', last_location,
    'ack_status', ack_status,
    'pod_submitted_at', pod_submitted_at,
    'pod_late_flag', pod_late_flag,
    'pod_missing_overdue_flag', pod_missing_overdue_flag
  ),
  jsonb_build_object(
    'bill_to_dispatch_delay_days', bill_to_dispatch_delay_days,
    'last_location_age_hours', last_location_age_hours,
    'ack_pending_days', ack_pending_days,
    'pod_missing_flag', pod_missing_flag,
    'pod_delay_days', pod_delay_days,
    'sla_days', 3
  )
from public.clawd_delay_risk_view
where dispatch_delay_flag
   or stale_location_flag
   or ack_overdue_flag
   or pod_missing_flag
   or pod_late_flag
   or pod_missing_overdue_flag;

grant select on
  public.admin_freight_ledger_view,
  public.clawd_delay_risk_view,
  public.clawd_anomaly_candidates_view
to authenticated;
