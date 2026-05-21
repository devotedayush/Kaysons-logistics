drop policy if exists "logistics managers assign dispatch managers" on public.profiles;

create policy "logistics managers assign dispatch managers"
on public.profiles
for update
to authenticated
using (
  public."current_role"()::text = 'logistics_manager'
  and id <> (select auth.uid())
  and (
    role::text = 'transporter'
    or (
      role::text = 'dispatch_manager'
      and manager_id = (select auth.uid())
    )
  )
)
with check (
  public."current_role"()::text = 'logistics_manager'
  and id <> (select auth.uid())
  and (
    (
      role::text = 'dispatch_manager'
      and manager_id = (select auth.uid())
      and status::text = 'approved'
    )
    or (
      role::text = 'transporter'
      and manager_id is null
    )
  )
);

create or replace function private.prevent_invalid_lm_dispatch_assignment()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public."current_role"()::text = 'logistics_manager'
     and old.id <> (select auth.uid()) then
    if (to_jsonb(new) - 'role' - 'manager_id' - 'status' - 'updated_at')
       is distinct from
       (to_jsonb(old) - 'role' - 'manager_id' - 'status' - 'updated_at') then
      raise exception 'Logistics managers can only assign dispatch manager role fields';
    end if;

    if not (
      (
        old.role::text = 'transporter'
        and new.role::text = 'dispatch_manager'
        and new.manager_id = (select auth.uid())
        and new.status::text = 'approved'
      )
      or (
        old.role::text = 'dispatch_manager'
        and old.manager_id = (select auth.uid())
        and new.role::text = 'dispatch_manager'
        and new.manager_id = (select auth.uid())
        and new.status::text = 'approved'
      )
      or (
        old.role::text = 'dispatch_manager'
        and old.manager_id = (select auth.uid())
        and new.role::text = 'transporter'
        and new.manager_id is null
      )
    ) then
      raise exception 'Logistics managers can only manage their own dispatch managers';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_invalid_lm_dispatch_assignment on public.profiles;

create trigger prevent_invalid_lm_dispatch_assignment
before update of role, manager_id, status on public.profiles
for each row
execute function private.prevent_invalid_lm_dispatch_assignment();
