drop policy if exists "dispatch managers write vehicle alerts" on public.admin_alerts;

create policy "dispatch managers write delivery review alerts"
on public.admin_alerts
for insert
to authenticated
with check (
  public."current_role"()::text = 'dispatch_manager'
  and category in ('vehicle_verification', 'late_pod')
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
