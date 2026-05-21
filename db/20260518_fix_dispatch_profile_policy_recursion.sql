create or replace function private.dispatch_manager_can_read_profile(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles dm
    where dm.id = auth.uid()
      and dm.role::text = 'dispatch_manager'
      and (
        target_profile_id = dm.id
        or target_profile_id = dm.manager_id
        or exists (
          select 1
          from public.freights f
          where f.created_by = dm.manager_id
            and f.status::text in ('awarded', 'dispatched', 'locked', 'completed')
            and (
              f.created_by = target_profile_id
              or f.winner_profile_id = target_profile_id
            )
        )
      )
  );
$$;

revoke all on function private.dispatch_manager_can_read_profile(uuid) from public;
grant execute on function private.dispatch_manager_can_read_profile(uuid) to authenticated;

drop policy if exists "dispatch managers read related profiles" on public.profiles;
create policy "dispatch managers read related profiles"
on public.profiles
for select
to authenticated
using (private.dispatch_manager_can_read_profile(id));
