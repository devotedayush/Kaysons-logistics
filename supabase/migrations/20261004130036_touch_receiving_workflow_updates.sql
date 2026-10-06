-- Notify the existing freight subscription after receiving child mutations.
-- Existing public RPC signatures, private grants, and integrity guards stay intact.
create or replace function private.delivery_workflow_mutate(p_action text,p_id uuid,p_data jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); role_name text:=public.current_role()::text;
 f public.freights; r public.freight_delivery_receivers; c public.freight_expense_claims;
 item jsonb; details jsonb; report_data jsonb; paths jsonb; outcome text; decision text;
 idx integer; expected_town text; charge uuid; all_received boolean;
begin
 if uid is null or role_name is null then raise exception 'Approved account required' using errcode='42501'; end if;
 if p_action in ('report','pod') then
  select * into r from public.freight_delivery_receivers where id=p_id;
  select * into f from public.freights where id=r.freight_id for update;
  -- Lock parent first for every mutation; re-read child after waiting.
  select * into r from public.freight_delivery_receivers where id=p_id for update;
 elsif p_action='expense_review' then
  select * into c from public.freight_expense_claims where id=p_id;
  select * into f from public.freights where id=c.freight_id for update;
  select * into c from public.freight_expense_claims where id=p_id for update;
 else select * into f from public.freights where id=p_id for update;
 end if;
 if f.id is null or not private.delivery_workflow_can_read(f.id) then raise exception 'Dispatch access denied' using errcode='42501'; end if;
 if p_action in ('ensure','plan') and role_name not in ('admin','logistics_manager') then raise exception 'Office manages receiving plan' using errcode='42501'; end if;
 if p_action in ('pod','expense_review') and role_name not in ('admin','logistics_manager','accountant') then raise exception 'Office review required' using errcode='42501'; end if;
 if p_action in ('report','journey','expense') and (role_name<>'transporter' or f.winner_profile_id<>uid) then raise exception 'Assigned transporter required' using errcode='42501'; end if;
 if p_action in ('report','journey','expense') and f.status::text not in ('dispatched','locked','completed') then raise exception 'Dispatch the assigned vehicle before recording trip activity' using errcode='22023'; end if;
 if p_action='ensure' then
  if exists(select 1 from public.freight_delivery_receivers where freight_id=f.id) then return; end if;
  details:=case when jsonb_typeof(f.stop_details)='array' and jsonb_array_length(f.stop_details)>0 then f.stop_details else '[]'::jsonb end;
  if jsonb_array_length(details)=0 then
   details:='[]'::jsonb;
   for item in select to_jsonb(t) from unnest(coalesce(f.stops,'{}'::text[])) t loop details:=details||jsonb_build_array(jsonb_build_object('name',item#>>'{}')); end loop;
   details:=details||jsonb_build_array(jsonb_build_object('name',f.destination_town,'cases',case when coalesce(cardinality(f.stops),0)=0 then f.cases end,'weight_kg',case when coalesce(cardinality(f.stops),0)=0 then f.weight_kg end));
  end if;
  idx:=0;
  for item in select * from jsonb_array_elements(details) loop
   insert into public.freight_delivery_receivers(freight_id,stop_index,town,party_name,planned_cases,planned_weight_mt)
   values(f.id,idx,coalesce(nullif(btrim(item->>'name'),''),f.destination_town),coalesce(f.party_name,''),nullif(item->>'cases','')::integer,nullif(item->>'weight_kg','')::numeric);
   idx:=idx+1;
  end loop;
  update public.freights set updated_at=now(),delivery_workflow_version=1,ack_status='pending',ack_received_at=null,pod_received_by=null,pod_received_date=null where id=f.id;
  return;
 end if;
 if f.delivery_workflow_version<>1 then raise exception 'Office must initialize receiving plan first'; end if;
 if p_action='plan' then
  if jsonb_typeof(p_data->'receivers') is distinct from 'array' or jsonb_array_length(p_data->'receivers')=0 then raise exception 'At least one customer required'; end if;
  if exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and report<>'{}') or exists(select 1 from public.freight_expense_claims where freight_id=f.id and receiver_id is not null) then raise exception 'Plan is fixed after reports or allocated expenses'; end if;
  delete from public.freight_delivery_receivers where freight_id=f.id;
  for item in select * from jsonb_array_elements(p_data->'receivers') loop
   idx:=(item->>'stop_index')::integer;
   if idx is null or idx<0 or idx>=(case when jsonb_typeof(f.stop_details)='array' and jsonb_array_length(f.stop_details)>0 then jsonb_array_length(f.stop_details) else coalesce(cardinality(f.stops),0)+1 end) then raise exception 'Invalid stop index'; end if;
   expected_town:=case when jsonb_typeof(f.stop_details)='array' and jsonb_array_length(f.stop_details)>0 then coalesce(nullif(btrim(f.stop_details->idx->>'name'),''),f.destination_town) when idx<coalesce(cardinality(f.stops),0) then f.stops[idx+1] else f.destination_town end;
   if btrim(item->>'town') is distinct from btrim(expected_town) then raise exception 'Customer town must match its planned route stop'; end if;
   insert into public.freight_delivery_receivers(freight_id,stop_index,town,party_name,planned_cases,planned_weight_mt,gr_numbers,lr_numbers,e_way_bill_numbers)
   values(f.id,idx,item->>'town',coalesce(item->>'party_name',''),nullif(item->>'planned_cases','')::integer,nullif(item->>'planned_weight_mt','')::numeric,
    array(select jsonb_array_elements_text(coalesce(item->'gr_numbers','[]'))),array(select jsonb_array_elements_text(coalesce(item->'lr_numbers','[]'))),array(select jsonb_array_elements_text(coalesce(item->'e_way_bill_numbers','[]'))));
  end loop;
  -- Allocations either remain unknown (all NULL), or exactly partition
  -- the office-planned stop quantities. Mixed known/unknown allocations fail.
  details:=case when jsonb_typeof(f.stop_details)='array' and jsonb_array_length(f.stop_details)>0 then f.stop_details else case when coalesce(cardinality(f.stops),0)=0 then jsonb_build_array(jsonb_build_object('cases',f.cases,'weight_kg',f.weight_kg)) else '[]'::jsonb end end;
  idx:=0;
  for item in select * from jsonb_array_elements(details) loop
   if nullif(item->>'cases','') is not null and exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and stop_index=idx and planned_cases is not null) then
    if exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and stop_index=idx and planned_cases is null)
      or (select sum(planned_cases) from public.freight_delivery_receivers where freight_id=f.id and stop_index=idx) is distinct from (item->>'cases')::integer then raise exception 'Customer cases must total the planned stop cases'; end if;
   end if;
   if nullif(item->>'weight_kg','') is not null and exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and stop_index=idx and planned_weight_mt is not null) then
    if exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and stop_index=idx and planned_weight_mt is null)
      or (select sum(planned_weight_mt) from public.freight_delivery_receivers where freight_id=f.id and stop_index=idx) is distinct from (item->>'weight_kg')::numeric then raise exception 'Customer MT must total the planned stop MT'; end if;
   end if;
   idx:=idx+1;
  end loop;
  for idx in 0..(case when jsonb_typeof(f.stop_details)='array' and jsonb_array_length(f.stop_details)>0 then jsonb_array_length(f.stop_details) else coalesce(cardinality(f.stops),0)+1 end)-1 loop
   if not exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and stop_index=idx) then raise exception 'Every stop needs a customer'; end if;
  end loop;
 elsif p_action='report' then
  -- Whitelist transporter fields; preserve existing attachments on metadata edits.
  report_data:=r.report;
  if p_data->>'outcome'='full' and r.report->>'outcome' is distinct from 'full' then report_data:=report_data-array['cases_received','weight_received_mt','cases_damaged','cases_rejected','discrepancy_reason']; end if;
  report_data:=report_data||(select coalesce(jsonb_object_agg(key,value),'{}') from jsonb_each(p_data) where key=any(array['recipient_name','recipient_phone','delivered_at','outcome','cases_received','weight_received_mt','discrepancy_reason','proof_paths','site_photo_paths','cases_damaged','cases_rejected']));
  outcome:=report_data->>'outcome';
  if outcome is null or outcome not in ('full','partial','refused','attempted') or nullif(btrim(report_data->>'recipient_name'),'') is null or nullif(report_data->>'delivered_at','') is null then raise exception 'Receiver, actual delivery time, and outcome required'; end if;
  if (report_data->>'delivered_at')::timestamptz>now()+interval '5 minutes' then raise exception 'Actual delivery time cannot be in the future'; end if;
  if outcome<>'full' and nullif(report_data->>'cases_received','') is null then raise exception 'Non-full delivery requires explicit received cases'; end if;
  if r.planned_cases is not null and coalesce((report_data->>'cases_received')::integer,0)>r.planned_cases then raise exception 'Received cases exceed planned allocation'; end if;
  if r.planned_weight_mt is not null and coalesce((report_data->>'weight_received_mt')::numeric,0)>r.planned_weight_mt then raise exception 'Received MT exceed planned allocation'; end if;
  if coalesce((report_data->>'cases_received')::integer,0)<0 or coalesce((report_data->>'weight_received_mt')::numeric,0)<0 then raise exception 'Received quantities cannot be negative'; end if;
  if coalesce((report_data->>'cases_damaged')::integer,0)>0 or coalesce((report_data->>'cases_rejected')::integer,0)>0 or outcome<>'full' or (report_data?'cases_received' and r.planned_cases is not null and (report_data->>'cases_received')::integer is distinct from r.planned_cases) or (report_data?'weight_received_mt' and r.planned_weight_mt is not null and (report_data->>'weight_received_mt')::numeric is distinct from r.planned_weight_mt) then
   if nullif(btrim(report_data->>'discrepancy_reason'),'') is null then raise exception 'Explain partial, failed or discrepant delivery'; end if;
  end if;
  paths:=coalesce(report_data->'proof_paths','[]'); perform private.delivery_workflow_check_paths(f.id,paths);
  perform private.delivery_workflow_check_paths(f.id,coalesce(report_data->'site_photo_paths','[]'));
  if r.planned_cases is not null and (coalesce((report_data->>'cases_damaged')::integer,0)>r.planned_cases or coalesce((report_data->>'cases_rejected')::integer,0)>r.planned_cases) then raise exception 'Exception cases exceed planned allocation'; end if;
  if coalesce((report_data->>'cases_damaged')::integer,0)<0 or coalesce((report_data->>'cases_rejected')::integer,0)<0 then raise exception 'Exception quantities cannot be negative'; end if;
  if outcome='full' and (coalesce((report_data->>'cases_damaged')::integer,0)>0 or coalesce((report_data->>'cases_rejected')::integer,0)>0 or (report_data?'cases_received' and r.planned_cases is not null and (report_data->>'cases_received')::integer is distinct from r.planned_cases) or (report_data?'weight_received_mt' and r.planned_weight_mt is not null and (report_data->>'weight_received_mt')::numeric is distinct from r.planned_weight_mt)) then raise exception 'Use partial outcome for quantity discrepancies'; end if;

  update public.freight_delivery_receivers set report=report_data||jsonb_build_object('submitted_at',now()),pod_review_status='pending',pod_review_note=null,reviewed_by=null,reviewed_at=null,updated_at=now() where id=r.id;
  update public.freights set ack_status='pending',ack_received_at=null,pod_received_by=null,pod_received_date=null where id=f.id;
 elsif p_action='pod' then
  decision:=p_data->>'decision'; if decision is null or decision not in ('accepted','rejected') then raise exception 'Invalid POD decision'; end if;
  if r.report='{}' then raise exception 'No delivery report to review'; end if;
  paths:=coalesce(r.report->'proof_paths','[]'); perform private.delivery_workflow_check_paths(f.id,paths);
  if decision='accepted' and r.report->>'outcome' is distinct from 'full' then raise exception 'Resolve partial, refused or attempted delivery before accepting POD'; end if;
  if decision='accepted' and jsonb_array_length(paths)=0 then raise exception 'POD proof required for acceptance'; end if;
  if decision='rejected' and nullif(btrim(p_data->>'note'),'') is null then raise exception 'Rejection reason required'; end if;
  update public.freight_delivery_receivers set pod_review_status=decision,pod_review_note=p_data->>'note',reviewed_by=uid,reviewed_at=now(),updated_at=now() where id=r.id;
  select count(*)>0 and bool_and(pod_review_status='accepted' and coalesce(report->>'outcome','')='full') into all_received from public.freight_delivery_receivers where freight_id=f.id;
  update public.freights set status=case when all_received and status::text in ('dispatched','locked') then 'completed'::public.freight_status else status end,ack_status=case when all_received then 'received' else 'pending' end,ack_received_at=case when all_received then now() end,pod_received_by=case when all_received then uid end,pod_received_date=case when all_received then current_date end where id=f.id;
 elsif p_action='journey' then
  details:=(select coalesce(jsonb_object_agg(key,value),'{}') from jsonb_each(p_data) where key=any(array['location','next_destination','eta','delay_reason','contractor_name','contractor_phone','vehicle_number','photo_paths','occurred_at','contractors']));
  if nullif(btrim(details->>'location'),'') is null then raise exception 'Current location required'; end if;
  if details?'eta' and nullif(details->>'eta','') is not null then perform (details->>'eta')::timestamptz; end if;
  if details?'occurred_at' and nullif(details->>'occurred_at','') is not null then perform (details->>'occurred_at')::timestamptz; end if;
  perform private.delivery_workflow_check_paths(f.id,coalesce(details->'photo_paths','[]'));
  if details?'contractors' then
   if jsonb_typeof(details->'contractors') is distinct from 'array' then raise exception 'Contractors must be an array'; end if;
   for item in select * from jsonb_array_elements(details->'contractors') loop
    if nullif(btrim(item->>'name'),'') is null then raise exception 'Contractor name required'; end if;
    if nullif(item->>'from','') is not null and not (item->>'from'=f.origin or item->>'from'=f.destination_town or item->>'from'=any(coalesce(f.stops,'{}'::text[])) or exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and town=item->>'from')) then raise exception 'Contractor origin must be an existing route location'; end if;
    if nullif(item->>'to','') is not null and not (item->>'to'=f.origin or item->>'to'=f.destination_town or item->>'to'=any(coalesce(f.stops,'{}'::text[])) or exists(select 1 from public.freight_delivery_receivers where freight_id=f.id and town=item->>'to')) then raise exception 'Contractor destination must be an existing route location'; end if;
   end loop;
  end if;
  insert into public.freight_journey_updates(freight_id,data,submitted_by) values(f.id,details,uid);
 elsif p_action='expense' then
  if nullif(p_data->>'receiver_id','') is not null and not exists(select 1 from public.freight_delivery_receivers where id=(p_data->>'receiver_id')::uuid and freight_id=f.id) then raise exception 'Receiver is outside this dispatch'; end if;
  perform private.delivery_workflow_check_paths(f.id,coalesce(p_data->'receipt_paths','[]'));
  insert into public.freight_expense_claims(freight_id,receiver_id,kind,amount,reason,receipt_paths,submitted_by) values(f.id,nullif(p_data->>'receiver_id','')::uuid,p_data->>'kind',(p_data->>'amount')::numeric,p_data->>'reason',array(select jsonb_array_elements_text(coalesce(p_data->'receipt_paths','[]'))),uid);
 elsif p_action='expense_review' then
  decision:=p_data->>'decision'; if decision is null or decision not in ('approved','rejected') then raise exception 'Invalid expense decision'; end if;
  if c.status='approved' and decision='approved' then return; end if;
  if c.status<>'pending' then raise exception 'Reviewed claim is immutable'; end if;
  if decision='rejected' and nullif(btrim(p_data->>'note'),'') is null then raise exception 'Rejection reason required'; end if;
  if decision='approved' then
   perform private.delivery_workflow_check_paths(f.id,to_jsonb(c.receipt_paths));
   insert into public.freight_charges(freight_id,kind,amount,remarks,added_by,approved,added_after_lock) values(f.id,c.kind,c.amount,c.reason,uid,true,f.status::text in ('locked','completed')) returning id into charge;
  end if;
  update public.freight_expense_claims set status=decision,review_note=p_data->>'note',reviewed_by=uid,reviewed_at=now(),charge_id=charge where id=c.id;
 else raise exception 'Unknown workflow action';
 end if;
 -- Publish child-only writes through the parent's existing Realtime stream.
 -- Row and approved-role guards still apply to this timestamp-only update.
 if p_action in ('plan','journey','expense','expense_review') then
  update public.freights set updated_at=now() where id=f.id;
 end if;
end $$;
