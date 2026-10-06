-- Permit office staff to record missing invoices after delivery without changing the completed status.
create or replace function public.lock_freight_invoices(
  p_freight_id uuid,
  p_invoices jsonb,
  p_charges jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  freight_row public.freights;
  item jsonb;
  invoice_id uuid;
  invoice_ids uuid[] := '{}'::uuid[];
  invoice_index integer := 0;
  invoice_count integer;
  charge_count integer := 0;
  missing_count integer := 0;
  missing_index integer := 0;
  missing_cases numeric := 0;
  missing_weight numeric := 0;
  explicit_total numeric := 0;
  remaining_amount numeric := 0;
  missing_allocated numeric := 0;
  allocated_amount numeric := 0;
  share_amount numeric;
  accepted_amount numeric;
  winner_amount numeric;
  charge_amount numeric;
  charge_index integer;
  target_invoice_id uuid;
  role_name text := public.current_role()::text;
begin
  if (select auth.uid()) is null
     or coalesce(role_name, '') not in ('admin', 'logistics_manager') then
    raise exception 'Only approved office staff may lock invoices' using errcode = '42501';
  end if;
  if p_freight_id is null
     or jsonb_typeof(p_invoices) is distinct from 'array'
     or jsonb_typeof(p_charges) is distinct from 'array' then
    raise exception 'Invoices and charges must be JSON arrays' using errcode = '22023';
  end if;

  select * into freight_row
  from public.freights f
  where f.id = p_freight_id
  for update;
  if not found then
    raise exception 'Freight is unavailable' using errcode = 'P0002';
  end if;
  if freight_row.status not in (
      'awarded'::public.freight_status,
      'dispatched'::public.freight_status,
      'completed'::public.freight_status
    ) then
    raise exception 'Only awarded, dispatched or completed freight can receive invoices' using errcode = '42501';
  end if;
  if exists (select 1 from public.invoices i where i.freight_id = p_freight_id) then
    raise exception 'Freight already has invoices; use the manual ledger save for edits'
      using errcode = '23505';
  end if;

  invoice_count := jsonb_array_length(p_invoices);
  if invoice_count = 0 then
    raise exception 'At least one invoice is required to lock freight' using errcode = '22023';
  end if;
  if exists (
    select 1
    from (
      select public.normalize_invoice_number(value->>'invoice_number') as invoice_number_norm
      from jsonb_array_elements(p_invoices)
    ) duplicate_keys
    group by invoice_number_norm
    having count(*) > 1
  ) then
    raise exception 'Invoice numbers must be unique within a freight' using errcode = '23505';
  end if;

  select b.amount into winner_amount
  from public.bids b
  where b.freight_id = p_freight_id
    and b.state = 'won'::public.bid_state
  order by b.updated_at desc, b.id
  limit 1;
  accepted_amount := coalesce(freight_row.accepted_freight_amount, winner_amount);
  if accepted_amount is null or accepted_amount <= 0 then
    raise exception 'A positive accepted freight amount is required before locking'
      using errcode = '42501';
  end if;
  if upper(btrim(accepted_amount::text)) in
       ('NAN', '+NAN', '-NAN', 'INFINITY', '+INFINITY', '-INFINITY') then
    raise exception 'Accepted freight amount must be finite' using errcode = '22023';
  end if;

  for item in select value from jsonb_array_elements(p_invoices) loop
    if nullif(btrim(item->>'invoice_number'), '') is null
       or nullif(btrim(item->>'town'), '') is null then
      raise exception 'Invoice number and town are required' using errcode = '22023';
    end if;
    if upper(btrim(coalesce(item->>'cases', ''))) in
         ('NAN', '+NAN', '-NAN', 'INFINITY', '+INFINITY', '-INFINITY')
       or upper(btrim(coalesce(item->>'weight_kg', ''))) in
         ('NAN', '+NAN', '-NAN', 'INFINITY', '+INFINITY', '-INFINITY')
       or upper(btrim(coalesce(item->>'base_freight', ''))) in
         ('NAN', '+NAN', '-NAN', 'INFINITY', '+INFINITY', '-INFINITY')
       or upper(btrim(coalesce(item->>'freight_share', ''))) in
         ('NAN', '+NAN', '-NAN', 'INFINITY', '+INFINITY', '-INFINITY') then
      raise exception 'Invoice quantities and freight must be finite'
        using errcode = '22023';
    end if;
    if coalesce(nullif(btrim(item->>'cases'), '')::numeric, 0) < 0
       or coalesce(nullif(btrim(item->>'weight_kg'), '')::numeric, 0) < 0
       or coalesce(nullif(btrim(item->>'base_freight'), '')::numeric, 0) < 0
       or coalesce(nullif(btrim(item->>'freight_share'), '')::numeric, 0) < 0 then
      raise exception 'Invoice quantities and freight must be non-negative'
        using errcode = '22023';
    end if;
    if item ? 'freight_share' and nullif(btrim(item->>'freight_share'), '') is not null then
      explicit_total := explicit_total + (item->>'freight_share')::numeric;
    else
      missing_count := missing_count + 1;
      missing_cases := missing_cases + coalesce(nullif(btrim(item->>'cases'), '')::numeric, 0);
      missing_weight := missing_weight + coalesce(nullif(btrim(item->>'weight_kg'), '')::numeric, 0);
    end if;
  end loop;

  if explicit_total > accepted_amount + 0.000001 then
    raise exception 'Explicit invoice freight shares exceed the accepted amount'
      using errcode = '22023';
  end if;
  if missing_count = 0 then
    if abs(explicit_total - accepted_amount) > 0.000001 then
      raise exception 'Explicit invoice freight shares must equal the accepted amount'
        using errcode = '22023';
    end if;
  else
    remaining_amount := greatest(0, accepted_amount - explicit_total);
  end if;

  invoice_index := 0;
  for item in select value from jsonb_array_elements(p_invoices) loop
    invoice_index := invoice_index + 1;
    invoice_id := gen_random_uuid();
    invoice_ids := array_append(invoice_ids, invoice_id);
    if item ? 'freight_share' and nullif(item->>'freight_share', '') is not null then
      share_amount := (item->>'freight_share')::numeric;
    else
      missing_index := missing_index + 1;
      if missing_index = missing_count then
        share_amount := remaining_amount - missing_allocated;
      elsif missing_weight > 0 then
        share_amount := remaining_amount
          * coalesce(nullif(btrim(item->>'weight_kg'), '')::numeric, 0)
          / missing_weight;
      elsif missing_cases > 0 then
        share_amount := remaining_amount
          * coalesce(nullif(btrim(item->>'cases'), '')::numeric, 0)
          / missing_cases;
      else
        share_amount := remaining_amount / missing_count;
      end if;
      if missing_index < missing_count then
        share_amount := least(remaining_amount - missing_allocated, round(share_amount, 2));
      end if;
      missing_allocated := missing_allocated + share_amount;
    end if;
    if share_amount < 0 then
      raise exception 'Invoice freight share cannot be negative' using errcode = '22023';
    end if;
    allocated_amount := allocated_amount + share_amount;

    insert into public.invoices(
      id, freight_id, invoice_number, gr_number, lr_number,
      e_way_bill_number, delivery_reference, party_name, town,
      cases, weight_kg, base_freight, freight_share, bill_date,
      dispatch_date, vehicle_number, vehicle_type, transporter_id, validated
    ) values (
      invoice_id, p_freight_id, btrim(item->>'invoice_number'),
      nullif(btrim(item->>'gr_number'), ''),
      nullif(btrim(item->>'lr_number'), ''),
      nullif(btrim(item->>'e_way_bill_number'), ''),
      nullif(btrim(item->>'delivery_reference'), ''),
      nullif(btrim(item->>'party_name'), ''),
      btrim(item->>'town'),
      nullif(item->>'cases', '')::integer,
      nullif(item->>'weight_kg', '')::numeric,
      coalesce(nullif(item->>'base_freight', '')::numeric, share_amount),
      share_amount,
      nullif(item->>'bill_date', '')::date,
      nullif(item->>'dispatch_date', '')::date,
      nullif(btrim(item->>'vehicle_number'), ''),
      nullif(btrim(item->>'vehicle_type'), ''),
      freight_row.winner_profile_id,
      true
    );
  end loop;

  if abs(allocated_amount - accepted_amount) > 0.000001 then
    raise exception 'Invoice freight shares must equal the accepted amount'
      using errcode = '22023';
  end if;

  for item in select value from jsonb_array_elements(p_charges) loop
    if nullif(btrim(item->>'amount'), '') is null
       or upper(btrim(coalesce(item->>'amount', ''))) in
         ('NAN', '+NAN', '-NAN', 'INFINITY', '+INFINITY', '-INFINITY') then
      raise exception 'Charge amount must be finite and non-negative'
        using errcode = '22023';
    end if;
    charge_amount := (item->>'amount')::numeric;
    if charge_amount is null or charge_amount < 0 then
      raise exception 'Charge amount must be non-negative' using errcode = '22023';
    end if;
    charge_index := nullif(item->>'invoice_index', '')::integer;
    target_invoice_id := null;
    if charge_index is not null then
      if charge_index < 0 or charge_index >= invoice_count then
        raise exception 'Charge invoice_index is outside the invoice array'
          using errcode = '22023';
      end if;
      target_invoice_id := invoice_ids[charge_index + 1];
    end if;
    insert into public.freight_charges(
      freight_id, invoice_id, kind, amount, remarks, added_by, approved
    ) values (
      p_freight_id,
      target_invoice_id,
      item->>'kind',
      charge_amount,
      nullif(btrim(item->>'remarks'), ''),
      (select auth.uid()),
      true
    );
    charge_count := charge_count + 1;
  end loop;

  if freight_row.status = 'completed'::public.freight_status then
    -- Keep the delivery result intact when paperwork arrives afterward.
    update public.freights
    set locked_at = coalesce(locked_at, now())
    where id = p_freight_id;
  else
    perform set_config('kaysons.lock_freight', 'on', true);
    update public.freights
    set status = 'locked'::public.freight_status,
        locked_at = coalesce(locked_at, now())
    where id = p_freight_id;
  end if;

  return jsonb_build_object(
    'freight_id', p_freight_id,
    'status', case when freight_row.status = 'completed'::public.freight_status
                   then 'completed' else 'locked' end,
    'accepted_amount', accepted_amount,
    'invoice_count', invoice_count,
    'charge_count', charge_count,
    'invoice_ids', to_jsonb(invoice_ids)
  );
end
$$;

revoke all on function public.lock_freight_invoices(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.lock_freight_invoices(uuid, jsonb, jsonb) to authenticated;
