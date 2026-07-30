create or replace function public.find_duplicate_finalized_invoices(
  invoice_numbers text[],
  excluded_freight_id uuid default null
)
returns table (
  invoice_number text,
  invoice_number_norm text,
  existing_freight_id uuid,
  existing_invoice_id uuid,
  company_name text,
  transporter_name text,
  bill_date date,
  dispatch_date date,
  status public.freight_status,
  total_freight numeric
)
language sql
stable
set search_path = ''
as $$
  with input_invoices as (
    select
      raw_invoice.invoice_number,
      public.normalize_invoice_number(raw_invoice.invoice_number) as invoice_number_norm
    from unnest(invoice_numbers) as raw_invoice(invoice_number)
    where public.normalize_invoice_number(raw_invoice.invoice_number) is not null
  ),
  charge_totals as (
    select
      freight_charges.freight_id,
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
  )
  select distinct on (input_invoices.invoice_number_norm, invoices.freight_id)
    input_invoices.invoice_number,
    input_invoices.invoice_number_norm,
    invoices.freight_id as existing_freight_id,
    invoices.id as existing_invoice_id,
    freights.company_name,
    coalesce(profiles.business_name, profiles.full_name, profiles.email) as transporter_name,
    coalesce(invoices.bill_date, freights.bill_date) as bill_date,
    coalesce(invoices.dispatch_date, freights.dispatch_date, freights.dispatched_at::date) as dispatch_date,
    freights.status,
    coalesce(invoices.freight_share, invoices.base_freight, freights.internal_calling_bid, 0::numeric)
      + coalesce(charge_totals.charges_total, 0::numeric) as total_freight
  from input_invoices
  join public.invoices
    on public.normalize_invoice_number(invoices.invoice_number) = input_invoices.invoice_number_norm
  join public.freights
    on freights.id = invoices.freight_id
  left join public.profiles
    on profiles.id = coalesce(invoices.transporter_id, freights.winner_profile_id)
  left join charge_totals
    on charge_totals.freight_id = freights.id
  where public.is_finalized_freight_status(freights.status)
    and freights.id is distinct from excluded_freight_id
  order by input_invoices.invoice_number_norm, invoices.freight_id, invoices.created_at;
$$;

revoke all on function public.find_duplicate_finalized_invoices(text[], uuid)
  from public;
grant execute on function public.find_duplicate_finalized_invoices(text[], uuid)
  to authenticated;
