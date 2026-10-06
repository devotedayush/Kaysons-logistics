-- Record one destination at a time without overwriting another stop's proof.
create or replace function public.save_delivered_stop(
  p_freight_id uuid,
  p_stop_index integer,
  p_data jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  freight_row public.freights%rowtype;
  expected_stops jsonb;
  expected_name text;
  saved_stops jsonb;
  previous_stop jsonb;
  stages jsonb;
  submitted_at timestamptz := now();
  delivered_count integer;
  stop_count integer;
  complete boolean;
  all_pods_received boolean;
  first_pod_path text;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in to update a delivery' using errcode = '42501';
  end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'Delivery details must be an object' using errcode = '22023';
  end if;

  select * into freight_row
  from public.freights
  where id = p_freight_id
  for update;
  if not found then
    raise exception 'Freight not found' using errcode = 'P0002';
  end if;
  if freight_row.record_origin <> 'live'
     or freight_row.winner_profile_id is distinct from (select auth.uid())
     or (select public.current_role()) <> 'transporter'::public.user_role then
    raise exception 'Only the awarded transporter can update this delivery'
      using errcode = '42501';
  end if;
  if freight_row.status not in (
    'dispatched'::public.freight_status,
    'locked'::public.freight_status,
    'completed'::public.freight_status
  ) then
    raise exception 'Dispatch must start before delivery can be reported'
      using errcode = '42501';
  end if;

  if jsonb_typeof(freight_row.stop_details) = 'array'
     and jsonb_array_length(freight_row.stop_details) > 0 then
    expected_stops := freight_row.stop_details;
  else
    expected_stops := coalesce(to_jsonb(freight_row.stops), '[]'::jsonb)
      || jsonb_build_array(freight_row.destination_town);
  end if;
  stop_count := jsonb_array_length(expected_stops);
  if stop_count < 2 or p_stop_index < 0 or p_stop_index >= stop_count then
    raise exception 'This dispatch does not have that delivery stop'
      using errcode = '22023';
  end if;
  expected_name := case
    when jsonb_typeof(expected_stops->p_stop_index) = 'object'
      then expected_stops->p_stop_index->>'name'
    else expected_stops->>p_stop_index
  end;
  if nullif(btrim(expected_name), '') is null
     or btrim(coalesce(p_data->>'destination', '')) <> btrim(expected_name) then
    raise exception 'Delivery destination does not match the dispatch stop'
      using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_data->>'receiver_name', '')), '') is null then
    raise exception 'Receiver name is required for a delivery update'
      using errcode = '22023';
  end if;
  if p_data ? 'stop_index' and (p_data->>'stop_index')::integer <> p_stop_index then
    raise exception 'Delivery stop index does not match'
      using errcode = '22023';
  end if;

  saved_stops := coalesce(freight_row.delivery_stages->'delivered_stops', '[]'::jsonb);
  if jsonb_typeof(saved_stops) <> 'array' then
    raise exception 'Saved delivery stops are invalid' using errcode = '22023';
  end if;
  select value into previous_stop
  from jsonb_array_elements(saved_stops) as existing(value)
  where (value->>'stop_index')::integer = p_stop_index
  limit 1;
  select coalesce(jsonb_agg(item order by (item->>'stop_index')::integer), '[]'::jsonb)
    into saved_stops
  from (
    select value as item
    from jsonb_array_elements(saved_stops) as existing(value)
    where (value->>'stop_index')::integer <> p_stop_index
    union all
    -- Office invoice references remain intact on later transporter updates.
    -- Transporters can update delivery/GR/POD details, not office invoice data.
    select coalesce(previous_stop, '{}'::jsonb)
      || (p_data - 'submitted_at' - 'invoice_numbers' - 'invoice_number' - 'invoice_photo_path')
      || jsonb_build_object(
      'stop_index', p_stop_index,
      'destination', expected_name,
      'submitted_at', submitted_at
    )
  ) merged;

  select count(distinct (item->>'stop_index')::integer)
    into delivered_count
  from jsonb_array_elements(saved_stops) as delivered(item)
  where (item->>'stop_index')::integer between 0 and stop_count - 1;
  complete := delivered_count = stop_count;
  all_pods_received := complete and not exists (
    select 1
    from jsonb_array_elements(saved_stops) as delivered(item)
    where nullif(btrim(coalesce(item->>'pod_photo_path', '')), '') is null
  );
  first_pod_path := saved_stops->0->>'pod_photo_path';
  stages := jsonb_set(
    coalesce(freight_row.delivery_stages, '{}'::jsonb),
    '{delivered_stops}',
    saved_stops,
    true
  );

  update public.freights
  set delivery_stages = stages,
      status = case when complete then 'completed'::public.freight_status else status end,
      ack_status = case
        when complete and all_pods_received then 'received'
        when complete then 'pending'
        else ack_status
      end,
      ack_received_at = case when all_pods_received then submitted_at else null end,
      pod_received_date = case when all_pods_received then submitted_at::date else null end,
      pod_file_path = case when all_pods_received then first_pod_path else null end,
      pod_received_by = case when all_pods_received then (select auth.uid()) else null end
  where id = p_freight_id;

  return jsonb_build_object(
    'delivered_stops', saved_stops,
    'complete', complete,
    'all_pods_received', all_pods_received,
    'newly_completed', complete and freight_row.status <> 'completed'::public.freight_status
  );
end;
$$;

revoke all on function public.save_delivered_stop(uuid, integer, jsonb)
  from public, anon;
grant execute on function public.save_delivered_stop(uuid, integer, jsonb)
  to authenticated;
