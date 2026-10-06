-- Also protect acknowledgement from direct API writes on multi-stop trips.
create or replace function private.validate_transporter_pod_references()
returns trigger language plpgsql security invoker set search_path = ''
as $$
declare
  proof_path text;
  has_proof boolean := false;
  stop_count integer;
  required_stop integer;
begin
  if (select public.current_role()) is distinct from 'transporter'::public.user_role then
    return new;
  end if;
  for proof_path in
    select distinct nullif(btrim(path), '')
    from (
      select new.pod_file_path as path
      union all
      select new.delivery_stages #>> '{delivered,pod_photo_path}'
      union all
      select item->>'pod_photo_path'
      from jsonb_array_elements(case
        when jsonb_typeof(new.delivery_stages->'delivered_stops') = 'array'
          then new.delivery_stages->'delivered_stops'
        else '[]'::jsonb end) as stops(item)
    ) proofs
    where nullif(btrim(path), '') is not null
  loop
    if split_part(proof_path, '/', 1) <> (select auth.uid())::text
       or split_part(proof_path, '/', 2) <> new.id::text
       or not exists (
         select 1 from storage.objects o
         where o.bucket_id='delivery-documents' and o.name=proof_path
       ) then
      raise exception 'Upload the POD under this dispatch before recording receipt'
        using errcode='22023';
    end if;
    has_proof := true;
  end loop;
  if new.ack_status='received' and has_proof then
    stop_count := case
      when jsonb_typeof(new.stop_details)='array' and jsonb_array_length(new.stop_details)>0
        then jsonb_array_length(new.stop_details)
      else coalesce(cardinality(new.stops),0)+1 end;
    if stop_count>1 then
      for required_stop in 0..stop_count-1 loop
        if not exists (
          select 1 from jsonb_array_elements(case
            when jsonb_typeof(new.delivery_stages->'delivered_stops')='array'
              then new.delivery_stages->'delivered_stops'
            else '[]'::jsonb end) as stops(item)
          where (item->>'stop_index')::integer=required_stop
            and nullif(btrim(item->>'pod_photo_path'),'') is not null
        ) then
          raise exception 'Every destination requires POD before acknowledgement is received'
            using errcode='22023';
        end if;
      end loop;
    end if;
  end if;
  if new.ack_status='received' and not has_proof then
    -- Preserve an office-audited manual receipt on an unrelated delivery edit.
    if tg_op='UPDATE' and old.ack_status='received'
       and old.pod_received_by is not null
       and old.pod_received_by is distinct from (select auth.uid())
       and new.pod_received_by is not distinct from old.pod_received_by
       and new.pod_received_date is not distinct from old.pod_received_date
       and new.ack_received_at is not distinct from old.ack_received_at then
      return new;
    end if;
    raise exception 'POD receipt requires uploaded proof or an audited office acknowledgement'
      using errcode='22023';
  end if;
  return new;
end
$$;
revoke all on function private.validate_transporter_pod_references()
  from public, anon, authenticated;

