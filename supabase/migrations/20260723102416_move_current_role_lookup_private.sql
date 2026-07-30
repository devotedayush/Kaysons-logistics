create or replace function private.current_role()
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

revoke execute on function private.current_role() from public, anon;
grant execute on function private.current_role() to authenticated, service_role;

create or replace function public.current_role()
returns public.user_role
language sql
stable
security invoker
set search_path = ''
as $$
  select private.current_role()
$$;

revoke execute on function public.current_role() from public, anon;
grant execute on function public.current_role() to authenticated, service_role;
