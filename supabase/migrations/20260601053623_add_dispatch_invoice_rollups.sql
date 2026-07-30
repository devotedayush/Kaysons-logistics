alter table public.freights
  add column if not exists gr_bilty_number text;

alter table public.invoices
  add column if not exists freight_share numeric;

update public.invoices
set freight_share = base_freight
where freight_share is null
  and base_freight is not null;

update public.freights f
set gr_bilty_number = invoice_refs.lr_gr_number
from (
  select
    freight_id,
    min(coalesce(nullif(lr_number, ''), nullif(gr_number, ''))) as lr_gr_number
  from public.invoices
  where coalesce(nullif(lr_number, ''), nullif(gr_number, '')) is not null
  group by freight_id
) invoice_refs
where f.id = invoice_refs.freight_id
  and f.gr_bilty_number is null;

create or replace view public.admin_freight_ledger_view as
with charge_totals as (
  select
    freight_charges.freight_id,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'freight') as freight_amount,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'extra_freight') as extra_freight,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'labour') as labour,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'detention') as detention,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'toll_tax') as toll_tax,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'point_charge') as point_charge,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'out_route') as out_route,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'deduction') as deduction,
    sum(freight_charges.amount) filter (where freight_charges.kind = 'other') as other,
    coalesce(
      sum(
        case
          when freight_charges.kind = 'deduction' then -freight_charges.amount
          else freight_charges.amount
        end
      ),
      0::numeric
    ) as charges_total
  from public.freight_charges
  group by freight_charges.freight_id
),
product_totals as (
  select
    freight_product_lines.freight_id,
    string_agg(
      freight_product_lines.product_name || ':' || freight_product_lines.quantity::text,
      ', '
      order by freight_product_lines.product_name
    ) as product_breakdown
  from public.freight_product_lines
  group by freight_product_lines.freight_id
),
invoice_rollups as (
  select
    invoices.freight_id,
    count(*)::integer as invoice_count,
    count(distinct nullif(invoices.e_way_bill_number, ''))::integer as e_way_bill_count,
    count(distinct nullif(invoices.party_name, ''))::integer as party_count,
    string_agg(distinct nullif(invoices.invoice_number, ''), ', ' order by nullif(invoices.invoice_number, '')) as invoice_numbers,
    string_agg(distinct nullif(invoices.e_way_bill_number, ''), ', ' order by nullif(invoices.e_way_bill_number, '')) as e_way_bill_numbers,
    string_agg(distinct nullif(invoices.party_name, ''), ', ' order by nullif(invoices.party_name, '')) as party_names
  from public.invoices
  group by invoices.freight_id
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
      then coalesce(i.dispatch_date, f.dispatch_date, f.dispatched_at::date)
        - coalesce(i.bill_date, f.bill_date)
      else null::integer
    end as delay_days,
    i.invoice_number,
    i.e_way_bill_number,
    coalesce(i.lr_number, i.gr_number) as lr_gr_number,
    f.origin,
    coalesce(i.town, f.destination_town) as town,
    coalesce(i.cases, f.cases, 0) as cases,
    coalesce(i.weight_kg, f.weight_kg, 0::numeric) as weight_kg,
    coalesce(i.vehicle_number, f.vehicle_number) as vehicle_number,
    coalesce(i.vehicle_type, f.vehicle_type) as vehicle_type,
    coalesce(
      f.vehicle_capacity_category,
      public.vehicle_capacity_category_for_weight(coalesce(i.weight_kg, f.weight_kg, 0::numeric))
    ) as vehicle_capacity_category,
    coalesce(i.transporter_id, f.winner_profile_id) as transporter_id,
    coalesce(tp.business_name, tp.full_name, tp.email) as transporter_name,
    coalesce(i.freight_share, i.base_freight, ct.freight_amount, f.internal_calling_bid, 0::numeric) as freight,
    coalesce(ct.extra_freight, 0::numeric) as extra_freight,
    coalesce(ct.labour, 0::numeric) as labour,
    coalesce(ct.detention, 0::numeric) as detention,
    coalesce(ct.toll_tax, 0::numeric) as toll_tax,
    coalesce(ct.point_charge, 0::numeric) as point_charge,
    coalesce(ct.out_route, 0::numeric) as out_route,
    coalesce(ct.deduction, 0::numeric) as deduction,
    coalesce(ct.other, 0::numeric) as other,
    coalesce(i.freight_share, i.base_freight, ct.freight_amount, f.internal_calling_bid, 0::numeric)
      + coalesce(ct.extra_freight, 0::numeric)
      + coalesce(ct.labour, 0::numeric)
      + coalesce(ct.detention, 0::numeric)
      + coalesce(ct.toll_tax, 0::numeric)
      + coalesce(ct.point_charge, 0::numeric)
      + coalesce(ct.out_route, 0::numeric)
      + coalesce(ct.other, 0::numeric)
      - coalesce(ct.deduction, 0::numeric) as total_freight,
    case
      when coalesce(i.weight_kg, f.weight_kg, 0::numeric) > 0::numeric
      then (
        coalesce(i.freight_share, i.base_freight, ct.freight_amount, f.internal_calling_bid, 0::numeric)
          + coalesce(ct.extra_freight, 0::numeric)
          + coalesce(ct.labour, 0::numeric)
          + coalesce(ct.detention, 0::numeric)
          + coalesce(ct.toll_tax, 0::numeric)
          + coalesce(ct.point_charge, 0::numeric)
          + coalesce(ct.out_route, 0::numeric)
          + coalesce(ct.other, 0::numeric)
          - coalesce(ct.deduction, 0::numeric)
      ) / coalesce(i.weight_kg, f.weight_kg, 0::numeric)
      else null::numeric
    end as pmt,
    f.ack_status,
    f.ack_received_at,
    f.pod_received_date,
    f.pod_file_path,
    f.pod_remark,
    f.pod_received_by,
    coalesce(pr.full_name, pr.business_name, pr.email) as pod_received_by_name,
    coalesce(i.remarks, f.remarks) as remarks,
    pt.product_breakdown,
    f.status,
    f.created_at,
    i.delivery_reference,
    nullif(f.delivery_stages #>> '{delivered,submitted_at}'::text[], '')::timestamp with time zone as pod_submitted_at,
    f.gr_bilty_number,
    coalesce(f.gr_bilty_number, i.lr_number, i.gr_number) as dispatch_gr_bilty_number,
    i.freight_share
  from public.freights f
  left join public.invoices i on i.freight_id = f.id
  left join public.profiles tp on tp.id = coalesce(i.transporter_id, f.winner_profile_id)
  left join public.profiles pr on pr.id = f.pod_received_by
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
  date_trunc('month', coalesce(lr.bill_date, lr.created_at::date)::timestamp with time zone)::date as period_month,
  coalesce(s.last_month_balance, 0::numeric) as last_month_balance,
  coalesce(s.payment_amount, 0::numeric) as payment_amount,
  coalesce(s.deduction_amount, 0::numeric) as settlement_deduction,
  coalesce(s.last_month_balance, 0::numeric)
    + lr.total_freight
    - coalesce(s.payment_amount, 0::numeric)
    - coalesce(s.deduction_amount, 0::numeric) as balance,
  s.remarks as settlement_remarks,
  lr.pod_submitted_at,
  case
    when lr.dispatch_date is not null and lr.pod_submitted_at is not null
    then lr.pod_submitted_at::date - lr.dispatch_date
    else null::integer
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
  end as pod_missing_overdue_flag,
  lr.vehicle_capacity_category,
  lr.pod_received_date,
  lr.pod_file_path,
  lr.pod_remark,
  lr.pod_received_by,
  lr.pod_received_by_name,
  lr.gr_bilty_number,
  lr.dispatch_gr_bilty_number,
  lr.freight_share,
  coalesce(ir.invoice_count, 0) as invoice_count,
  coalesce(ir.e_way_bill_count, 0) as e_way_bill_count,
  coalesce(ir.party_count, 0) as party_count,
  ir.invoice_numbers,
  ir.e_way_bill_numbers,
  ir.party_names
from ledger_rows lr
left join invoice_rollups ir on ir.freight_id = lr.freight_id
left join public.transporter_ledger_settlements s
  on s.company_name = lr.company_name
  and not s.transporter_id is distinct from lr.transporter_id
  and s.period_month = date_trunc('month', coalesce(lr.bill_date, lr.created_at::date)::timestamp with time zone)::date;
