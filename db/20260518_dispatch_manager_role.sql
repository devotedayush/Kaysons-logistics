alter type public.user_role add value if not exists 'dispatch_manager';

alter table if exists public.profiles
  add column if not exists manager_id uuid references public.profiles(id) on delete set null;

create index if not exists profiles_manager_id_idx
  on public.profiles (manager_id);

create schema if not exists private;

create or replace function private.validate_dispatch_manager_profile()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.role::text = 'dispatch_manager' then
    if new.manager_id is null then
      raise exception 'Dispatch manager must report to a logistics manager';
    end if;
    if not exists (
      select 1
      from public.profiles manager
      where manager.id = new.manager_id
        and manager.role::text = 'logistics_manager'
    ) then
      raise exception 'Dispatch manager manager_id must reference a logistics manager';
    end if;
  elsif new.manager_id is not null then
    new.manager_id := null;
  end if;

  return new;
end;
$$;

drop trigger if exists validate_dispatch_manager_profile on public.profiles;

create trigger validate_dispatch_manager_profile
before insert or update of role, manager_id on public.profiles
for each row
execute function private.validate_dispatch_manager_profile();

create or replace function private.prevent_dispatch_manager_freight_columns()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public."current_role"()::text = 'dispatch_manager'
     and (to_jsonb(new) - 'delivery_stages') is distinct from (to_jsonb(old) - 'delivery_stages') then
    raise exception 'Dispatch managers can only update delivery stage checks';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_dispatch_manager_freight_columns on public.freights;

create trigger prevent_dispatch_manager_freight_columns
before update on public.freights
for each row
execute function private.prevent_dispatch_manager_freight_columns();

drop policy if exists "dispatch managers read manager accepted freights" on public.freights;
create policy "dispatch managers read manager accepted freights"
on public.freights
for select
to authenticated
using (
  public."current_role"()::text = 'dispatch_manager'
  and status::text in ('awarded', 'dispatched', 'locked', 'completed')
  and created_by = (
    select dm.manager_id
    from public.profiles dm
    where dm.id = (select auth.uid())
      and dm.role::text = 'dispatch_manager'
  )
);

drop policy if exists "dispatch managers update manager accepted freight checks" on public.freights;
create policy "dispatch managers update manager accepted freight checks"
on public.freights
for update
to authenticated
using (
  public."current_role"()::text = 'dispatch_manager'
  and status::text in ('awarded', 'dispatched', 'locked', 'completed')
  and created_by = (
    select dm.manager_id
    from public.profiles dm
    where dm.id = (select auth.uid())
      and dm.role::text = 'dispatch_manager'
  )
)
with check (
  public."current_role"()::text = 'dispatch_manager'
  and status::text in ('awarded', 'dispatched', 'locked', 'completed')
  and created_by = (
    select dm.manager_id
    from public.profiles dm
    where dm.id = (select auth.uid())
      and dm.role::text = 'dispatch_manager'
  )
);

drop policy if exists "dispatch managers read related profiles" on public.profiles;
create policy "dispatch managers read related profiles"
on public.profiles
for select
to authenticated
using (
  public."current_role"()::text = 'dispatch_manager'
  and (
    id = (select auth.uid())
    or id = (
      select dm.manager_id
      from public.profiles dm
      where dm.id = (select auth.uid())
        and dm.role::text = 'dispatch_manager'
    )
    or exists (
      select 1
      from public.freights f
      join public.profiles dm on dm.id = (select auth.uid())
      where dm.role::text = 'dispatch_manager'
        and f.created_by = dm.manager_id
        and f.status::text in ('awarded', 'dispatched', 'locked', 'completed')
        and (
          f.created_by = profiles.id
          or f.winner_profile_id = profiles.id
        )
    )
  )
);

drop policy if exists "bids transporter read visible" on public.bids;
create policy "bids transporter read visible"
on public.bids
for select
to authenticated
using (
  public."current_role"()::text = 'transporter'
  and exists (
    select 1
    from public.freights f
    where f.id = bids.freight_id
  )
);

drop policy if exists "dispatch managers read delivery documents" on storage.objects;
create policy "dispatch managers read delivery documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'delivery-documents'
  and public."current_role"()::text = 'dispatch_manager'
  and exists (
    select 1
    from public.freights f
    join public.profiles dm on dm.id = (select auth.uid())
    where dm.role::text = 'dispatch_manager'
      and f.created_by = dm.manager_id
      and f.status::text in ('awarded', 'dispatched', 'locked', 'completed')
      and f.id::text = (storage.foldername(name))[2]
  )
);

drop policy if exists "dispatch managers write vehicle alerts" on public.admin_alerts;
create policy "dispatch managers write vehicle alerts"
on public.admin_alerts
for insert
to authenticated
with check (
  public."current_role"()::text = 'dispatch_manager'
  and category = 'vehicle_verification'
  and exists (
    select 1
    from public.freights f
    join public.profiles dm on dm.id = (select auth.uid())
    where dm.role::text = 'dispatch_manager'
      and f.id = admin_alerts.freight_id
      and f.created_by = dm.manager_id
      and f.status::text in ('awarded', 'dispatched', 'locked', 'completed')
  )
);
