create table if not exists public.ai_daily_reports (
  id uuid primary key default gen_random_uuid(),
  report_date date not null unique default current_date,
  summary text not null default '',
  anomalies jsonb not null default '[]'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  generated_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists ai_daily_reports_date_idx
  on public.ai_daily_reports (report_date desc);

alter table if exists public.ai_daily_reports enable row level security;

drop policy if exists "admins_can_read_ai_reports" on public.ai_daily_reports;
create policy "admins_can_read_ai_reports"
on public.ai_daily_reports
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
);

drop policy if exists "admins_can_write_ai_reports" on public.ai_daily_reports;
create policy "admins_can_write_ai_reports"
on public.ai_daily_reports
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
);

drop policy if exists "admins_can_update_ai_reports" on public.ai_daily_reports;
create policy "admins_can_update_ai_reports"
on public.ai_daily_reports
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
);

grant select, insert, update on public.ai_daily_reports to authenticated;
