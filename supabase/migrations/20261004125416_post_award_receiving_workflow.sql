-- Additive receiving workflow. Existing historical/legacy trips are not regrouped.
alter table public.freights add column delivery_workflow_version integer not null default 0;
create table public.freight_delivery_receivers (
 id uuid primary key default gen_random_uuid(), freight_id uuid not null references public.freights(id),
 stop_index integer not null check(stop_index>=0), town text not null check(btrim(town)<>''),
 party_name text not null default '', planned_cases integer check(planned_cases>=0),
 planned_weight_mt numeric check(planned_weight_mt>=0), gr_numbers text[] not null default '{}',
 lr_numbers text[] not null default '{}', e_way_bill_numbers text[] not null default '{}',
 report jsonb not null default '{}', pod_review_status text not null default 'pending' check(pod_review_status in ('pending','accepted','rejected')),
 pod_review_note text, reviewed_by uuid references public.profiles(id), reviewed_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index freight_delivery_receivers_freight_idx on public.freight_delivery_receivers(freight_id,stop_index);
create index freight_delivery_receivers_reviewer_idx on public.freight_delivery_receivers(reviewed_by);
create table public.freight_journey_updates (
 id uuid primary key default gen_random_uuid(), freight_id uuid not null references public.freights(id),
 data jsonb not null, submitted_by uuid not null references public.profiles(id), submitted_at timestamptz not null default now()
);
create index freight_journey_updates_freight_idx on public.freight_journey_updates(freight_id,submitted_at);
create index freight_journey_updates_submitter_idx on public.freight_journey_updates(submitted_by);
create table public.freight_expense_claims (
 id uuid primary key default gen_random_uuid(), freight_id uuid not null references public.freights(id),
 receiver_id uuid references public.freight_delivery_receivers(id), kind text not null check(kind in ('labour','detention','toll_tax','extra_freight','out_route','point_charge','other')),
 amount numeric not null check(amount>0), reason text not null check(btrim(reason)<>''), receipt_paths text[] not null default '{}',
 status text not null default 'pending' check(status in ('pending','approved','rejected')), review_note text,
 submitted_by uuid not null references public.profiles(id), submitted_at timestamptz not null default now(),
 reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, charge_id uuid unique references public.freight_charges(id)
);
create index freight_expense_claims_freight_idx on public.freight_expense_claims(freight_id,submitted_at);
create index freight_expense_claims_receiver_idx on public.freight_expense_claims(receiver_id);
create index freight_expense_claims_submitter_idx on public.freight_expense_claims(submitted_by);
create index freight_expense_claims_reviewer_idx on public.freight_expense_claims(reviewed_by);

-- Private authority boundary: no Data API writes to workflow tables. Every
-- mutation goes through the narrow worker with explicit approved-role checks.
create function private.delivery_workflow_can_read(p_freight_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.freights f join public.profiles p on p.id=auth.uid()
 where f.id=p_freight_id and p.status::text='approved' and f.record_origin='live'
 and f.status::text in ('awarded','dispatched','locked','completed')
 and (p.role::text in ('admin','logistics_manager','accountant')
 or (p.role::text='transporter' and f.winner_profile_id=p.id)
 or (p.role::text='dispatch_manager' and f.created_by=p.manager_id and exists(select 1 from public.profiles manager where manager.id=p.manager_id and manager.status::text='approved' and manager.role::text='logistics_manager'))))
$$;
revoke all on function private.delivery_workflow_can_read(uuid) from public,anon;
grant execute on function private.delivery_workflow_can_read(uuid) to authenticated;
alter table public.freight_delivery_receivers enable row level security;
alter table public.freight_journey_updates enable row level security;
alter table public.freight_expense_claims enable row level security;
revoke all on public.freight_delivery_receivers,public.freight_journey_updates,public.freight_expense_claims from public,anon,authenticated;
grant select on public.freight_delivery_receivers,public.freight_journey_updates,public.freight_expense_claims to authenticated;
create policy workflow_receivers_read on public.freight_delivery_receivers for select to authenticated using(private.delivery_workflow_can_read(freight_id));
create policy workflow_journey_read on public.freight_journey_updates for select to authenticated using(private.delivery_workflow_can_read(freight_id));
create policy workflow_expenses_read on public.freight_expense_claims for select to authenticated using(private.delivery_workflow_can_read(freight_id));

create function private.delivery_workflow_check_paths(p_freight_id uuid,p_paths jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare path text; winner uuid;
begin
 if not private.delivery_workflow_can_read(p_freight_id) then raise exception 'Dispatch access denied' using errcode='42501'; end if;
 if jsonb_typeof(p_paths) is distinct from 'array' then raise exception 'Proof paths must be an array' using errcode='22023'; end if;
 select winner_profile_id into winner from public.freights where id=p_freight_id;
 if jsonb_array_length(p_paths)>20 then raise exception 'Maximum 20 attachments' using errcode='22023'; end if;
 for path in select jsonb_array_elements_text(p_paths) loop
  if path is null or split_part(path,'/',1) is distinct from winner::text
   or split_part(path,'/',2) is distinct from p_freight_id::text
   or path ~ '(^|/)\.\.(/|$)' or path !~* '\.(pdf|png|jpe?g|webp)$'
   or not exists(select 1 from storage.objects where bucket_id='delivery-documents' and name=path)
  then raise exception 'Upload image/PDF proof under the assigned transporter/dispatch path first' using errcode='22023'; end if;
 end loop;
end $$;
revoke all on function private.delivery_workflow_check_paths(uuid,jsonb) from public,anon,authenticated;

-- Enforce completion against receiver rows for every API, including legacy writes.
-- Accepted receiver reports are written exclusively by the private worker.
create function private.guard_receiving_ack() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.delivery_workflow_version=1 and new.delivery_workflow_version<>1 then raise exception 'Receiving workflow cannot be disabled'; end if;
 if new.delivery_workflow_version=1 then
  if new.ack_status='received' and (not exists(select 1 from public.freight_delivery_receivers where freight_id=new.id)
    or exists(select 1 from public.freight_delivery_receivers where freight_id=new.id and (pod_review_status<>'accepted' or report->>'outcome' is distinct from 'full')))
  then raise exception 'All customers require full delivery and office-accepted POD' using errcode='22023'; end if;
  if public.current_role()::text='transporter' and (new.ack_status is distinct from old.ack_status or new.pod_received_by is distinct from old.pod_received_by or new.pod_received_date is distinct from old.pod_received_date or new.ack_received_at is distinct from old.ack_received_at) and new.ack_status='received'
  then raise exception 'Only office review acknowledges receiving' using errcode='42501'; end if;
  if new.status::text='completed' and old.status::text<>'completed' and new.ack_status<>'received'
  then raise exception 'Receiving review is pending' using errcode='22023'; end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_receiving_ack() from public,anon,authenticated;
create trigger guard_receiving_ack before update on public.freights for each row execute function private.guard_receiving_ack();

create function private.delivery_workflow_mutate(p_action text,p_id uuid,p_data jsonb default '{}') returns void
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
  update public.freights set delivery_workflow_version=1,ack_status='pending',ack_received_at=null,pod_received_by=null,pod_received_date=null where id=f.id;
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
end $$;
revoke all on function private.delivery_workflow_mutate(text,uuid,jsonb) from public,anon;
grant execute on function private.delivery_workflow_mutate(text,uuid,jsonb) to authenticated;

create function public.ensure_delivery_plan(p_freight_id uuid) returns void language sql security invoker set search_path='' as $$ select private.delivery_workflow_mutate('ensure',p_freight_id,'{}') $$;
create function public.save_delivery_plan(p_freight_id uuid,p_receivers jsonb) returns void language sql security invoker set search_path='' as $$ select private.delivery_workflow_mutate('plan',p_freight_id,jsonb_build_object('receivers',p_receivers)) $$;
create function public.save_delivery_report(p_receiver_id uuid,p_data jsonb) returns void language sql security invoker set search_path='' as $$ select private.delivery_workflow_mutate('report',p_receiver_id,p_data) $$;
create function public.review_delivery_pod(p_receiver_id uuid,p_decision text,p_note text default null) returns void language sql security invoker set search_path='' as $$ select private.delivery_workflow_mutate('pod',p_receiver_id,jsonb_build_object('decision',p_decision,'note',p_note)) $$;
create function public.add_journey_update(p_freight_id uuid,p_data jsonb) returns void language sql security invoker set search_path='' as $$ select private.delivery_workflow_mutate('journey',p_freight_id,p_data) $$;
create function public.submit_freight_expense(p_freight_id uuid,p_data jsonb) returns void language sql security invoker set search_path='' as $$ select private.delivery_workflow_mutate('expense',p_freight_id,p_data) $$;
create function public.review_freight_expense(p_claim_id uuid,p_decision text,p_note text default null) returns void language sql security invoker set search_path='' as $$ select private.delivery_workflow_mutate('expense_review',p_claim_id,jsonb_build_object('decision',p_decision,'note',p_note)) $$;
revoke execute on function public.ensure_delivery_plan(uuid),public.save_delivery_plan(uuid,jsonb),public.save_delivery_report(uuid,jsonb),public.review_delivery_pod(uuid,text,text),public.add_journey_update(uuid,jsonb),public.submit_freight_expense(uuid,jsonb),public.review_freight_expense(uuid,text,text) from public,anon;
grant execute on function public.ensure_delivery_plan(uuid),public.save_delivery_plan(uuid,jsonb),public.save_delivery_report(uuid,jsonb),public.review_delivery_pod(uuid,text,text),public.add_journey_update(uuid,jsonb),public.submit_freight_expense(uuid,jsonb),public.review_freight_expense(uuid,text,text) to authenticated;

create policy workflow_accountant_proof_read on storage.objects for select to authenticated using(bucket_id='delivery-documents' and public.current_role()::text='accountant' and exists(select 1 from public.freights f where f.id::text=split_part(name,'/',2) and f.winner_profile_id::text=split_part(name,'/',1) and private.delivery_workflow_can_read(f.id)));

-- Opt future live awards in; leave existing/historical records as-is.
create function private.initialize_awarded_receiving() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.record_origin='live' and new.status::text='awarded' and new.winner_profile_id is not null
 and (tg_op='INSERT' or old.status::text is distinct from 'awarded') then
  perform private.delivery_workflow_mutate('ensure',new.id,'{}');
 end if;
 return new;
end $$;
revoke all on function private.initialize_awarded_receiving() from public,anon,authenticated;
create trigger initialize_awarded_receiving after insert or update of status on public.freights
for each row execute function private.initialize_awarded_receiving();

-- Accountant status advancement is restricted to authoritative accepted receiver rows.
create or replace function private.prevent_accountant_freight_columns()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.current_role()::text is distinct from 'accountant' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.created_by is distinct from (select auth.uid())
       or not (
         (new.record_origin = 'live'
          and new.status = 'locked'::public.freight_status)
         or (new.record_origin = 'historical_import'
             and new.import_batch_id is not null
             and new.status in (
               'locked'::public.freight_status,
               'completed'::public.freight_status
             ))
       ) then
      raise exception 'Accountants may only insert manual locked or historical rows'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if old.record_origin = 'historical_import' then
    if new.id is distinct from old.id
       or new.created_by is distinct from old.created_by
       or new.record_origin is distinct from old.record_origin
       or new.data_completeness is distinct from old.data_completeness
       or new.import_batch_id is distinct from old.import_batch_id
       or new.import_metadata is distinct from old.import_metadata
       or new.status is distinct from old.status then
      raise exception 'Historical freight provenance and status are immutable'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if (new.status is distinct from old.status and not (
       old.delivery_workflow_version=1 and new.delivery_workflow_version=1
       and old.status::text in ('dispatched','locked') and new.status::text='completed'
       and new.ack_status='received'
       and exists(select 1 from public.freight_delivery_receivers where freight_id=new.id)
       and not exists(select 1 from public.freight_delivery_receivers where freight_id=new.id and (pod_review_status<>'accepted' or report->>'outcome' is distinct from 'full'))
     ))
     or (to_jsonb(new) - array[
          'company_name', 'party_name', 'bill_date', 'dispatch_date',
          'source_branch', 'remarks', 'gr_bilty_number', 'ack_status',
          'ack_received_at', 'pod_received_date', 'pod_file_path',
          'pod_remark', 'pod_received_by', 'updated_at', 'status'
        ]) is distinct from
        (to_jsonb(old) - array[
          'company_name', 'party_name', 'bill_date', 'dispatch_date',
          'source_branch', 'remarks', 'gr_bilty_number', 'ack_status',
          'ack_received_at', 'pod_received_date', 'pod_file_path',
          'pod_remark', 'pod_received_by', 'updated_at', 'status'
        ]) then
    raise exception 'Accountants may only update accounting and audited POD fields'
      using errcode = '42501';
  end if;
  return new;
end
$$;
