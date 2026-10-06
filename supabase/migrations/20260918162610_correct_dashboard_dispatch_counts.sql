-- Count dispatch identities, while summing invoice-level money and quantities.
CREATE OR REPLACE FUNCTION public.clawd_admin_snapshot(p_period_start date DEFAULT NULL::date, p_period_end date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
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
      count(distinct freight_id)::integer as dispatches,
      coalesce(sum(cases), 0)::integer as cases,
      round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons,
      round(coalesce(sum(total_freight), 0)::numeric, 2) as freight,
      count(distinct freight_id) filter (where coalesce(ack_status, '') = 'received')::integer as pod_received,
      count(distinct freight_id) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending,
      round(coalesce(sum(total_freight) filter (where coalesce(ack_status, '') <> 'received'), 0)::numeric, 2) as pod_pending_value,
      round(coalesce(sum(total_freight) filter (where pod_missing_overdue_flag or pod_late_flag or coalesce(ack_status, '') <> 'received'), 0)::numeric, 2) as review_value
    from ledger
  ),
  company_totals as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.freight desc), '[]'::jsonb) as data
    from (
      select coalesce(company_name, 'Unassigned') as company_name, count(distinct freight_id)::integer as dispatches, coalesce(sum(cases), 0)::integer as cases, round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons, round(coalesce(sum(total_freight), 0)::numeric, 2) as freight, count(distinct freight_id) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by coalesce(company_name, 'Unassigned')
    ) row_data
  ),
  transporter_rankings as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.freight desc), '[]'::jsonb) as data
    from (
      select coalesce(transporter_name, 'Unassigned') as transporter_name, count(distinct freight_id)::integer as dispatches, coalesce(sum(cases), 0)::integer as cases, round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons, round(coalesce(sum(total_freight), 0)::numeric, 2) as freight, round(case when coalesce(sum(weight_kg), 0) > 0 then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0) else 0 end::numeric, 2) as freight_per_mt, count(distinct freight_id) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by coalesce(transporter_name, 'Unassigned')
      order by coalesce(sum(total_freight), 0) desc
      limit 10
    ) row_data
  ),
  destination_rankings as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.dispatches desc), '[]'::jsonb) as data
    from (
      select coalesce(town, 'Unknown') as destination, count(distinct freight_id)::integer as dispatches, coalesce(sum(cases), 0)::integer as cases, round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons, round(coalesce(sum(total_freight), 0)::numeric, 2) as freight, count(distinct freight_id) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by coalesce(town, 'Unknown')
      order by count(distinct freight_id) desc
      limit 10
    ) row_data
  ),
  route_rankings as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.freight desc), '[]'::jsonb) as data
    from (
      select concat(coalesce(origin, 'Unknown'), ' -> ', coalesce(town, 'Unknown')) as route, count(distinct freight_id)::integer as dispatches, round(coalesce(sum(weight_kg), 0)::numeric, 3) as metric_tons, round(coalesce(sum(total_freight), 0)::numeric, 2) as freight, round(case when coalesce(sum(weight_kg), 0) > 0 then coalesce(sum(total_freight), 0) / coalesce(sum(weight_kg), 0) else 0 end::numeric, 2) as freight_per_mt, count(distinct freight_id) filter (where coalesce(ack_status, '') <> 'received')::integer as pod_pending
      from ledger
      group by concat(coalesce(origin, 'Unknown'), ' -> ', coalesce(town, 'Unknown'))
      order by coalesce(sum(total_freight), 0) desc
      limit 10
    ) row_data
  ),
  pod_aging as (
    select jsonb_build_object(
      'pending_total', count(distinct freight_id) filter (where coalesce(ack_status, '') <> 'received'),
      'old_pending', count(distinct freight_id) filter (where coalesce(ack_status, '') <> 'received' and dispatch_date is not null and current_date - dispatch_date > 3),
      'by_transporter', coalesce((select jsonb_agg(to_jsonb(row_data) order by row_data.pending desc) from (select coalesce(transporter_name, 'Unassigned') as transporter_name, count(distinct freight_id)::integer as pending, round(coalesce(sum(total_freight), 0)::numeric, 2) as value from ledger where coalesce(ack_status, '') <> 'received' group by coalesce(transporter_name, 'Unassigned') order by count(distinct freight_id) desc limit 8) row_data), '[]'::jsonb),
      'by_destination', coalesce((select jsonb_agg(to_jsonb(row_data) order by row_data.pending desc) from (select coalesce(town, 'Unknown') as destination, count(distinct freight_id)::integer as pending, round(coalesce(sum(total_freight), 0)::numeric, 2) as value from ledger where coalesce(ack_status, '') <> 'received' group by coalesce(town, 'Unknown') order by count(distinct freight_id) desc limit 8) row_data), '[]'::jsonb)
    ) as data
    from ledger
  ),
  risk_summary as (
    select jsonb_build_object(
      'open_alerts', (select count(*) from public.admin_alerts where status <> 'resolved'),
      'duplicate_eway_risks', (select count(*) from public.clawd_eway_reconciliation_view e join ledger l on l.freight_id = e.freight_id and not l.invoice_id is distinct from e.invoice_id where e.duplicate_eway_count > 1),
      'eway_or_gr_mismatches', (select count(*) from public.clawd_eway_reconciliation_view e join ledger l on l.freight_id = e.freight_id and not l.invoice_id is distinct from e.invoice_id where e.eway_mismatch_flag or e.gr_lr_mismatch_flag),
      'high_extra_charge_risks', (select count(*) from public.clawd_charge_risk_view c join ledger l on l.freight_id = c.freight_id and not l.invoice_id is distinct from c.invoice_id where c.extra_charge_ratio > 0.75 and (coalesce(c.extra_freight, 0) + coalesce(c.labour, 0) + coalesce(c.detention, 0) + coalesce(c.toll_tax, 0) + coalesce(c.point_charge, 0) + coalesce(c.out_route, 0) + coalesce(c.other, 0)) >= 1000),
      'route_cost_spike_risks', (select count(*) from public.clawd_freight_fact_view f join public.clawd_route_cost_baseline_view b on b.route_key = f.route_key join ledger l on l.freight_id = f.freight_id and not l.invoice_id is distinct from f.invoice_id where f.pmt is not null and b.median_pmt_90d is not null and b.ledger_rows >= 5 and f.pmt::double precision > b.median_pmt_90d * 2 and f.pmt - b.median_pmt_90d::numeric >= 500)
    ) as data
  ),
  trend as (
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.business_date), '[]'::jsonb) as data
    from (select business_date, round(coalesce(sum(total_freight), 0)::numeric, 2) as freight from ledger group by business_date) row_data
  )
  select jsonb_build_object('period', jsonb_build_object('period_start', (select period_start from selected_period), 'period_end', (select period_end from selected_period)), 'totals', (select to_jsonb(totals) from totals), 'company_totals', (select data from company_totals), 'transporter_rankings', (select data from transporter_rankings), 'destination_rankings', (select data from destination_rankings), 'route_rankings', (select data from route_rankings), 'pod_aging', (select data from pod_aging), 'risk_summary', (select data from risk_summary), 'trend', (select data from trend));
$function$

