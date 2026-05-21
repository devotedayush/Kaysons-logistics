create table if not exists public.ai_prompt_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'general',
  template_text text not null,
  variables_schema jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create table if not exists public.ai_runs (
  id uuid primary key default gen_random_uuid(),
  run_type text not null,
  prompt_template_id uuid references public.ai_prompt_templates(id) on delete set null,
  input_facts_hash text,
  input_snapshot jsonb not null default '{}'::jsonb,
  prompt_text text not null default '',
  model text not null default '',
  output_text text not null default '',
  structured_output jsonb not null default '{}'::jsonb,
  usage jsonb not null default '{}'::jsonb,
  status text not null default 'completed',
  error text,
  requested_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone not null default now()
);

create table if not exists public.ai_reports (
  id uuid primary key default gen_random_uuid(),
  report_type text not null,
  period_start date,
  period_end date,
  summary text not null default '',
  recommendations jsonb not null default '[]'::jsonb,
  risk_score numeric not null default 0,
  ai_run_id uuid references public.ai_runs(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  unique (report_type, period_start, period_end)
);

create table if not exists public.ai_anomaly_events (
  id uuid primary key default gen_random_uuid(),
  signal_type text not null,
  severity text not null default 'medium',
  entity_type text not null default 'freight',
  freight_id uuid references public.freights(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  transporter_id uuid references public.profiles(id) on delete set null,
  route_key text,
  company_name text,
  evidence jsonb not null default '{}'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  ai_run_id uuid references public.ai_runs(id) on delete set null,
  detected_at timestamp with time zone not null default now(),
  resolved_at timestamp with time zone,
  resolved_by uuid references public.profiles(id) on delete set null,
  unique (signal_type, freight_id, invoice_id, transporter_id, route_key)
);

create index if not exists ai_prompt_templates_active_idx
  on public.ai_prompt_templates (is_active, category, created_at desc);

create index if not exists ai_runs_type_created_idx
  on public.ai_runs (run_type, created_at desc);

create index if not exists ai_reports_type_period_idx
  on public.ai_reports (report_type, period_start desc, period_end desc);

create index if not exists ai_anomaly_events_status_idx
  on public.ai_anomaly_events (status, severity, detected_at desc);

create index if not exists ai_anomaly_events_freight_idx
  on public.ai_anomaly_events (freight_id);

alter table public.ai_prompt_templates enable row level security;
alter table public.ai_runs enable row level security;
alter table public.ai_reports enable row level security;
alter table public.ai_anomaly_events enable row level security;

drop policy if exists "staff read prompt templates" on public.ai_prompt_templates;
create policy "staff read prompt templates"
on public.ai_prompt_templates
for select
to authenticated
using (public."current_role"()::text in ('admin', 'accountant'));

drop policy if exists "admins manage prompt templates" on public.ai_prompt_templates;
create policy "admins manage prompt templates"
on public.ai_prompt_templates
for all
to authenticated
using (public."current_role"()::text = 'admin')
with check (public."current_role"()::text = 'admin');

drop policy if exists "staff read ai runs" on public.ai_runs;
create policy "staff read ai runs"
on public.ai_runs
for select
to authenticated
using (public."current_role"()::text in ('admin', 'accountant'));

drop policy if exists "staff read ai reports" on public.ai_reports;
create policy "staff read ai reports"
on public.ai_reports
for select
to authenticated
using (public."current_role"()::text in ('admin', 'accountant'));

drop policy if exists "staff read ai anomalies" on public.ai_anomaly_events;
create policy "staff read ai anomalies"
on public.ai_anomaly_events
for select
to authenticated
using (public."current_role"()::text in ('admin', 'accountant'));

drop policy if exists "staff update ai anomalies" on public.ai_anomaly_events;
create policy "staff update ai anomalies"
on public.ai_anomaly_events
for update
to authenticated
using (public."current_role"()::text in ('admin', 'accountant'))
with check (public."current_role"()::text in ('admin', 'accountant'));

drop policy if exists "lm read own ai anomalies" on public.ai_anomaly_events;
create policy "lm read own ai anomalies"
on public.ai_anomaly_events
for select
to authenticated
using (
  public."current_role"()::text = 'logistics_manager'
  and exists (
    select 1
    from public.freights f
    where f.id = ai_anomaly_events.freight_id
      and f.created_by = (select auth.uid())
  )
);

grant select, insert, update, delete on public.ai_prompt_templates to authenticated;
grant select on public.ai_runs, public.ai_reports to authenticated;
grant select, update on public.ai_anomaly_events to authenticated;

insert into public.ai_prompt_templates (name, category, template_text, variables_schema)
values
  (
    'E-way bill fraud review',
    'fraud_review',
    'Analyze e-way bill risk between {{start_date}} and {{end_date}}. Explain mismatches, duplicates, missing proof, business impact, and next actions. Use only computed facts.',
    '{"start_date":"date","end_date":"date"}'::jsonb
  ),
  (
    'Route cost spike review',
    'route_cost',
    'Compare {{route_key}} costs between {{start_date}} and {{end_date}} against the historical baseline. Explain why this route became expensive and what admin should check.',
    '{"route_key":"text","start_date":"date","end_date":"date"}'::jsonb
  ),
  (
    'Transporter performance review',
    'transporter_performance',
    'Review {{transporter_name}} for cost, delay, proof, acknowledgement, and fraud-risk patterns. Explain changes and recommended action.',
    '{"transporter_name":"text"}'::jsonb
  )
on conflict do nothing;

create or replace view public.clawd_freight_fact_view
with (security_invoker = true)
as
with won_bids as (
  select distinct on (freight_id)
    freight_id,
    transporter_id,
    amount as accepted_bid_amount,
    updated_at as accepted_bid_at
  from public.bids
  where state = 'won'
  order by freight_id, updated_at desc
),
facts as (
  select
    l.*,
    lower(trim(coalesce(l.origin, 'unknown')) || '>' || trim(coalesce(l.town, 'unknown'))) as route_key,
    wb.accepted_bid_amount,
    coalesce(wb.accepted_bid_amount, l.freight, 0) as accepted_freight_amount,
    case when l.cases > 0 then l.total_freight / nullif(l.cases, 0) else null end as freight_per_case,
    case when coalesce(wb.accepted_bid_amount, l.freight, 0) > 0
      then (l.extra_freight + l.labour + l.detention + l.toll_tax + l.point_charge + l.out_route + l.other)
        / nullif(coalesce(wb.accepted_bid_amount, l.freight, 0), 0)
      else null
    end as extra_charge_ratio,
    case when l.total_freight > 0 then l.deduction / nullif(l.total_freight, 0) else null end as deduction_ratio,
    f.delivery_stages,
    f.driver_name,
    f.driver_phone,
    f.dispatched_at,
    f.locked_at,
    f.updated_at,
    f.winner_profile_id,
    f.created_by as logistics_manager_id,
    f.stop_details,
    f.stops,
    f.internal_calling_bid,
    f.delivery_stages #>> '{pickup,invoice_number}' as pickup_invoice_number,
    f.delivery_stages #>> '{in_transit,gr_bilty_number}' as transit_gr_bilty_number,
    f.delivery_stages #>> '{in_transit,e_way_bill_number}' as transit_eway_bill_number,
    f.delivery_stages #>> '{in_transit,last_location}' as last_location,
    nullif(f.delivery_stages #>> '{in_transit,location_updated_at}', '')::timestamptz as location_updated_at,
    f.delivery_stages #>> '{delivered,gr_number}' as delivered_gr_number,
    f.delivery_stages #>> '{delivered,e_way_bill_number}' as delivered_eway_bill_number,
    f.delivery_stages #>> '{delivered,pod_photo_path}' as pod_photo_path,
    f.delivery_stages #>> '{delivered,bill_reason}' as additional_bill_reason,
    f.delivery_stages #>> '{vehicle_confirmation,status}' as vehicle_confirmation_status
  from public.admin_freight_ledger_view l
  left join public.freights f on f.id = l.freight_id
  left join won_bids wb on wb.freight_id = l.freight_id
)
select
  facts.*,
  coalesce(nullif(invoice_number, ''), nullif(pickup_invoice_number, '')) is null as invoice_missing_flag,
  coalesce(nullif(e_way_bill_number, ''), nullif(transit_eway_bill_number, ''), nullif(delivered_eway_bill_number, '')) is null as eway_missing_flag,
  (
    nullif(e_way_bill_number, '') is not null
    and nullif(transit_eway_bill_number, '') is not null
    and e_way_bill_number <> transit_eway_bill_number
  )
  or (
    nullif(e_way_bill_number, '') is not null
    and nullif(delivered_eway_bill_number, '') is not null
    and e_way_bill_number <> delivered_eway_bill_number
  ) as eway_mismatch_flag,
  (
    nullif(lr_gr_number, '') is not null
    and nullif(transit_gr_bilty_number, '') is not null
    and lr_gr_number <> transit_gr_bilty_number
  )
  or (
    nullif(lr_gr_number, '') is not null
    and nullif(delivered_gr_number, '') is not null
    and lr_gr_number <> delivered_gr_number
  ) as gr_lr_mismatch_flag,
  pod_photo_path is null or pod_photo_path = '' as pod_missing_flag,
  case when location_updated_at is null then null else extract(epoch from (now() - location_updated_at)) / 3600 end as last_location_age_hours,
  case when ack_status <> 'received' and dispatch_date is not null then current_date - dispatch_date else 0 end as ack_pending_days
from facts;

create or replace view public.clawd_route_cost_baseline_view
with (security_invoker = true)
as
select
  route_key,
  coalesce(company_name, 'Unassigned') as company_name,
  transporter_id,
  coalesce(transporter_name, 'Unassigned') as transporter_name,
  count(*) as ledger_rows,
  percentile_cont(0.5) within group (order by pmt) filter (where pmt is not null) as median_pmt_90d,
  avg(pmt) filter (where pmt is not null) as avg_pmt_90d,
  min(pmt) filter (where pmt is not null) as min_pmt_90d,
  max(pmt) filter (where pmt is not null) as max_pmt_90d,
  avg(total_freight) as avg_total_freight_90d,
  sum(total_freight) as total_freight_90d
from public.clawd_freight_fact_view
where coalesce(bill_date, created_at::date) >= current_date - interval '90 days'
group by route_key, company_name, transporter_id, transporter_name;

create or replace view public.clawd_transporter_performance_view
with (security_invoker = true)
as
select
  transporter_id,
  coalesce(transporter_name, 'Unassigned') as transporter_name,
  count(distinct freight_id) as freight_count,
  sum(total_freight) as total_freight,
  avg(pmt) filter (where pmt is not null) as avg_pmt,
  count(*) filter (where eway_mismatch_flag) as eway_mismatch_count,
  count(*) filter (where eway_missing_flag) as eway_missing_count,
  count(*) filter (where pod_missing_flag and status in ('completed', 'locked')) as pod_missing_count,
  count(*) filter (where ack_status <> 'received') as ack_pending_count,
  avg(delay_days) filter (where delay_days is not null) as avg_delay_days,
  count(*) filter (where extra_charge_ratio > 0.25) as high_extra_charge_count
from public.clawd_freight_fact_view
group by transporter_id, transporter_name;

create or replace view public.clawd_eway_reconciliation_view
with (security_invoker = true)
as
select
  freight_id,
  invoice_id,
  transporter_id,
  transporter_name,
  route_key,
  company_name,
  invoice_number,
  e_way_bill_number as invoice_eway_bill_number,
  transit_eway_bill_number,
  delivered_eway_bill_number,
  lr_gr_number,
  transit_gr_bilty_number,
  delivered_gr_number,
  eway_missing_flag,
  eway_mismatch_flag,
  gr_lr_mismatch_flag,
  count(*) over (partition by nullif(e_way_bill_number, '')) as duplicate_eway_count,
  total_freight
from public.clawd_freight_fact_view
where nullif(e_way_bill_number, '') is not null
   or nullif(transit_eway_bill_number, '') is not null
   or nullif(delivered_eway_bill_number, '') is not null;

create or replace view public.clawd_charge_risk_view
with (security_invoker = true)
as
select
  freight_id,
  invoice_id,
  transporter_id,
  transporter_name,
  route_key,
  company_name,
  accepted_freight_amount,
  total_freight,
  extra_charge_ratio,
  deduction_ratio,
  extra_freight,
  labour,
  detention,
  toll_tax,
  point_charge,
  out_route,
  other,
  deduction,
  (extra_charge_ratio > 0.25) as high_extra_charge_flag,
  (detention > accepted_freight_amount * 0.2 and accepted_freight_amount > 0) as high_detention_flag,
  (labour > accepted_freight_amount * 0.2 and accepted_freight_amount > 0) as high_labour_flag
from public.clawd_freight_fact_view;

create or replace view public.clawd_delay_risk_view
with (security_invoker = true)
as
select
  freight_id,
  invoice_id,
  transporter_id,
  transporter_name,
  route_key,
  company_name,
  bill_date,
  dispatch_date,
  delay_days as bill_to_dispatch_delay_days,
  last_location,
  last_location_age_hours,
  ack_status,
  ack_pending_days,
  pod_missing_flag,
  (delay_days > 2) as dispatch_delay_flag,
  (last_location_age_hours > 24) as stale_location_flag,
  (ack_pending_days > 7) as ack_overdue_flag
from public.clawd_freight_fact_view;

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
  case when ack_overdue_flag or pod_missing_flag then 'high' else 'medium' end,
  'freight'::text,
  freight_id,
  invoice_id,
  transporter_id,
  route_key,
  company_name,
  jsonb_build_object('last_location', last_location, 'ack_status', ack_status),
  jsonb_build_object(
    'bill_to_dispatch_delay_days', bill_to_dispatch_delay_days,
    'last_location_age_hours', last_location_age_hours,
    'ack_pending_days', ack_pending_days,
    'pod_missing_flag', pod_missing_flag
  )
from public.clawd_delay_risk_view
where dispatch_delay_flag or stale_location_flag or ack_overdue_flag or pod_missing_flag;

grant select on
  public.clawd_freight_fact_view,
  public.clawd_route_cost_baseline_view,
  public.clawd_transporter_performance_view,
  public.clawd_eway_reconciliation_view,
  public.clawd_charge_risk_view,
  public.clawd_delay_risk_view,
  public.clawd_anomaly_candidates_view
to authenticated;
