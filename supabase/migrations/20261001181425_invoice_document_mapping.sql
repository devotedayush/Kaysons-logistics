-- A dispatch may contain many goods invoices. Each invoice can reference any number
-- of e-way bills and GR/Bilty documents; the same GR may cover several invoices.
create table public.invoice_documents (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  document_kind text not null check (document_kind in ('e_way_bill', 'gr_bilty')),
  document_number text not null check (length(btrim(document_number)) > 0),
  created_at timestamptz not null default now()
);

create unique index invoice_documents_invoice_kind_number_key
  on public.invoice_documents (invoice_id, document_kind, lower(btrim(document_number)));

alter table public.invoice_documents enable row level security;
revoke all on public.invoice_documents from public, anon;
grant select, insert, update, delete on public.invoice_documents to authenticated;

create policy "invoice documents office read"
on public.invoice_documents for select to authenticated
using ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role,
  'accountant'::public.user_role
));

create policy "invoice documents winner read"
on public.invoice_documents for select to authenticated
using (
  (select public.current_role()) = 'transporter'::public.user_role
  and exists (
    select 1 from public.invoices i
    join public.freights f on f.id = i.freight_id
    where i.id = invoice_documents.invoice_id
      and f.record_origin = 'live'
      and f.winner_profile_id = (select auth.uid())
  )
);

create policy "invoice documents office insert"
on public.invoice_documents for insert to authenticated
with check ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role,
  'accountant'::public.user_role
 ) and exists (
  select 1 from public.invoices i
  join public.freights f on f.id = i.freight_id
  where i.id = invoice_documents.invoice_id
    and ((select public.current_role()) <> 'accountant'::public.user_role
      or f.status in ('locked'::public.freight_status, 'completed'::public.freight_status)
      or f.record_origin = 'historical_import')
));

create policy "invoice documents office update"
on public.invoice_documents for update to authenticated
using ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role,
  'accountant'::public.user_role
 ) and exists (
  select 1 from public.invoices i
  join public.freights f on f.id = i.freight_id
  where i.id = invoice_documents.invoice_id
    and ((select public.current_role()) <> 'accountant'::public.user_role
      or f.status in ('locked'::public.freight_status, 'completed'::public.freight_status)
      or f.record_origin = 'historical_import')
))
with check ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role,
  'accountant'::public.user_role
 ) and exists (
  select 1 from public.invoices i
  join public.freights f on f.id = i.freight_id
  where i.id = invoice_documents.invoice_id
    and ((select public.current_role()) <> 'accountant'::public.user_role
      or f.status in ('locked'::public.freight_status, 'completed'::public.freight_status)
      or f.record_origin = 'historical_import')
));

create policy "invoice documents office delete"
on public.invoice_documents for delete to authenticated
using ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role,
  'accountant'::public.user_role
 ) and exists (
  select 1 from public.invoices i
  join public.freights f on f.id = i.freight_id
  where i.id = invoice_documents.invoice_id
    and ((select public.current_role()) <> 'accountant'::public.user_role
      or f.status in ('locked'::public.freight_status, 'completed'::public.freight_status)
      or f.record_origin = 'historical_import')
));

-- Preserve old invoices in the new mapping without changing legacy columns.
insert into public.invoice_documents(invoice_id, document_kind, document_number)
select i.id, 'e_way_bill', btrim(i.e_way_bill_number)
from public.invoices i
where nullif(btrim(i.e_way_bill_number), '') is not null
on conflict do nothing;

insert into public.invoice_documents(invoice_id, document_kind, document_number)
select i.id, 'gr_bilty', btrim(v.document_number)
from public.invoices i
cross join lateral (values (i.gr_number), (i.lr_number)) v(document_number)
where nullif(btrim(v.document_number), '') is not null
on conflict do nothing;

-- Existing callers still write scalar values. Keep that path visible in the mapping.
create or replace function private.mirror_invoice_scalar_documents()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if old.e_way_bill_number is distinct from new.e_way_bill_number then
      delete from public.invoice_documents d
      where d.invoice_id = new.id and d.document_kind = 'e_way_bill'
        and lower(btrim(d.document_number)) = lower(btrim(old.e_way_bill_number));
    end if;
    if old.gr_number is distinct from new.gr_number then
      delete from public.invoice_documents d
      where d.invoice_id = new.id and d.document_kind = 'gr_bilty'
        and lower(btrim(d.document_number)) = lower(btrim(old.gr_number));
    end if;
    if old.lr_number is distinct from new.lr_number then
      delete from public.invoice_documents d
      where d.invoice_id = new.id and d.document_kind = 'gr_bilty'
        and lower(btrim(d.document_number)) = lower(btrim(old.lr_number));
    end if;
  end if;
  if nullif(btrim(new.e_way_bill_number), '') is not null then
    insert into public.invoice_documents(invoice_id, document_kind, document_number)
    values(new.id, 'e_way_bill', btrim(new.e_way_bill_number))
    on conflict do nothing;
  end if;
  if nullif(btrim(new.gr_number), '') is not null then
    insert into public.invoice_documents(invoice_id, document_kind, document_number)
    values(new.id, 'gr_bilty', btrim(new.gr_number))
    on conflict do nothing;
  end if;
  if nullif(btrim(new.lr_number), '') is not null then
    insert into public.invoice_documents(invoice_id, document_kind, document_number)
    values(new.id, 'gr_bilty', btrim(new.lr_number))
    on conflict do nothing;
  end if;
  return new;
end
$$;
revoke all on function private.mirror_invoice_scalar_documents() from public, anon, authenticated;

create trigger mirror_invoice_scalar_documents
after insert or update of e_way_bill_number, gr_number, lr_number on public.invoices
for each row execute function private.mirror_invoice_scalar_documents();

-- Used by the invoice-lock and manual-ledger transactions. Array keys take
-- precedence; absent arrays fall back to the old scalar fields.
create or replace function public.replace_invoice_documents(
  p_invoice_id uuid, p_invoice jsonb
) returns void language plpgsql security invoker set search_path = ''
as $$
declare
  v_invoice public.invoices;
  v_eway jsonb;
  v_gr jsonb;
  v_first_eway text;
  v_first_gr text;
begin
  if (select auth.uid()) is null or (select public.current_role()) not in (
    'admin'::public.user_role,
    'logistics_manager'::public.user_role,
    'accountant'::public.user_role
  ) then
    raise exception 'Office role required to edit invoice documents' using errcode = '42501';
  end if;
  if jsonb_typeof(p_invoice) is distinct from 'object' then
    raise exception 'Invoice documents must be an object' using errcode = '22023';
  end if;
  select * into v_invoice from public.invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'Invoice is unavailable' using errcode = 'P0002';
  end if;

  v_eway := case when p_invoice ? 'e_way_bill_numbers'
    then p_invoice->'e_way_bill_numbers'
    when nullif(btrim(coalesce(p_invoice->>'e_way_bill_number', v_invoice.e_way_bill_number)), '') is not null
    then jsonb_build_array(coalesce(p_invoice->>'e_way_bill_number', v_invoice.e_way_bill_number))
    else '[]'::jsonb end;
  v_gr := case when p_invoice ? 'gr_bilty_numbers'
    then p_invoice->'gr_bilty_numbers'
    else to_jsonb(array_remove(array[
      nullif(btrim(coalesce(p_invoice->>'gr_number', v_invoice.gr_number)), ''),
      nullif(btrim(coalesce(p_invoice->>'lr_number', v_invoice.lr_number)), '')
    ], null)) end;

  if jsonb_typeof(v_eway) is distinct from 'array'
     or jsonb_typeof(v_gr) is distinct from 'array'
     or jsonb_array_length(v_eway) > 100
     or jsonb_array_length(v_gr) > 100
     or exists (
       select 1 from jsonb_array_elements(v_eway || v_gr) as x(value)
       where jsonb_typeof(x.value) <> 'string'
          or length(btrim(x.value #>> '{}')) not between 1 and 120
     ) then
    raise exception 'Document numbers must be non-empty strings (at most 100 per kind)'
      using errcode = '22023';
  end if;

  -- Update legacy scalars before replacing rows. The scalar mirror trigger may
  -- remove an old first number; doing it first keeps extra mapped numbers safe.
  v_first_eway := nullif(btrim(v_eway->>0), '');
  v_first_gr := nullif(btrim(v_gr->>0), '');
  update public.invoices
  set e_way_bill_number = v_first_eway,
      gr_number = v_first_gr,
      lr_number = v_first_gr
  where id = p_invoice_id;

  delete from public.invoice_documents where invoice_id = p_invoice_id;
  insert into public.invoice_documents(invoice_id, document_kind, document_number)
  select p_invoice_id, 'e_way_bill', btrim(value #>> '{}')
  from jsonb_array_elements(v_eway) as x(value)
  on conflict do nothing;
  insert into public.invoice_documents(invoice_id, document_kind, document_number)
  select p_invoice_id, 'gr_bilty', btrim(value #>> '{}')
  from jsonb_array_elements(v_gr) as x(value)
  on conflict do nothing;

end
$$;

revoke all on function public.replace_invoice_documents(uuid, jsonb) from public, anon;
grant execute on function public.replace_invoice_documents(uuid, jsonb) to authenticated;

-- Keep the existing atomic lock contract and add nested document arrays.
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
    perform public.replace_invoice_documents(invoice_id, item);
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

-- Manual ledger edits retain child document mappings when arrays are absent.
-- Save accounting edits as one transaction; failed children preserve the original entry.
create or replace function public.save_manual_ledger_entry(
 p_freight_id uuid, p_is_new boolean, p_freight jsonb, p_invoices jsonb,
 p_charges jsonb, p_products jsonb, p_overrides jsonb, p_settlement jsonb default null
) returns uuid
language plpgsql security invoker set search_path=''
as $$
declare
 v public.freights; merged public.freights; r public.invoices; c public.freight_charges;
 item jsonb; v_uid uuid := auth.uid();
begin
 if v_uid is null or public.current_role()::text not in ('admin','accountant','logistics_manager') then
   raise exception 'Office role required' using errcode='42501';
 end if;
 if p_freight_id is null or jsonb_typeof(p_freight) is distinct from 'object'
   or jsonb_typeof(p_invoices) is distinct from 'array' or jsonb_array_length(p_invoices)=0
   or jsonb_typeof(p_charges) is distinct from 'array' or jsonb_typeof(p_products) is distinct from 'array'
   or jsonb_typeof(p_overrides) is distinct from 'array' then raise exception 'Invalid ledger payload'; end if;
 if exists(select 1 from jsonb_populate_recordset(null::public.invoices,p_invoices) i
   where i.id is null or nullif(btrim(i.invoice_number),'') is null or nullif(btrim(i.town),'') is null
   or i.cases < 0 or i.weight_kg < 0 or i.base_freight < 0 or i.freight_share < 0) then
   raise exception 'Every invoice requires a number, town and non-negative quantities'; end if;
 if exists (
   select 1
   from jsonb_array_elements(p_invoices) as raw(value)
   group by public.normalize_invoice_number(raw.value->>'invoice_number')
   having count(*) > 1
 ) then
   raise exception 'Invoice numbers must be unique within a freight' using errcode='23505';
 end if;
 if exists(select 1 from public.invoices i join jsonb_populate_recordset(null::public.invoices,p_invoices) n on n.id=i.id
   where i.freight_id is distinct from p_freight_id) then raise exception 'Invoice belongs to a different freight'; end if;
 if p_is_new then
   merged := jsonb_populate_record(null::public.freights,p_freight);
   insert into public.freights(id,created_by,status,origin,destination_town,company_name,party_name,bill_date,dispatch_date,vehicle_number,vehicle_type,gr_bilty_number,vehicle_capacity_category,source_branch,ack_status,ack_received_at,pod_received_date,pod_file_path,pod_remark,pod_received_by,winner_profile_id,cases,weight_kg,remarks) values(p_freight_id,v_uid,'locked',merged.origin,merged.destination_town,merged.company_name,merged.party_name,merged.bill_date,merged.dispatch_date,merged.vehicle_number,merged.vehicle_type,merged.gr_bilty_number,merged.vehicle_capacity_category,merged.source_branch,merged.ack_status,merged.ack_received_at,merged.pod_received_date,merged.pod_file_path,merged.pod_remark,merged.pod_received_by,merged.winner_profile_id,merged.cases,merged.weight_kg,merged.remarks);
 else
   select * into v from public.freights where id=p_freight_id for update;
   if not found then raise exception 'Freight is unavailable' using errcode='42501'; end if;
   merged := jsonb_populate_record(v,p_freight);
   update public.freights set origin=merged.origin,destination_town=merged.destination_town,company_name=merged.company_name,party_name=merged.party_name,bill_date=merged.bill_date,dispatch_date=merged.dispatch_date,vehicle_number=merged.vehicle_number,vehicle_type=merged.vehicle_type,gr_bilty_number=merged.gr_bilty_number,vehicle_capacity_category=merged.vehicle_capacity_category,source_branch=merged.source_branch,ack_status=merged.ack_status,ack_received_at=merged.ack_received_at,pod_received_date=merged.pod_received_date,pod_file_path=merged.pod_file_path,pod_remark=merged.pod_remark,pod_received_by=merged.pod_received_by,winner_profile_id=merged.winner_profile_id,cases=merged.cases,weight_kg=merged.weight_kg,remarks=merged.remarks where id=p_freight_id;
 end if;
 -- Overrides precede invoice validation, within the same transaction.
 for item in select value from jsonb_array_elements(p_overrides) loop
   if public.current_role()::text <> 'admin' or nullif(btrim(item->>'reason'),'') is null or nullif(btrim(item->>'remark'),'') is null then
     raise exception 'Duplicate override requires an administrator, reason and remark' using errcode='42501';
   end if;
   insert into public.duplicate_freight_overrides(invoice_number,invoice_number_norm,existing_freight_id,new_freight_id,approved_by,reason,remark,metadata)
   values(item->>'invoice_number',public.normalize_invoice_number(item->>'invoice_number'),(item->>'existing_freight_id')::uuid,p_freight_id,v_uid,item->>'reason',item->>'remark',coalesce(item->'metadata','{}'));
 end loop;
 -- Replace children atomically and preserve invoice identities and their charge references.
 delete from public.freight_charges where freight_id=p_freight_id;
 delete from public.freight_product_lines where freight_id=p_freight_id;
 delete from public.invoices where freight_id=p_freight_id and id not in
   (select i.id from jsonb_populate_recordset(null::public.invoices,p_invoices) i);
 for r in select * from jsonb_populate_recordset(null::public.invoices,p_invoices) loop
   insert into public.invoices(id,freight_id,invoice_number,gr_number,transporter_id,town,weight_kg,cases,base_freight,freight_share,validated,e_way_bill_number,party_name,bill_date,dispatch_date,lr_number,vehicle_number,vehicle_type,remarks,delivery_reference) values(r.id,p_freight_id,r.invoice_number,r.gr_number,merged.winner_profile_id,r.town,r.weight_kg,r.cases,r.base_freight,r.freight_share,true,r.e_way_bill_number,r.party_name,r.bill_date,r.dispatch_date,r.lr_number,r.vehicle_number,r.vehicle_type,r.remarks,r.delivery_reference)
   on conflict(id) do update set freight_id=excluded.freight_id,invoice_number=excluded.invoice_number,gr_number=excluded.gr_number,transporter_id=excluded.transporter_id,town=excluded.town,weight_kg=excluded.weight_kg,cases=excluded.cases,base_freight=excluded.base_freight,freight_share=excluded.freight_share,validated=excluded.validated,e_way_bill_number=excluded.e_way_bill_number,party_name=excluded.party_name,bill_date=excluded.bill_date,dispatch_date=excluded.dispatch_date,lr_number=excluded.lr_number,vehicle_number=excluded.vehicle_number,vehicle_type=excluded.vehicle_type,remarks=excluded.remarks,delivery_reference=excluded.delivery_reference;
   select value into item from jsonb_array_elements(p_invoices) as raw(value)
   where raw.value->>'id' = r.id::text limit 1;
   if item ? 'e_way_bill_numbers' or item ? 'gr_bilty_numbers' then
     perform public.replace_invoice_documents(r.id, item);
   end if;
 end loop;
 for c in select * from jsonb_populate_recordset(null::public.freight_charges,p_charges) loop
   if c.amount is null or c.amount < 0 or (c.invoice_id is not null and not exists
     (select 1 from public.invoices where id=c.invoice_id and freight_id=p_freight_id)) then
     raise exception 'Charge must be non-negative and linked to an invoice in this freight';
   end if;
   insert into public.freight_charges(freight_id,invoice_id,kind,amount,remarks,added_by,approved,added_after_lock)
   values(p_freight_id,c.invoice_id,c.kind,c.amount,c.remarks,v_uid,true,coalesce(c.added_after_lock,false));
 end loop;
 for item in select value from jsonb_array_elements(p_products) loop
   if nullif(btrim(item->>'product_name'),'') is null or (item->>'quantity')::numeric < 0 then raise exception 'Invalid product row'; end if;
   insert into public.freight_product_lines(freight_id,product_name,quantity)
     values(p_freight_id,item->>'product_name',(item->>'quantity')::numeric);
 end loop;
 if p_settlement is not null and p_settlement <> 'null'::jsonb then
   if (p_settlement->>'transporter_id')::uuid is distinct from merged.winner_profile_id
     or (p_settlement->>'company_name') is distinct from merged.company_name then raise exception 'Settlement does not match freight'; end if;
   insert into public.transporter_ledger_settlements(company_name,transporter_id,period_month,last_month_balance,payment_amount,deduction_amount,remarks,created_by)
   values(merged.company_name,merged.winner_profile_id,(p_settlement->>'period_month')::date,
     (p_settlement->>'last_month_balance')::numeric,(p_settlement->>'payment_amount')::numeric,
     (p_settlement->>'deduction_amount')::numeric,p_settlement->>'remarks',v_uid)
   on conflict(company_name,transporter_id,period_month) do update set
     last_month_balance=excluded.last_month_balance,payment_amount=excluded.payment_amount,
     deduction_amount=excluded.deduction_amount,remarks=excluded.remarks,updated_at=now();
 end if;
 return p_freight_id;
end;
$$;
revoke all on function public.save_manual_ledger_entry(uuid,boolean,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon;
grant execute on function public.save_manual_ledger_entry(uuid,boolean,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb) to authenticated;

-- Keep the ledger view column contract while counting every mapped e-way bill.
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
            count(DISTINCT invoices.id)::integer AS invoice_count,
            (count(DISTINCT NULLIF(d.document_number, ''::text)) FILTER (WHERE d.document_kind = 'e_way_bill'))::integer AS e_way_bill_count,
            count(DISTINCT NULLIF(invoices.party_name, ''::text))::integer AS party_count,
            string_agg(DISTINCT NULLIF(invoices.invoice_number, ''::text), ', '::text ORDER BY (NULLIF(invoices.invoice_number, ''::text))) AS invoice_numbers,
            string_agg(DISTINCT NULLIF(d.document_number, ''::text), ', '::text ORDER BY (NULLIF(d.document_number, ''::text))) FILTER (WHERE d.document_kind = 'e_way_bill') AS e_way_bill_numbers,
            string_agg(DISTINCT NULLIF(invoices.party_name, ''::text), ', '::text ORDER BY (NULLIF(invoices.party_name, ''::text))) AS party_names
           FROM invoices
           LEFT JOIN public.invoice_documents d ON d.invoice_id = invoices.id
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
