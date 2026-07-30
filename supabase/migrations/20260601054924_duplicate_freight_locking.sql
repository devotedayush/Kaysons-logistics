create or replace function public.normalize_invoice_number(invoice_number text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(regexp_replace(lower(coalesce(invoice_number, '')), '[^a-z0-9]+', '', 'g'), '')
$$;

create table if not exists public.duplicate_freight_overrides (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null,
  invoice_number_norm text not null,
  existing_freight_id uuid references public.freights(id),
  new_freight_id uuid not null references public.freights(id) on delete cascade,
  approved_by uuid not null references public.profiles(id),
  reason text not null,
  remark text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default now(),
  constraint duplicate_freight_overrides_reason_required
    check (length(trim(reason)) > 0),
  constraint duplicate_freight_overrides_remark_required
    check (length(trim(remark)) > 0),
  constraint duplicate_freight_overrides_invoice_norm_required
    check (length(trim(invoice_number_norm)) > 0)
);

create index if not exists duplicate_freight_overrides_invoice_norm_idx
  on public.duplicate_freight_overrides(invoice_number_norm);

create index if not exists duplicate_freight_overrides_new_freight_idx
  on public.duplicate_freight_overrides(new_freight_id);

alter table public.duplicate_freight_overrides enable row level security;

drop policy if exists "Admins can read duplicate freight overrides"
  on public.duplicate_freight_overrides;
create policy "Admins can read duplicate freight overrides"
  on public.duplicate_freight_overrides
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.role in ('admin', 'accountant')
    )
  );

drop policy if exists "Admins can create duplicate freight overrides"
  on public.duplicate_freight_overrides;
create policy "Admins can create duplicate freight overrides"
  on public.duplicate_freight_overrides
  for insert
  to authenticated
  with check (
    approved_by = (select auth.uid())
    and exists (
      select 1
      from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.role = 'admin'
    )
  );

create or replace function public.is_finalized_freight_status(status public.freight_status)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select status in ('locked'::public.freight_status, 'completed'::public.freight_status)
$$;

create or replace function public.enforce_no_duplicate_finalized_invoice()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  invoice_norm text;
  new_status public.freight_status;
  existing_freight uuid;
begin
  invoice_norm := public.normalize_invoice_number(new.invoice_number);
  if invoice_norm is null or new.freight_id is null then
    return new;
  end if;

  select freights.status
  into new_status
  from public.freights
  where freights.id = new.freight_id;

  if not public.is_finalized_freight_status(new_status) then
    return new;
  end if;

  select existing.freight_id
  into existing_freight
  from public.invoices existing
  join public.freights existing_freight_row
    on existing_freight_row.id = existing.freight_id
  where public.normalize_invoice_number(existing.invoice_number) = invoice_norm
    and existing.freight_id is distinct from new.freight_id
    and public.is_finalized_freight_status(existing_freight_row.status)
  order by existing.created_at
  limit 1;

  if existing_freight is null then
    return new;
  end if;

  if exists (
    select 1
    from public.duplicate_freight_overrides overrides
    join public.profiles approver on approver.id = overrides.approved_by
    where overrides.invoice_number_norm = invoice_norm
      and overrides.new_freight_id = new.freight_id
      and overrides.existing_freight_id is not distinct from existing_freight
      and approver.role = 'admin'
      and length(trim(overrides.reason)) > 0
      and length(trim(overrides.remark)) > 0
  ) then
    return new;
  end if;

  raise exception
    'Duplicate freight blocked: invoice % is already linked to finalized freight %',
    new.invoice_number,
    existing_freight
    using errcode = '23505';
end;
$$;

drop trigger if exists enforce_no_duplicate_finalized_invoice_on_invoices
  on public.invoices;
create trigger enforce_no_duplicate_finalized_invoice_on_invoices
  before insert or update of invoice_number, freight_id
  on public.invoices
  for each row
  execute function public.enforce_no_duplicate_finalized_invoice();

create or replace function public.enforce_no_duplicate_finalized_freight_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  duplicate_record record;
begin
  if not public.is_finalized_freight_status(new.status) then
    return new;
  end if;

  if tg_op = 'UPDATE'
    and public.is_finalized_freight_status(old.status)
    and old.status = new.status
  then
    return new;
  end if;

  select
    current_invoice.invoice_number,
    public.normalize_invoice_number(current_invoice.invoice_number) as invoice_norm,
    existing_invoice.freight_id as existing_freight_id
  into duplicate_record
  from public.invoices current_invoice
  join public.invoices existing_invoice
    on public.normalize_invoice_number(existing_invoice.invoice_number)
      = public.normalize_invoice_number(current_invoice.invoice_number)
   and existing_invoice.freight_id is distinct from current_invoice.freight_id
  join public.freights existing_freight
    on existing_freight.id = existing_invoice.freight_id
  where current_invoice.freight_id = new.id
    and public.normalize_invoice_number(current_invoice.invoice_number) is not null
    and public.is_finalized_freight_status(existing_freight.status)
  order by existing_invoice.created_at
  limit 1;

  if duplicate_record.invoice_norm is null then
    return new;
  end if;

  if exists (
    select 1
    from public.duplicate_freight_overrides overrides
    join public.profiles approver on approver.id = overrides.approved_by
    where overrides.invoice_number_norm = duplicate_record.invoice_norm
      and overrides.new_freight_id = new.id
      and overrides.existing_freight_id is not distinct from duplicate_record.existing_freight_id
      and approver.role = 'admin'
      and length(trim(overrides.reason)) > 0
      and length(trim(overrides.remark)) > 0
  ) then
    return new;
  end if;

  raise exception
    'Duplicate freight blocked: invoice % is already linked to finalized freight %',
    duplicate_record.invoice_number,
    duplicate_record.existing_freight_id
    using errcode = '23505';
end;
$$;

drop trigger if exists enforce_no_duplicate_finalized_freight_status_on_freights
  on public.freights;
create trigger enforce_no_duplicate_finalized_freight_status_on_freights
  before insert or update of status
  on public.freights
  for each row
  execute function public.enforce_no_duplicate_finalized_freight_status();
