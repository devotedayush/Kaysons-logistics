-- Operational integrity guards for bids, awards, invoice locking, and role writes.
-- Applied after review and verified with authenticated-role rollback regressions.

alter table public.freights
  add column if not exists accepted_freight_amount numeric;

comment on column public.freights.weight_kg is
  'Legacy column name retained for compatibility; values are metric tons in imported and operational records.';
comment on column public.invoices.weight_kg is
  'Legacy column name retained for compatibility; values are metric tons in imported and operational records.';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'freights_accepted_freight_amount_check'
      and conrelid = 'public.freights'::regclass
  ) then
    alter table public.freights
      add constraint freights_accepted_freight_amount_check
      check (
        accepted_freight_amount is null
        or (
          accepted_freight_amount > 0
          and accepted_freight_amount <> 'NaN'::numeric
          and accepted_freight_amount <> 'Infinity'::numeric
          and accepted_freight_amount <> '-Infinity'::numeric
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'bids_amount_positive_check'
      and conrelid = 'public.bids'::regclass
  ) then
    alter table public.bids
      add constraint bids_amount_positive_check
      check (
        amount > 0
        and amount <> 'NaN'::numeric
        and amount <> 'Infinity'::numeric
        and amount <> '-Infinity'::numeric
      );
  end if;
end
$$;

-- Preserve the historical column and charge payload shape while making all new
-- workflow writes use the report's canonical names.
create or replace function public.normalize_freight_charge_kind(p_kind text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case lower(btrim(p_kind))
    when 'freight' then 'freight'
    when 'extra_freight' then 'extra_freight'
    when 'labour' then 'labour'
    when 'detention' then 'detention'
    when 'toll' then 'toll_tax'
    when 'toll_tax' then 'toll_tax'
    when 'club' then 'point_charge'
    when 'dalla' then 'point_charge'
    when 'point_charge' then 'point_charge'
    when 'out_route' then 'out_route'
    when 'deduction' then 'deduction'
    when 'other' then 'other'
    else null
  end
$$;

revoke all on function public.normalize_freight_charge_kind(text)
  from public, anon, authenticated;

create or replace function private.normalize_freight_charge_kind()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.kind := public.normalize_freight_charge_kind(new.kind);
  if new.kind is null then
    raise exception 'Unsupported freight charge kind' using errcode = '22023';
  end if;

  if new.invoice_id is not null
     and not exists (
       select 1
       from public.invoices i
       where i.id = new.invoice_id
         and i.freight_id = new.freight_id
     ) then
    raise exception 'Charge invoice must belong to the same freight'
      using errcode = '23514';
  end if;
  return new;
end
$$;

revoke execute on function private.normalize_freight_charge_kind()
  from public, anon, authenticated;

drop trigger if exists normalize_freight_charge_kind on public.freight_charges;
create trigger normalize_freight_charge_kind
before insert or update of kind, freight_id, invoice_id
on public.freight_charges
for each row
execute function private.normalize_freight_charge_kind();

update public.freight_charges
set kind = public.normalize_freight_charge_kind(kind)
where kind is distinct from public.normalize_freight_charge_kind(kind);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'freight_charges_kind_check'
      and conrelid = 'public.freight_charges'::regclass
  ) then
    alter table public.freight_charges
      add constraint freight_charges_kind_check
      check (kind in (
        'freight', 'extra_freight', 'labour', 'detention', 'toll_tax',
        'point_charge', 'out_route', 'deduction', 'other'
      ));
  end if;
end
$$;

-- Copy the currently persisted winning bid into the durable accepted-price
-- column. Historical rows remain NULL and continue to use their imported price.
update public.freights f
set accepted_freight_amount = winner.amount
from public.bids winner
where winner.freight_id = f.id
  and winner.state = 'won'::public.bid_state
  and f.accepted_freight_amount is null;

create or replace function private.prevent_invalid_bid_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  freight_row public.freights;
  role_name text := public.current_role()::text;
begin
  if tg_op = 'DELETE' then
    select * into freight_row
    from public.freights f
    where f.id = old.freight_id
    for share;
    if not found then
      raise exception 'Freight is unavailable' using errcode = '23503';
    end if;
    if freight_row.status <> 'bidding'::public.freight_status
       or (freight_row.bid_closes_at is not null and now() > freight_row.bid_closes_at) then
      raise exception 'Bids cannot be deleted after the bidding window closes'
        using errcode = '42501';
    end if;
    if role_name = 'transporter'
       and old.transporter_id is distinct from (select auth.uid()) then
      raise exception 'Only the bid owner may delete a bid' using errcode = '42501';
    end if;
    return old;
  end if;

  select * into freight_row
  from public.freights f
  where f.id = new.freight_id
  for share;

  if not found then
    raise exception 'Freight is unavailable' using errcode = '23503';
  end if;

  if tg_op = 'UPDATE'
     and (
       new.id is distinct from old.id
       or new.freight_id is distinct from old.freight_id
       or new.transporter_id is distinct from old.transporter_id
     ) then
    raise exception 'Bid identity cannot change' using errcode = '42501';
  end if;

  if new.amount is null
     or new.amount <= 0
     or new.amount = 'NaN'::numeric
     or new.amount = 'Infinity'::numeric
     or new.amount = '-Infinity'::numeric then
    raise exception 'Bid amount must be positive' using errcode = '22023';
  end if;

  if role_name = 'transporter' then
    if new.transporter_id is distinct from (select auth.uid())
       or freight_row.record_origin <> 'live'
       or freight_row.status <> 'bidding'::public.freight_status
       or (freight_row.bid_opens_at is not null and now() < freight_row.bid_opens_at)
       or (freight_row.bid_closes_at is not null and now() > freight_row.bid_closes_at) then
      raise exception 'Bids are only accepted from the owner during the open bidding window'
        using errcode = '42501';
    end if;
    if new.state <> 'active'::public.bid_state then
      raise exception 'Transporters may only submit active bids' using errcode = '42501';
    end if;
  end if;

  if freight_row.status in (
      'awarded'::public.freight_status,
      'dispatched'::public.freight_status,
      'locked'::public.freight_status,
      'completed'::public.freight_status
    ) and tg_op = 'INSERT' then
    raise exception 'Bids cannot be inserted after award' using errcode = '42501';
  end if;

  if freight_row.status in (
      'awarded'::public.freight_status,
      'dispatched'::public.freight_status,
      'locked'::public.freight_status,
      'completed'::public.freight_status
    ) and tg_op = 'UPDATE' and (
      new.amount is distinct from old.amount
      or new.transporter_id is distinct from old.transporter_id
      or new.freight_id is distinct from old.freight_id
      or new.state is distinct from old.state
    ) then
    raise exception 'Bids are immutable after award' using errcode = '42501';
  end if;

  return new;
end
$$;

revoke execute on function private.prevent_invalid_bid_write()
  from public, anon, authenticated;

drop trigger if exists prevent_invalid_bid_write on public.bids;
create trigger prevent_invalid_bid_write
before insert or update or delete on public.bids
for each row
execute function private.prevent_invalid_bid_write();

create or replace function private.prevent_freight_award_bypass()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  winner_role public.user_role;
  winner_status public.registration_status;
begin
  if tg_op = 'INSERT' and new.status = 'awarded'::public.freight_status then
    if coalesce(public.current_role()::text, '') not in ('admin', 'logistics_manager')
       or new.accepted_freight_amount is null
       or new.accepted_freight_amount <= 0
       or new.winner_profile_id is null then
      raise exception 'Direct awards require a positive accepted amount and transporter'
        using errcode = '42501';
    end if;
    select p.role, p.status into winner_role, winner_status
    from public.profiles p where p.id = new.winner_profile_id;
    if winner_role is distinct from 'transporter'::public.user_role
       or winner_status is distinct from 'approved'::public.registration_status then
      raise exception 'Award winner must be an approved transporter'
        using errcode = '42501';
    end if;
  end if;

  if tg_op = 'UPDATE'
     and new.status = 'awarded'::public.freight_status
     and old.status is distinct from new.status
     and coalesce(current_setting('kaysons.award_freight', true), '') <> 'on' then
    raise exception 'Use award_freight to award a freight atomically'
      using errcode = '42501';
  end if;

  if tg_op = 'UPDATE'
     and new.status = 'locked'::public.freight_status
     and old.status is distinct from new.status
     and coalesce(current_setting('kaysons.lock_freight', true), '') <> 'on' then
    raise exception 'Use lock_freight_invoices to lock a freight atomically'
      using errcode = '42501';
  end if;

  if tg_op = 'UPDATE'
     and old.status in (
       'awarded'::public.freight_status,
       'dispatched'::public.freight_status,
       'locked'::public.freight_status,
       'completed'::public.freight_status
     )
     and new.accepted_freight_amount is distinct from old.accepted_freight_amount then
    raise exception 'Accepted freight amount is immutable after award'
      using errcode = '42501';
  end if;
  return new;
end
$$;

revoke execute on function private.prevent_freight_award_bypass()
  from public, anon, authenticated;

drop trigger if exists prevent_freight_award_bypass on public.freights;
create trigger prevent_freight_award_bypass
before insert or update of status, accepted_freight_amount, winner_profile_id
on public.freights
for each row
execute function private.prevent_freight_award_bypass();

create or replace function private.prevent_transporter_freight_columns()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.current_role()::text is distinct from 'transporter' then
    return new;
  end if;

  if old.record_origin <> 'live'
     or old.winner_profile_id is distinct from (select auth.uid()) then
    raise exception 'Only the assigned live transporter may update this freight'
      using errcode = '42501';
  end if;

  if new.status is distinct from old.status
     and not (
       (old.status = 'awarded'::public.freight_status
        and new.status = 'dispatched'::public.freight_status)
       or (old.status = 'dispatched'::public.freight_status
           and new.status = 'completed'::public.freight_status)
       or (old.status = 'locked'::public.freight_status
           and new.status = 'completed'::public.freight_status)
     ) then
    raise exception 'Transporters may only advance dispatch status'
      using errcode = '42501';
  end if;

  if (to_jsonb(new) - array[
        'delivery_stages', 'vehicle_number', 'driver_name', 'driver_phone',
        'dispatched_at', 'status', 'ack_status', 'ack_received_at',
        'pod_received_date', 'pod_file_path', 'pod_remark', 'pod_received_by',
        'updated_at'
      ]) is distinct from
     (to_jsonb(old) - array[
        'delivery_stages', 'vehicle_number', 'driver_name', 'driver_phone',
        'dispatched_at', 'status', 'ack_status', 'ack_received_at',
        'pod_received_date', 'pod_file_path', 'pod_remark', 'pod_received_by',
        'updated_at'
      ]) then
    raise exception 'Transporters may only update delivery and vehicle fields'
      using errcode = '42501';
  end if;
  return new;
end
$$;

revoke execute on function private.prevent_transporter_freight_columns()
  from public, anon, authenticated;

drop trigger if exists prevent_transporter_freight_columns on public.freights;
create trigger prevent_transporter_freight_columns
before update on public.freights
for each row
execute function private.prevent_transporter_freight_columns();

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

  if new.status is distinct from old.status
     or (to_jsonb(new) - array[
          'company_name', 'party_name', 'bill_date', 'dispatch_date',
          'source_branch', 'remarks', 'gr_bilty_number', 'ack_status',
          'ack_received_at', 'pod_received_date', 'pod_file_path',
          'pod_remark', 'pod_received_by', 'updated_at'
        ]) is distinct from
        (to_jsonb(old) - array[
          'company_name', 'party_name', 'bill_date', 'dispatch_date',
          'source_branch', 'remarks', 'gr_bilty_number', 'ack_status',
          'ack_received_at', 'pod_received_date', 'pod_file_path',
          'pod_remark', 'pod_received_by', 'updated_at'
        ]) then
    raise exception 'Accountants may only update accounting and audited POD fields'
      using errcode = '42501';
  end if;
  return new;
end
$$;

revoke execute on function private.prevent_accountant_freight_columns()
  from public, anon, authenticated;

drop trigger if exists prevent_accountant_freight_columns on public.freights;
create trigger prevent_accountant_freight_columns
before insert or update on public.freights
for each row
execute function private.prevent_accountant_freight_columns();

create or replace function private.prevent_accountant_invoice_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  freight_row record;
  target_freight uuid := case when tg_op = 'DELETE' then old.freight_id else new.freight_id end;
begin
  if public.current_role()::text is distinct from 'accountant' then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;

  select f.status, f.record_origin into freight_row
  from public.freights f where f.id = target_freight;
  if not found or not (
      freight_row.status in ('locked'::public.freight_status, 'completed'::public.freight_status)
      or freight_row.record_origin = 'historical_import'
    ) then
    raise exception 'Accountant invoice changes require a finalized freight'
      using errcode = '42501';
  end if;

  if tg_op = 'UPDATE' and new.freight_id is distinct from old.freight_id then
    raise exception 'Invoice freight cannot be reassigned by an accountant'
      using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; else return new; end if;
end
$$;

revoke execute on function private.prevent_accountant_invoice_mutation()
  from public, anon, authenticated;

drop trigger if exists prevent_accountant_invoice_mutation on public.invoices;
create trigger prevent_accountant_invoice_mutation
before insert or update or delete on public.invoices
for each row
execute function private.prevent_accountant_invoice_mutation();

create or replace function private.prevent_accountant_charge_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  freight_row record;
  target_freight uuid := case when tg_op = 'DELETE' then old.freight_id else new.freight_id end;
begin
  if public.current_role()::text is distinct from 'accountant' then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;

  select f.status, f.record_origin into freight_row
  from public.freights f where f.id = target_freight;
  if not found or not (
      freight_row.status in ('locked'::public.freight_status, 'completed'::public.freight_status)
      or freight_row.record_origin = 'historical_import'
    ) then
    raise exception 'Accountant charge changes require a finalized freight'
      using errcode = '42501';
  end if;

  if tg_op <> 'DELETE' then
    new.added_by := coalesce(new.added_by, (select auth.uid()));
    if new.added_by is distinct from (select auth.uid()) then
      raise exception 'Accountant charges must be attributed to the caller'
        using errcode = '42501';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; else return new; end if;
end
$$;

revoke execute on function private.prevent_accountant_charge_mutation()
  from public, anon, authenticated;

drop trigger if exists prevent_accountant_charge_mutation on public.freight_charges;
create trigger prevent_accountant_charge_mutation
before insert or update or delete on public.freight_charges
for each row
execute function private.prevent_accountant_charge_mutation();

drop policy if exists "bids transporter own" on public.bids;
drop policy if exists "bids staff read" on public.bids;
drop policy if exists "bids staff update" on public.bids;
drop policy if exists "bids transporter read visible" on public.bids;

create policy "bids staff read"
on public.bids
for select to authenticated
using ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role
));

create policy "bids staff update"
on public.bids
for update to authenticated
using ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role
))
with check ((select public.current_role()) in (
  'admin'::public.user_role,
  'logistics_manager'::public.user_role
));

create policy "bids transporter read visible"
on public.bids
for select to authenticated
using (
  (select public.current_role()) = 'transporter'::public.user_role
  and exists (
    select 1 from public.freights f
    where f.id = bids.freight_id
  )
);

create policy "bids transporter insert open"
on public.bids
for insert to authenticated
with check (
  (select public.current_role()) = 'transporter'::public.user_role
  and transporter_id = (select auth.uid())
  and state = 'active'::public.bid_state
  and amount > 0
  and exists (
    select 1
    from public.freights f
    where f.id = bids.freight_id
      and f.record_origin = 'live'
      and f.status = 'bidding'::public.freight_status
      and (f.bid_opens_at is null or now() >= f.bid_opens_at)
      and (f.bid_closes_at is null or now() <= f.bid_closes_at)
  )
);

create policy "bids transporter update open"
on public.bids
for update to authenticated
using (
  (select public.current_role()) = 'transporter'::public.user_role
  and transporter_id = (select auth.uid())
  and exists (
    select 1
    from public.freights f
    where f.id = bids.freight_id
      and f.record_origin = 'live'
      and f.status = 'bidding'::public.freight_status
      and (f.bid_opens_at is null or now() >= f.bid_opens_at)
      and (f.bid_closes_at is null or now() <= f.bid_closes_at)
  )
)
with check (
  (select public.current_role()) = 'transporter'::public.user_role
  and transporter_id = (select auth.uid())
  and state = 'active'::public.bid_state
  and amount > 0
);

drop policy if exists "accountants manage ledger freights" on public.freights;
create policy "accountants read ledger freights"
on public.freights
for select to authenticated
using ((select public.current_role()) = 'accountant'::public.user_role);

create policy "accountants insert locked ledger freights"
on public.freights
for insert to authenticated
with check (
  (select public.current_role()) = 'accountant'::public.user_role
  and created_by = (select auth.uid())
  and (
    (record_origin = 'live' and status = 'locked'::public.freight_status)
    or (
      record_origin = 'historical_import'
      and import_batch_id is not null
      and status in (
        'locked'::public.freight_status,
        'completed'::public.freight_status
      )
    )
  )
);

create policy "accountants update ledger freights"
on public.freights
for update to authenticated
using ((select public.current_role()) = 'accountant'::public.user_role)
with check ((select public.current_role()) = 'accountant'::public.user_role);

create or replace function public.award_freight(
  p_freight_id uuid,
  p_transporter_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  freight_row public.freights;
  bid_row public.bids;
  winner public.profiles;
begin
  if (select auth.uid()) is null
     or coalesce(public.current_role()::text, '') not in ('admin', 'logistics_manager') then
    raise exception 'Only approved office staff may award freight' using errcode = '42501';
  end if;
  if p_freight_id is null or p_transporter_id is null then
    raise exception 'Freight and transporter are required' using errcode = '22004';
  end if;

  select * into freight_row
  from public.freights f
  where f.id = p_freight_id
  for update;
  if not found then
    raise exception 'Freight is unavailable' using errcode = 'P0002';
  end if;

  if freight_row.status = 'awarded'::public.freight_status
     and freight_row.winner_profile_id = p_transporter_id
     and freight_row.accepted_freight_amount is not null then
    return jsonb_build_object(
      'freight_id', p_freight_id,
      'transporter_id', p_transporter_id,
      'accepted_amount', freight_row.accepted_freight_amount,
      'status', freight_row.status,
      'idempotent', true
    );
  end if;
  if freight_row.status <> 'bidding'::public.freight_status then
    raise exception 'Only bidding freight can be awarded' using errcode = '42501';
  end if;

  select * into winner
  from public.profiles p
  where p.id = p_transporter_id
    and p.role = 'transporter'::public.user_role
    and p.status = 'approved'::public.registration_status;
  if not found then
    raise exception 'Award winner must be an approved transporter' using errcode = '42501';
  end if;

  select * into bid_row
  from public.bids b
  where b.freight_id = p_freight_id
    and b.transporter_id = p_transporter_id
    and b.state in ('active'::public.bid_state, 'won'::public.bid_state)
  order by (b.state = 'won'::public.bid_state) desc, b.updated_at desc, b.id
  limit 1
  for update;
  if not found or bid_row.amount is null or bid_row.amount <= 0 then
    raise exception 'An active positive bid is required for the award' using errcode = '42501';
  end if;

  perform set_config('kaysons.award_freight', 'on', true);
  update public.bids
  set state = 'lost'::public.bid_state
  where freight_id = p_freight_id;
  update public.bids
  set state = 'won'::public.bid_state
  where id = bid_row.id;

  update public.freights
  set winner_profile_id = p_transporter_id,
      accepted_freight_amount = bid_row.amount,
      status = 'awarded'::public.freight_status
  where id = p_freight_id;

  return jsonb_build_object(
    'freight_id', p_freight_id,
    'transporter_id', p_transporter_id,
    'bid_id', bid_row.id,
    'accepted_amount', bid_row.amount,
    'status', 'awarded',
    'idempotent', false
  );
end
$$;

revoke all on function public.award_freight(uuid, uuid) from public, anon;
grant execute on function public.award_freight(uuid, uuid) to authenticated;

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
      'dispatched'::public.freight_status
    ) then
    raise exception 'Only awarded or dispatched freight can be locked' using errcode = '42501';
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

  perform set_config('kaysons.lock_freight', 'on', true);
  update public.freights
  set status = 'locked'::public.freight_status,
      locked_at = coalesce(locked_at, now())
  where id = p_freight_id;

  return jsonb_build_object(
    'freight_id', p_freight_id,
    'status', 'locked',
    'accepted_amount', accepted_amount,
    'invoice_count', invoice_count,
    'charge_count', charge_count,
    'invoice_ids', to_jsonb(invoice_ids)
  );
end
$$;

revoke all on function public.lock_freight_invoices(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.lock_freight_invoices(uuid, jsonb, jsonb) to authenticated;
