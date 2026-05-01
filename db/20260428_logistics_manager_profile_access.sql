alter table if exists public.profiles
  add column if not exists coverage_area text;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vehicles'
      and policyname = 'vehicles staff read'
  ) then
    execute $policy$
      create policy "vehicles staff read"
      on public.vehicles
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.profiles lm
          where lm.id = (select auth.uid())
            and lm.role in ('admin', 'logistics_manager')
        )
      )
    $policy$;
  end if;
end $$;
