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
