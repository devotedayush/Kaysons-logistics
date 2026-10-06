-- Accountants may create and finish their own historical upload batches.
create policy "accountant own import batch insert" on public.historical_import_batches
for insert to authenticated with check (
  (select public.current_role()) = 'accountant'::public.user_role
  and created_by = (select auth.uid())
);
create policy "accountant own import batch update" on public.historical_import_batches
for update to authenticated using (
  (select public.current_role()) = 'accountant'::public.user_role
  and created_by = (select auth.uid())
) with check (
  (select public.current_role()) = 'accountant'::public.user_role
  and created_by = (select auth.uid())
);

-- A CSV is one transaction. RLS remains active and retries return the original batch.
create or replace function public.import_historical_ledger_csv(
  p_source_csv text, p_source_name text, p_freights jsonb,
  p_invoices jsonb, p_charges jsonb
) returns jsonb
language plpgsql security invoker set search_path = ''
as $$
declare
  v_batch uuid;
  v_key text;
  v_existing public.historical_import_batches;
begin
  if auth.uid() is null or public.current_role()::text not in ('admin','accountant','logistics_manager') then
    raise exception 'Only approved office staff can import historical records' using errcode = '42501';
  end if;
  if nullif(btrim(p_source_csv),'') is null or nullif(btrim(p_source_name),'') is null
    or jsonb_typeof(p_freights) is distinct from 'array'
    or jsonb_typeof(p_invoices) is distinct from 'array'
    or jsonb_typeof(p_charges) is distinct from 'array' then
    raise exception 'Invalid CSV import payload';
  end if;
  if jsonb_array_length(p_freights) = 0 or jsonb_array_length(p_invoices) = 0 then
    raise exception 'CSV import requires dispatches and invoices';
  end if;
  v_key := 'csv-v1:' || md5(replace(btrim(p_source_csv), E'\r\n', E'\n'));
  perform pg_advisory_xact_lock(hashtextextended(v_key, 0));
  select * into v_existing from public.historical_import_batches where source_key = v_key;
  if found then
    if v_existing.status <> 'completed' then raise exception 'Import batch is not completed; review it before retrying'; end if;
    return jsonb_build_object('already_imported', true, 'batch_id', v_existing.id, 'rows_imported', v_existing.row_count);
  end if;
  if exists (select 1 from jsonb_populate_recordset(null::public.freights,p_freights) f
    where f.id is null or f.created_by is distinct from auth.uid()
      or nullif(btrim(f.origin),'') is null or nullif(btrim(f.destination_town),'') is null
      or f.status::text not in ('locked','completed')
      or f.cases < 0 or f.weight_kg < 0 or f.internal_calling_bid < 0)
    or exists (select 1 from jsonb_populate_recordset(null::public.invoices,p_invoices) i
      where i.id is null or nullif(btrim(i.invoice_number),'') is null or i.bill_date is null
        or nullif(btrim(i.party_name),'') is null or nullif(btrim(i.town),'') is null
        or i.cases < 0 or i.weight_kg < 0 or i.base_freight < 0
        or not exists (select 1 from jsonb_populate_recordset(null::public.freights,p_freights) f where f.id=i.freight_id))
    or exists (select 1 from jsonb_populate_recordset(null::public.freight_charges,p_charges) c
      where c.added_by is distinct from auth.uid() or c.amount < 0
        or c.kind not in ('extra_freight','labour','detention')
        or not exists (select 1 from jsonb_populate_recordset(null::public.invoices,p_invoices) i
          where i.id=c.invoice_id and i.freight_id=c.freight_id)) then
    raise exception 'Import validation failed; no rows were imported';
  end if;
  insert into public.historical_import_batches(source_key,source_name,row_count,created_by,metadata)
    values(v_key,p_source_name,jsonb_array_length(p_invoices),auth.uid(),jsonb_build_object('weight_unit','metric_ton','importer','csv-v1'))
    returning id into v_batch;
  insert into public.freights (id, created_by, origin, destination_town, cases, weight_kg, internal_calling_bid, status, winner_profile_id, vehicle_number, gr_bilty_number, vehicle_capacity_category, dispatched_at, locked_at, remarks, delivery_stages, company_name, party_name, bill_date, dispatch_date, vehicle_type, source_branch, ack_status, ack_received_at, pod_received_date, pod_received_by, record_origin, data_completeness, import_batch_id, import_metadata)
    select r.id, r.created_by, r.origin, r.destination_town, r.cases, r.weight_kg, r.internal_calling_bid, r.status, r.winner_profile_id, r.vehicle_number, r.gr_bilty_number, r.vehicle_capacity_category, r.dispatched_at, r.locked_at, r.remarks, r.delivery_stages, r.company_name, r.party_name, r.bill_date, r.dispatch_date, r.vehicle_type, r.source_branch, r.ack_status, r.ack_received_at, r.pod_received_date, r.pod_received_by, 'historical_import', 'partial', v_batch, jsonb_build_object('source_key',v_key,'weight_unit','metric_ton')
    from jsonb_populate_recordset(null::public.freights,p_freights) r;
  insert into public.invoices (id, freight_id, invoice_number, gr_number, transporter_id, town, weight_kg, cases, base_freight, freight_share, validated, e_way_bill_number, party_name, bill_date, dispatch_date, lr_number, vehicle_number, vehicle_type, remarks, delivery_reference)
    select r.id, r.freight_id, r.invoice_number, r.gr_number, r.transporter_id, r.town, r.weight_kg, r.cases, r.base_freight, r.freight_share, r.validated, r.e_way_bill_number, r.party_name, r.bill_date, r.dispatch_date, r.lr_number, r.vehicle_number, r.vehicle_type, r.remarks, r.delivery_reference
    from jsonb_populate_recordset(null::public.invoices,p_invoices) r;
  insert into public.freight_charges (freight_id, invoice_id, kind, amount, remarks, added_by, approved)
    select r.freight_id, r.invoice_id, r.kind, r.amount, r.remarks, r.added_by, r.approved
    from jsonb_populate_recordset(null::public.freight_charges,p_charges) r;
  update public.historical_import_batches set status='completed',completed_at=now() where id=v_batch;
  return jsonb_build_object('already_imported',false,'batch_id',v_batch,'rows_imported',jsonb_array_length(p_invoices));
end;
$$;
revoke all on function public.import_historical_ledger_csv(text,text,jsonb,jsonb,jsonb) from public,anon;
grant execute on function public.import_historical_ledger_csv(text,text,jsonb,jsonb,jsonb) to authenticated;
comment on function public.import_historical_ledger_csv(text,text,jsonb,jsonb,jsonb) is
  'Atomic historical CSV import with content-key retry protection. Legacy weight_kg fields contain metric tons.';
