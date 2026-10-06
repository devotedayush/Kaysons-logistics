-- Retain the public view column contract and RLS while correcting invoice accounting.
alter table public.freights add column if not exists accepted_freight_amount numeric;
comment on column public.freights.weight_kg is 'Legacy column name: values are metric tons (MT), not kilograms.';
comment on column public.invoices.weight_kg is 'Legacy column name: values are metric tons (MT), not kilograms.';
create or replace view public.admin_freight_ledger_view with (security_invoker=true) as
 WITH charge_totals AS (
         SELECT freight_charges.freight_id,
            coalesce(freight_charges.invoice_id, (select id from public.invoices ci where ci.freight_id=freight_charges.freight_id order by ci.created_at,ci.id limit 1)) as allocated_invoice_id,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind = 'freight'::text) AS freight_amount,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind = 'extra_freight'::text) AS extra_freight,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind = 'labour'::text) AS labour,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind = 'detention'::text) AS detention,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind in ('toll_tax','toll')) AS toll_tax,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind in ('point_charge','club','dalla')) AS point_charge,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind = 'out_route'::text) AS out_route,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind = 'deduction'::text) AS deduction,
            sum(freight_charges.amount) FILTER (WHERE freight_charges.kind = 'other'::text) AS other,
            COALESCE(sum(
                CASE
                    WHEN freight_charges.kind = 'deduction'::text THEN - freight_charges.amount
                    ELSE freight_charges.amount
                END), 0::numeric) AS charges_total
           FROM freight_charges
          GROUP BY freight_charges.freight_id, allocated_invoice_id
        ), product_totals AS (
         SELECT freight_product_lines.freight_id,
            string_agg((freight_product_lines.product_name || ':'::text) || freight_product_lines.quantity::text, ', '::text ORDER BY freight_product_lines.product_name) AS product_breakdown
           FROM freight_product_lines
          GROUP BY freight_product_lines.freight_id
        ), invoice_rollups AS (
         SELECT invoices.freight_id,
            count(*)::integer AS invoice_count,
            count(DISTINCT NULLIF(invoices.e_way_bill_number, ''::text))::integer AS e_way_bill_count,
            count(DISTINCT NULLIF(invoices.party_name, ''::text))::integer AS party_count,
            string_agg(DISTINCT NULLIF(invoices.invoice_number, ''::text), ', '::text ORDER BY (NULLIF(invoices.invoice_number, ''::text))) AS invoice_numbers,
            string_agg(DISTINCT NULLIF(invoices.e_way_bill_number, ''::text), ', '::text ORDER BY (NULLIF(invoices.e_way_bill_number, ''::text))) AS e_way_bill_numbers,
            string_agg(DISTINCT NULLIF(invoices.party_name, ''::text), ', '::text ORDER BY (NULLIF(invoices.party_name, ''::text))) AS party_names
           FROM invoices
          GROUP BY invoices.freight_id
        ), ledger_rows AS (
         SELECT f.id AS freight_id,
            i.id AS invoice_id,
            f.created_by,
            f.company_name,
            COALESCE(i.party_name, f.party_name) AS party_name,
            COALESCE(i.bill_date, f.bill_date) AS bill_date,
            COALESCE(i.dispatch_date, f.dispatch_date, f.dispatched_at::date) AS dispatch_date,
                CASE
                    WHEN COALESCE(i.bill_date, f.bill_date) IS NOT NULL AND COALESCE(i.dispatch_date, f.dispatch_date, f.dispatched_at::date) IS NOT NULL THEN COALESCE(i.dispatch_date, f.dispatch_date, f.dispatched_at::date) - COALESCE(i.bill_date, f.bill_date)
                    ELSE NULL::integer
                END AS delay_days,
            i.invoice_number,
            i.e_way_bill_number,
            COALESCE(i.lr_number, i.gr_number) AS lr_gr_number,
            f.origin,
            COALESCE(i.town, f.destination_town) AS town,
            COALESCE(i.cases, case when i.id is null then f.cases when i.missing_cases_rank=1 then greatest(f.cases-i.known_cases,0)::integer else 0 end, 0) AS cases,
            COALESCE(i.weight_kg, case when i.id is null then f.weight_kg when i.missing_weight_rank=1 then greatest(f.weight_kg-i.known_weight,0) else 0 end, 0::numeric) AS weight_kg,
            COALESCE(i.vehicle_number, f.vehicle_number) AS vehicle_number,
            COALESCE(i.vehicle_type, f.vehicle_type) AS vehicle_type,
            COALESCE(f.vehicle_capacity_category, vehicle_capacity_category_for_weight(COALESCE(i.weight_kg, case when i.id is null then f.weight_kg when i.missing_weight_rank=1 then greatest(f.weight_kg-i.known_weight,0) else 0 end, 0::numeric))) AS vehicle_capacity_category,
            COALESCE(i.transporter_id, f.winner_profile_id) AS transporter_id,
            COALESCE(tp.business_name, tp.full_name, tp.email) AS transporter_name,
            COALESCE(i.freight_share, case when f.record_origin='live' then allocation.accepted_share end, i.base_freight, ct.freight_amount, case when i.id is null or i.invoice_rank=1 then f.internal_calling_bid end, 0::numeric) AS freight,
            COALESCE(ct.extra_freight, 0::numeric) AS extra_freight,
            COALESCE(ct.labour, 0::numeric) AS labour,
            COALESCE(ct.detention, 0::numeric) AS detention,
            COALESCE(ct.toll_tax, 0::numeric) AS toll_tax,
            COALESCE(ct.point_charge, 0::numeric) AS point_charge,
            COALESCE(ct.out_route, 0::numeric) AS out_route,
            COALESCE(ct.deduction, 0::numeric) AS deduction,
            COALESCE(ct.other, 0::numeric) AS other,
            COALESCE(i.freight_share, case when f.record_origin='live' then allocation.accepted_share end, i.base_freight, ct.freight_amount, case when i.id is null or i.invoice_rank=1 then f.internal_calling_bid end, 0::numeric) + COALESCE(ct.extra_freight, 0::numeric) + COALESCE(ct.labour, 0::numeric) + COALESCE(ct.detention, 0::numeric) + COALESCE(ct.toll_tax, 0::numeric) + COALESCE(ct.point_charge, 0::numeric) + COALESCE(ct.out_route, 0::numeric) + COALESCE(ct.other, 0::numeric) - COALESCE(ct.deduction, 0::numeric) AS total_freight,
                CASE
                    WHEN COALESCE(i.weight_kg, case when i.id is null then f.weight_kg when i.missing_weight_rank=1 then greatest(f.weight_kg-i.known_weight,0) else 0 end, 0::numeric) > 0::numeric THEN (COALESCE(i.freight_share, case when f.record_origin='live' then allocation.accepted_share end, i.base_freight, ct.freight_amount, case when i.id is null or i.invoice_rank=1 then f.internal_calling_bid end, 0::numeric) + COALESCE(ct.extra_freight, 0::numeric) + COALESCE(ct.labour, 0::numeric) + COALESCE(ct.detention, 0::numeric) + COALESCE(ct.toll_tax, 0::numeric) + COALESCE(ct.point_charge, 0::numeric) + COALESCE(ct.out_route, 0::numeric) + COALESCE(ct.other, 0::numeric) - COALESCE(ct.deduction, 0::numeric)) / COALESCE(i.weight_kg, case when i.id is null then f.weight_kg when i.missing_weight_rank=1 then greatest(f.weight_kg-i.known_weight,0) else 0 end, 0::numeric)
                    ELSE NULL::numeric
                END AS pmt,
            case when (nullif(btrim(f.pod_file_path),'') is not null or nullif(btrim(f.delivery_stages #>> '{delivered,pod_photo_path}'),'') is not null or (f.ack_status='received' and ((f.pod_received_by is not null and f.pod_received_date is not null) or f.record_origin='historical_import'))) then 'received'::text else 'pending'::text end as ack_status,
            f.ack_received_at,
            f.pod_received_date,
            f.pod_file_path,
            f.pod_remark,
            f.pod_received_by,
            COALESCE(pr.full_name, pr.business_name, pr.email) AS pod_received_by_name,
            COALESCE(i.remarks, f.remarks) AS remarks,
            pt.product_breakdown,
            f.status,
            f.created_at,
            i.delivery_reference,
            case when (nullif(btrim(f.pod_file_path),'') is not null or nullif(btrim(f.delivery_stages #>> '{delivered,pod_photo_path}'),'') is not null or (f.ack_status='received' and ((f.pod_received_by is not null and f.pod_received_date is not null) or f.record_origin='historical_import'))) then coalesce(f.ack_received_at, f.pod_received_date::timestamptz, NULLIF(f.delivery_stages #>> '{delivered,submitted_at}'::text[], ''::text)::timestamptz) end AS pod_submitted_at,
            f.gr_bilty_number,
            COALESCE(f.gr_bilty_number, i.lr_number, i.gr_number) AS dispatch_gr_bilty_number,
            i.freight_share
           FROM freights f
             LEFT JOIN (
 select x.*,
   count(*) over w as invoice_rows,
   count(*) filter(where x.freight_share is null) over w as unallocated_rows,
   coalesce(sum(x.freight_share) over w,0) as explicit_freight,
   count(*) filter(where x.freight_share is null) over (partition by x.freight_id order by x.created_at,x.id) as unallocated_rank,
   row_number() over (partition by x.freight_id order by x.created_at,x.id) as invoice_rank,
   coalesce(sum(x.cases) over w,0) as known_cases,
   coalesce(sum(x.weight_kg) over w,0) as known_weight,
   count(*) filter(where x.cases is null) over (partition by x.freight_id order by x.created_at,x.id) as missing_cases_rank,
   count(*) filter(where x.weight_kg is null) over (partition by x.freight_id order by x.created_at,x.id) as missing_weight_rank
 from public.invoices x window w as (partition by x.freight_id)
 ) i ON i.freight_id = f.id
 LEFT JOIN LATERAL (select b.amount from public.bids b where b.freight_id=f.id and b.transporter_id=f.winner_profile_id and b.state='won' order by b.updated_at desc,b.id limit 1) winning on true
 LEFT JOIN LATERAL (select coalesce(f.accepted_freight_amount,winning.amount) as agreed) price on true
 LEFT JOIN LATERAL (select case when i.id is null then price.agreed
   when i.freight_share is not null then i.freight_share
   when price.agreed is not null and i.unallocated_rows>0 then
     case when i.unallocated_rank=i.unallocated_rows then greatest(price.agreed-i.explicit_freight,0)-round(greatest(price.agreed-i.explicit_freight,0)/i.unallocated_rows,2)*(i.unallocated_rows-1)
     else round(greatest(price.agreed-i.explicit_freight,0)/i.unallocated_rows,2) end
   else null end as accepted_share) allocation on true
             LEFT JOIN profiles tp ON tp.id = COALESCE(i.transporter_id, f.winner_profile_id)
             LEFT JOIN profiles pr ON pr.id = f.pod_received_by
             LEFT JOIN charge_totals ct ON ct.freight_id = f.id and ct.allocated_invoice_id is not distinct from i.id
             LEFT JOIN product_totals pt ON pt.freight_id = f.id
        )
 SELECT lr.freight_id,
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
    date_trunc('month'::text, COALESCE(lr.bill_date, lr.created_at::date)::timestamp with time zone)::date AS period_month,
    COALESCE(s.last_month_balance, 0::numeric) AS last_month_balance,
    COALESCE(s.payment_amount, 0::numeric) AS payment_amount,
    COALESCE(s.deduction_amount, 0::numeric) AS settlement_deduction,
    COALESCE(s.last_month_balance, 0::numeric) + lr.total_freight - COALESCE(s.payment_amount, 0::numeric) - COALESCE(s.deduction_amount, 0::numeric) AS balance,
    s.remarks AS settlement_remarks,
    lr.pod_submitted_at,
        CASE
            WHEN lr.dispatch_date IS NOT NULL AND lr.pod_submitted_at IS NOT NULL THEN lr.pod_submitted_at::date - lr.dispatch_date
            ELSE NULL::integer
        END AS pod_delay_days,
        CASE
            WHEN lr.dispatch_date IS NOT NULL AND lr.pod_submitted_at IS NOT NULL THEN (lr.pod_submitted_at::date - lr.dispatch_date) > 3
            ELSE false
        END AS pod_late_flag,
        CASE
            WHEN lr.dispatch_date IS NOT NULL AND lr.pod_submitted_at IS NULL THEN (CURRENT_DATE - lr.dispatch_date) > 3
            ELSE false
        END AS pod_missing_overdue_flag,
    lr.vehicle_capacity_category,
    lr.pod_received_date,
    lr.pod_file_path,
    lr.pod_remark,
    lr.pod_received_by,
    lr.pod_received_by_name,
    lr.gr_bilty_number,
    lr.dispatch_gr_bilty_number,
    lr.freight_share,
    COALESCE(ir.invoice_count, 0) AS invoice_count,
    COALESCE(ir.e_way_bill_count, 0) AS e_way_bill_count,
    COALESCE(ir.party_count, 0) AS party_count,
    ir.invoice_numbers,
    ir.e_way_bill_numbers,
    ir.party_names
   FROM ledger_rows lr
     LEFT JOIN invoice_rollups ir ON ir.freight_id = lr.freight_id
     LEFT JOIN transporter_ledger_settlements s ON s.company_name = lr.company_name AND NOT s.transporter_id IS DISTINCT FROM lr.transporter_id AND s.period_month = date_trunc('month'::text, COALESCE(lr.bill_date, lr.created_at::date)::timestamp with time zone)::date;


-- Unique claims serialize concurrent finalization while retaining audited overrides.
create table if not exists private.finalized_invoice_claims (
  invoice_norm text primary key,
  freight_id uuid not null references public.freights(id) on delete cascade
);
alter table private.finalized_invoice_claims enable row level security;
revoke all on private.finalized_invoice_claims from public,anon,authenticated;
insert into private.finalized_invoice_claims(invoice_norm,freight_id)
select public.normalize_invoice_number(i.invoice_number), (array_agg(i.freight_id order by i.created_at,i.id))[1]
from public.invoices i join public.freights f on f.id=i.freight_id
where public.is_finalized_freight_status(f.status) and public.normalize_invoice_number(i.invoice_number) is not null
group by public.normalize_invoice_number(i.invoice_number)
on conflict(invoice_norm) do nothing;

create or replace function private.claim_finalized_invoice(p_norm text,p_freight uuid)
returns void language plpgsql security definer set search_path=''
as $$
declare owner_id uuid;
begin
 if p_norm is null then return; end if;
 -- ON CONFLICT locks the current row and observes a concurrent committed claimant.
 insert into private.finalized_invoice_claims(invoice_norm,freight_id) values(p_norm,p_freight)
 on conflict(invoice_norm) do update set invoice_norm=excluded.invoice_norm
 returning freight_id into owner_id;
 if owner_id=p_freight then return; end if;
 if not exists(select 1 from public.freights f join public.invoices i on i.freight_id=f.id
   where f.id=owner_id and public.is_finalized_freight_status(f.status)
   and public.normalize_invoice_number(i.invoice_number)=p_norm) then
   update private.finalized_invoice_claims set freight_id=p_freight where invoice_norm=p_norm;
   return;
 end if;
 if exists(select 1 from public.duplicate_freight_overrides o join public.profiles p on p.id=o.approved_by
   where o.invoice_number_norm=p_norm and o.new_freight_id=p_freight
   and (o.existing_freight_id is null or o.existing_freight_id=owner_id)
   and p.role='admin' and length(btrim(o.reason))>0 and length(btrim(o.remark))>0) then return; end if;
 raise exception 'Invoice already has finalized freight; an audited administrator override is required' using errcode='23505';
end $$;
revoke all on function private.claim_finalized_invoice(text,uuid) from public,anon,authenticated;

create or replace function private.enforce_finalized_invoice_claim()
returns trigger language plpgsql security definer set search_path=''
as $$
declare item record;
begin
 if tg_table_name='invoices' then
   if new.freight_id is not null and exists(select 1 from public.freights where id=new.freight_id and public.is_finalized_freight_status(status)) then
     perform private.claim_finalized_invoice(public.normalize_invoice_number(new.invoice_number),new.freight_id);
   end if;
 else
   if public.is_finalized_freight_status(new.status) then
     for item in select distinct public.normalize_invoice_number(invoice_number) norm from public.invoices where freight_id=new.id order by norm loop
       perform private.claim_finalized_invoice(item.norm,new.id);
     end loop;
   end if;
 end if;
 return new;
end $$;
revoke all on function private.enforce_finalized_invoice_claim() from public,anon,authenticated;
create trigger finalized_invoice_claim_guard before insert or update of invoice_number,freight_id on public.invoices
for each row execute function private.enforce_finalized_invoice_claim();
create trigger finalized_freight_claim_guard after insert or update of status on public.freights
for each row execute function private.enforce_finalized_invoice_claim();
