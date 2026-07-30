create table if not exists public.historical_import_batches (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique,
  source_name text not null,
  source_period_start date,
  source_period_end date,
  source_sha256 text,
  status text not null default 'processing',
  row_count integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint historical_import_batches_status_check
    check (status in ('processing', 'completed', 'failed')),
  constraint historical_import_batches_period_check
    check (
      source_period_start is null
      or source_period_end is null
      or source_period_end >= source_period_start
    ),
  constraint historical_import_batches_row_count_check
    check (row_count >= 0)
);

alter table public.historical_import_batches enable row level security;

grant select, insert, update on public.historical_import_batches to authenticated;
revoke all on public.historical_import_batches from anon;

create index if not exists historical_import_batches_created_by_idx
  on public.historical_import_batches(created_by);

alter table public.freights
  add column if not exists record_origin text not null default 'live',
  add column if not exists data_completeness text not null default 'complete',
  add column if not exists import_batch_id uuid references public.historical_import_batches(id),
  add column if not exists import_metadata jsonb not null default '{}'::jsonb;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'freights_record_origin_check'
      and conrelid = 'public.freights'::regclass
  ) then
    alter table public.freights
      add constraint freights_record_origin_check
      check (record_origin in ('live', 'historical_import'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'freights_data_completeness_check'
      and conrelid = 'public.freights'::regclass
  ) then
    alter table public.freights
      add constraint freights_data_completeness_check
      check (data_completeness in ('complete', 'partial', 'quarantined'));
  end if;
end
$$;

create index if not exists freights_record_origin_created_at_idx
  on public.freights(record_origin, created_at desc);

create index if not exists freights_import_batch_id_idx
  on public.freights(import_batch_id);

create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = (select auth.uid())
    and p.status = 'approved'
$$;

revoke execute on function public.current_role() from public, anon;
grant execute on function public.current_role() to authenticated, service_role;

create or replace function private.prevent_profile_privilege_self_edit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) = old.id
    and (
      new.role is distinct from old.role
      or new.status is distinct from old.status
      or new.permissions is distinct from old.permissions
      or new.manager_id is distinct from old.manager_id
    )
  then
    raise exception 'Role, approval status, permissions, and manager assignment cannot be changed by the profile owner';
  end if;
  return new;
end
$$;

revoke execute on function private.prevent_profile_privilege_self_edit() from public, anon, authenticated;

drop trigger if exists protect_profile_privilege_self_edit on public.profiles;
create trigger protect_profile_privilege_self_edit
before update on public.profiles
for each row
execute function private.prevent_profile_privilege_self_edit();

drop policy if exists "historical import batches staff read"
  on public.historical_import_batches;
create policy "historical import batches staff read"
on public.historical_import_batches
for select
to authenticated
using (
  (select public.current_role()) in (
    'admin'::public.user_role,
    'logistics_manager'::public.user_role,
    'accountant'::public.user_role
  )
);

drop policy if exists "historical import batches managers write"
  on public.historical_import_batches;
create policy "historical import batches managers write"
on public.historical_import_batches
for all
to authenticated
using (
  (select public.current_role()) in (
    'admin'::public.user_role,
    'logistics_manager'::public.user_role
  )
)
with check (
  (select public.current_role()) in (
    'admin'::public.user_role,
    'logistics_manager'::public.user_role
  )
);

drop policy if exists "freights transporter read" on public.freights;
create policy "freights transporter read"
on public.freights
for select
to authenticated
using (
  (select public.current_role()) = 'transporter'::public.user_role
  and record_origin = 'live'
  and status in (
    'bidding'::public.freight_status,
    'awarded'::public.freight_status,
    'dispatched'::public.freight_status,
    'locked'::public.freight_status,
    'completed'::public.freight_status
  )
  and not exists (
    select 1
    from public.freight_blocked_transporters blocked
    where blocked.freight_id = freights.id
      and blocked.transporter_id = (select auth.uid())
  )
  and (
    not exists (
      select 1
      from public.freight_preferred_transporters preferred
      where preferred.freight_id = freights.id
    )
    or exists (
      select 1
      from public.freight_preferred_transporters preferred
      where preferred.freight_id = freights.id
        and preferred.transporter_id = (select auth.uid())
    )
  )
);

drop policy if exists "freight winner update" on public.freights;
create policy "freight winner update"
on public.freights
for update
to authenticated
using (
  record_origin = 'live'
  and winner_profile_id = (select auth.uid())
  and (select public.current_role()) = 'transporter'::public.user_role
)
with check (
  record_origin = 'live'
  and winner_profile_id = (select auth.uid())
  and (select public.current_role()) = 'transporter'::public.user_role
);

drop policy if exists "invoices transporter self read" on public.invoices;
create policy "invoices transporter self read"
on public.invoices
for select
to authenticated
using (
  transporter_id = (select auth.uid())
  and (select public.current_role()) = 'transporter'::public.user_role
  and exists (
    select 1
    from public.freights freight
    where freight.id = invoices.freight_id
      and freight.record_origin = 'live'
  )
);

insert into public.historical_import_batches (
  source_key,
  source_name,
  source_period_start,
  source_period_end,
  status,
  row_count,
  metadata,
  created_by,
  completed_at
)
select
  'ludhiana-secondary-freight-2026-04',
  'Ludhiana Sec. Frt. Apr.26 Real Data',
  date '2026-04-01',
  date '2026-04-30',
  'completed',
  count(*)::integer,
  jsonb_build_object('legacy_seed', true),
  min(created_by::text)::uuid,
  now()
from public.freights
where source_branch = 'Ludhiana Sec. Frt. Apr.26 Real Data'
on conflict (source_key) do update
set row_count = excluded.row_count,
    status = 'completed',
    completed_at = coalesce(
      public.historical_import_batches.completed_at,
      excluded.completed_at
    );

update public.freights
set record_origin = 'historical_import',
    data_completeness = 'partial',
    import_batch_id = (
      select id
      from public.historical_import_batches
      where source_key = 'ludhiana-secondary-freight-2026-04'
    ),
    import_metadata = case
      when jsonb_typeof(stop_details) = 'object' then stop_details
      else import_metadata
    end,
    stop_details = case
      when jsonb_typeof(stop_details) = 'object' then '[]'::jsonb
      else stop_details
    end
where source_branch in (
  'Ludhiana Sec. Frt. Apr.26 Real Data',
  'Rajesh Anand CSV Apr.26'
);

update public.profiles
set status = 'rejected'
where email like 'seed-%@kaysons.demo';

alter view public.admin_freight_ledger_view
  set (security_invoker = true);
