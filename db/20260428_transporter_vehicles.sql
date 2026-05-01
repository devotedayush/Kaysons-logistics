create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete cascade,
  transporter_id uuid references public.profiles(id) on delete cascade,
  registration_number text,
  number text,
  vehicle_type text,
  type text,
  capacity_qt numeric,
  capacity_weight_kg numeric,
  capacity_kg numeric,
  rc_number text,
  insurance_number text,
  driver_name text,
  driver_phone text,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

alter table public.vehicles
  add column if not exists profile_id uuid references public.profiles(id) on delete cascade,
  add column if not exists registration_number text,
  add column if not exists vehicle_type text,
  add column if not exists capacity_qt numeric,
  add column if not exists capacity_weight_kg numeric,
  add column if not exists rc_number text,
  add column if not exists insurance_number text,
  add column if not exists driver_name text,
  add column if not exists driver_phone text,
  add column if not exists status text not null default 'active',
  add column if not exists updated_at timestamp with time zone not null default now();

update public.vehicles
set
  profile_id = coalesce(profile_id, transporter_id),
  registration_number = coalesce(registration_number, number),
  vehicle_type = coalesce(vehicle_type, type),
  capacity_weight_kg = coalesce(capacity_weight_kg, capacity_kg),
  updated_at = coalesce(updated_at, created_at, now())
where profile_id is null
   or registration_number is null
   or vehicle_type is null
   or capacity_weight_kg is null;

alter table public.vehicles
  alter column transporter_id drop not null,
  alter column number drop not null,
  alter column profile_id set not null,
  alter column registration_number set not null;

create index if not exists vehicles_profile_updated_idx
  on public.vehicles (profile_id, updated_at desc);

create unique index if not exists vehicles_profile_registration_idx
  on public.vehicles (profile_id, lower(registration_number));

alter table if exists public.vehicles enable row level security;

drop policy if exists "transporters_can_read_own_vehicles" on public.vehicles;
create policy "transporters_can_read_own_vehicles"
on public.vehicles
for select
to authenticated
using (
  profile_id = (select auth.uid())
  or transporter_id = (select auth.uid())
);

drop policy if exists "transporters_can_insert_own_vehicles" on public.vehicles;
create policy "transporters_can_insert_own_vehicles"
on public.vehicles
for insert
to authenticated
with check (
  profile_id = (select auth.uid())
  or transporter_id = (select auth.uid())
);

drop policy if exists "transporters_can_update_own_vehicles" on public.vehicles;
create policy "transporters_can_update_own_vehicles"
on public.vehicles
for update
to authenticated
using (
  profile_id = (select auth.uid())
  or transporter_id = (select auth.uid())
)
with check (
  profile_id = (select auth.uid())
  or transporter_id = (select auth.uid())
);

drop policy if exists "transporters_can_delete_own_vehicles" on public.vehicles;
create policy "transporters_can_delete_own_vehicles"
on public.vehicles
for delete
to authenticated
using (
  profile_id = (select auth.uid())
  or transporter_id = (select auth.uid())
);

grant select, insert, update, delete on public.vehicles to authenticated;
