alter table public.ai_anomaly_events
  add column if not exists business_priority_score numeric not null default 0;

create or replace function public.clawd_latest_business_period()
returns table(period_start date, period_end date)
language sql
stable
set search_path = ''
as $$
  with latest as (
    select coalesce(
      max(bill_date),
      max(dispatch_date),
      max(created_at::date),
      current_date
    ) as anchor_date
    from public.admin_freight_ledger_view
  )
  select
    date_trunc('month', anchor_date::timestamp)::date as period_start,
    (date_trunc('month', anchor_date::timestamp) + interval '1 month - 1 day')::date as period_end
  from latest;
$$;

create or replace function public.clawd_admin_snapshot(
  p_period_start date default null,
  p_period_end date default null
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  with selected_period as (
    select
      coalesce(p_period_start, latest.period_start) as period_start,
      coalesce(p_period_end, latest.period_end) as period_end
    from public.clawd_latest_business_period() latest
  ),
  ledger as (
    select
      l.*,
      coalesce(l.bill_date, l.dispatch_date, l.created_at::date) as business_date
    from public.admin_freight_ledger_view l
    cross join selected_period p
    where coalesce(l.bill_date, l.dispatch_date, l.created_at::date)
      between p.period_start and p.period_end
  ),
  totals as (
    select
      count(*)::integer as dispatches,
      coalesce(sum(cases), 0)::integer as cases,
      round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons,
      round(coalesce(sum(total_freight), 0)::numeric, 2) as freight,
      count(*) filter (where coalesce(ack_status, '') = 'received')::integer as pod_received,
      count(*) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending,
      round(
        coalesce(sum(total_freight) filter (where coalesce(ack_status, '') <> 'received'), 0)::numeric,
        2
      ) as pod_pending_value,
      round(
        coalesce(sum(total_freight) filter (
          where pod_missing_overdue_flag
             or pod_late_flag
             or coalesce(ack_status, '') <> 'received'
        ), 0)::numeric,
        2
      ) as review_value
    from ledger
  ),
  company_totals as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.freight desc), '[]'::jsonb) as data
    from (
      select
        coalesce(company_name, 'Unassigned') as company_name,
        count(*)::integer as dispatches,
        coalesce(sum(cases), 0)::integer as cases,
        round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons,
        round(coalesce(sum(total_freight), 0)::numeric, 2) as freight,
        count(*) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by coalesce(company_name, 'Unassigned')
    ) row_data
  ),
  transporter_rankings as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.freight desc), '[]'::jsonb) as data
    from (
      select
        coalesce(transporter_name, 'Unassigned') as transporter_name,
        count(*)::integer as dispatches,
        coalesce(sum(cases), 0)::integer as cases,
        round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons,
        round(coalesce(sum(total_freight), 0)::numeric, 2) as freight,
        round(
          case when coalesce(sum(weight_kg), 0) > 0
            then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0)
            else 0
          end::numeric,
          2
        ) as freight_per_mt,
        count(*) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by coalesce(transporter_name, 'Unassigned')
      order by coalesce(sum(total_freight), 0) desc
      limit 10
    ) row_data
  ),
  destination_rankings as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.dispatches desc), '[]'::jsonb) as data
    from (
      select
        coalesce(town, 'Unknown') as destination,
        count(*)::integer as dispatches,
        coalesce(sum(cases), 0)::integer as cases,
        round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons,
        round(coalesce(sum(total_freight), 0)::numeric, 2) as freight,
        count(*) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by coalesce(town, 'Unknown')
      order by count(*) desc
      limit 10
    ) row_data
  ),
  route_rankings as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.freight desc), '[]'::jsonb) as data
    from (
      select
        concat(coalesce(origin, 'Unknown'), ' -> ', coalesce(town, 'Unknown')) as route,
        count(*)::integer as dispatches,
        round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons,
        round(coalesce(sum(total_freight), 0)::numeric, 2) as freight,
        round(
          case when coalesce(sum(weight_kg), 0) > 0
            then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0)
            else 0
          end::numeric,
          2
        ) as freight_per_mt,
        count(*) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by concat(coalesce(origin, 'Unknown'), ' -> ', coalesce(town, 'Unknown'))
      order by coalesce(sum(total_freight), 0) desc
      limit 10
    ) row_data
  ),
  pod_aging as (
    select jsonb_build_object(
      'pending_total', count(*) filter (where coalesce(ack_status, '') <> 'received'),
      'old_pending', count(*) filter (
        where coalesce(ack_status, '') <> 'received'
          and dispatch_date is not null
          and current_date - dispatch_date > 3
      ),
      'by_transporter', coalesce((
        select jsonb_agg(to_jsonb(row_data) order by row_data.pending desc)
        from (
          select
            coalesce(transporter_name, 'Unassigned') as transporter_name,
            count(*)::integer as pending,
            round(coalesce(sum(total_freight), 0)::numeric, 2) as value
          from ledger
          where coalesce(ack_status, '') <> 'received'
          group by coalesce(transporter_name, 'Unassigned')
          order by count(*) desc
          limit 8
        ) row_data
      ), '[]'::jsonb),
      'by_destination', coalesce((
        select jsonb_agg(to_jsonb(row_data) order by row_data.pending desc)
        from (
          select
            coalesce(town, 'Unknown') as destination,
            count(*)::integer as pending,
            round(coalesce(sum(total_freight), 0)::numeric, 2) as value
          from ledger
          where coalesce(ack_status, '') <> 'received'
          group by coalesce(town, 'Unknown')
          order by count(*) desc
          limit 8
        ) row_data
      ), '[]'::jsonb)
    ) as data
    from ledger
  ),
  risk_summary as (
    select jsonb_build_object(
      'open_alerts', (select count(*) from public.admin_alerts where status <> 'resolved'),
      'duplicate_eway_risks', (
        select count(*)
        from public.clawd_eway_reconciliation_view e
        join ledger l
          on l.freight_id = e.freight_id
         and not l.invoice_id is distinct from e.invoice_id
        where e.duplicate_eway_count > 1
      ),
      'eway_or_gr_mismatches', (
        select count(*)
        from public.clawd_eway_reconciliation_view e
        join ledger l
          on l.freight_id = e.freight_id
         and not l.invoice_id is distinct from e.invoice_id
        where e.eway_mismatch_flag or e.gr_lr_mismatch_flag
      ),
      'high_extra_charge_risks', (
        select count(*)
        from public.clawd_charge_risk_view c
        join ledger l
          on l.freight_id = c.freight_id
         and not l.invoice_id is distinct from c.invoice_id
        where c.extra_charge_ratio > 0.75
          and (
            coalesce(c.extra_freight, 0)
            + coalesce(c.labour, 0)
            + coalesce(c.detention, 0)
            + coalesce(c.toll_tax, 0)
            + coalesce(c.point_charge, 0)
            + coalesce(c.out_route, 0)
            + coalesce(c.other, 0)
          ) >= 1000
      ),
      'route_cost_spike_risks', (
        select count(*)
        from public.clawd_freight_fact_view f
        join public.clawd_route_cost_baseline_view b on b.route_key = f.route_key
        join ledger l
          on l.freight_id = f.freight_id
         and not l.invoice_id is distinct from f.invoice_id
        where f.pmt is not null
          and b.median_pmt_90d is not null
          and b.ledger_rows >= 5
          and f.pmt::double precision > b.median_pmt_90d * 2
          and f.pmt - b.median_pmt_90d::numeric >= 500
      )
    ) as data
  ),
  trend as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.business_date), '[]'::jsonb) as data
    from (
      select
        business_date,
        round(coalesce(sum(total_freight), 0)::numeric, 2) as freight
      from ledger
      group by business_date
    ) row_data
  )
  select jsonb_build_object(
    'period', jsonb_build_object(
      'period_start', (select period_start from selected_period),
      'period_end', (select period_end from selected_period)
    ),
    'totals', (select to_jsonb(totals) from totals),
    'company_totals', (select data from company_totals),
    'transporter_rankings', (select data from transporter_rankings),
    'destination_rankings', (select data from destination_rankings),
    'route_rankings', (select data from route_rankings),
    'pod_aging', (select data from pod_aging),
    'risk_summary', (select data from risk_summary),
    'trend', (select data from trend)
  );
$$;

create or replace view public.clawd_anomaly_candidates_view as
select
  'eway_mismatch'::text as signal_type,
  'critical'::text as severity,
  'freight'::text as entity_type,
  e.freight_id,
  e.invoice_id,
  e.transporter_id,
  e.route_key,
  e.company_name,
  jsonb_build_object(
    'invoice_eway_bill_number', e.invoice_eway_bill_number,
    'transit_eway_bill_number', e.transit_eway_bill_number,
    'delivered_eway_bill_number', e.delivered_eway_bill_number,
    'lr_gr_number', e.lr_gr_number,
    'transit_gr_bilty_number', e.transit_gr_bilty_number,
    'delivered_gr_number', e.delivered_gr_number
  ) as evidence,
  jsonb_build_object('total_freight', e.total_freight) as metrics,
  95::numeric as business_priority_score
from public.clawd_eway_reconciliation_view e
where e.eway_mismatch_flag or e.gr_lr_mismatch_flag

union all

select
  'duplicate_eway'::text as signal_type,
  'critical'::text as severity,
  'freight'::text as entity_type,
  e.freight_id,
  e.invoice_id,
  e.transporter_id,
  e.route_key,
  e.company_name,
  jsonb_build_object(
    'e_way_bill_number', e.invoice_eway_bill_number,
    'duplicate_count', e.duplicate_eway_count
  ) as evidence,
  jsonb_build_object('total_freight', e.total_freight) as metrics,
  100::numeric as business_priority_score
from public.clawd_eway_reconciliation_view e
where e.duplicate_eway_count > 1

union all

select
  'route_cost_spike'::text as signal_type,
  case
    when f.pmt::double precision > b.median_pmt_90d * 2.5 then 'critical'::text
    else 'high'::text
  end as severity,
  'freight'::text as entity_type,
  f.freight_id,
  f.invoice_id,
  f.transporter_id,
  f.route_key,
  f.company_name,
  jsonb_build_object(
    'route_key', f.route_key,
    'transporter_name', f.transporter_name,
    'ledger_rows', b.ledger_rows
  ) as evidence,
  jsonb_build_object(
    'pmt', f.pmt,
    'route_median_pmt_90d', b.median_pmt_90d,
    'cost_vs_baseline_ratio',
      case when b.median_pmt_90d > 0
        then f.pmt::double precision / b.median_pmt_90d
        else null::double precision
      end,
    'total_freight', f.total_freight
  ) as metrics,
  least(
    95::numeric,
    60::numeric
      + greatest(0::numeric, f.pmt - b.median_pmt_90d::numeric) / 100
      + coalesce(f.total_freight, 0) / 10000
  ) as business_priority_score
from public.clawd_freight_fact_view f
join public.clawd_route_cost_baseline_view b on b.route_key = f.route_key
where f.pmt is not null
  and b.median_pmt_90d is not null
  and b.ledger_rows >= 5
  and f.pmt::double precision > b.median_pmt_90d * 2
  and f.pmt - b.median_pmt_90d::numeric >= 500

union all

select
  'high_extra_charge'::text as signal_type,
  case
    when c.extra_charge_ratio > 1 then 'high'::text
    else 'medium'::text
  end as severity,
  'freight'::text as entity_type,
  c.freight_id,
  c.invoice_id,
  c.transporter_id,
  c.route_key,
  c.company_name,
  jsonb_build_object('transporter_name', c.transporter_name) as evidence,
  jsonb_build_object(
    'accepted_freight_amount', c.accepted_freight_amount,
    'total_freight', c.total_freight,
    'extra_charge_ratio', c.extra_charge_ratio,
    'extra_freight', c.extra_freight,
    'labour', c.labour,
    'detention', c.detention,
    'other', c.other
  ) as metrics,
  least(
    90::numeric,
    50::numeric
      + c.extra_charge_ratio * 20
      + (
        coalesce(c.extra_freight, 0)
        + coalesce(c.labour, 0)
        + coalesce(c.detention, 0)
        + coalesce(c.toll_tax, 0)
        + coalesce(c.point_charge, 0)
        + coalesce(c.out_route, 0)
        + coalesce(c.other, 0)
      ) / 1000
  ) as business_priority_score
from public.clawd_charge_risk_view c
where c.extra_charge_ratio > 0.75
  and (
    coalesce(c.extra_freight, 0)
    + coalesce(c.labour, 0)
    + coalesce(c.detention, 0)
    + coalesce(c.toll_tax, 0)
    + coalesce(c.point_charge, 0)
    + coalesce(c.out_route, 0)
    + coalesce(c.other, 0)
  ) >= 1000

union all

select
  'proof_or_ack_delay'::text as signal_type,
  case
    when l.dispatch_date is not null and current_date - l.dispatch_date > 10 then 'high'::text
    else 'medium'::text
  end as severity,
  'freight'::text as entity_type,
  l.freight_id,
  l.invoice_id,
  l.transporter_id,
  concat(coalesce(l.origin, 'Unknown'), ' -> ', coalesce(l.town, 'Unknown')) as route_key,
  l.company_name,
  jsonb_build_object(
    'transporter_name', l.transporter_name,
    'ack_status', l.ack_status,
    'dispatch_date', l.dispatch_date,
    'pod_received_date', l.pod_received_date
  ) as evidence,
  jsonb_build_object(
    'pod_pending_days', greatest(0, coalesce(current_date - l.dispatch_date, 0)),
    'total_freight', l.total_freight,
    'sla_days', 3
  ) as metrics,
  least(
    85::numeric,
    45::numeric
      + greatest(0, coalesce(current_date - l.dispatch_date, 0)) * 2
      + coalesce(l.total_freight, 0) / 10000
  ) as business_priority_score
from public.admin_freight_ledger_view l
where coalesce(l.ack_status, '') <> 'received'
  and l.dispatch_date is not null
  and current_date - l.dispatch_date > 3;
