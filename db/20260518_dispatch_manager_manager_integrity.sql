create or replace function private.validate_dispatch_manager_profile()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE'
     and old.role::text = 'logistics_manager'
     and new.role::text <> 'logistics_manager'
     and exists (
       select 1
       from public.profiles dm
       where dm.role::text = 'dispatch_manager'
         and dm.manager_id = old.id
     ) then
    raise exception 'Cannot change a logistics manager role while dispatch managers report to them';
  end if;

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

create or replace function private.prevent_dispatch_manager_orphan_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.role::text = 'logistics_manager'
     and exists (
       select 1
       from public.profiles dm
       where dm.role::text = 'dispatch_manager'
         and dm.manager_id = old.id
     ) then
    raise exception 'Cannot delete a logistics manager while dispatch managers report to them';
  end if;

  return old;
end;
$$;

drop trigger if exists prevent_dispatch_manager_orphan_delete on public.profiles;

create trigger prevent_dispatch_manager_orphan_delete
before delete on public.profiles
for each row
execute function private.prevent_dispatch_manager_orphan_delete();
