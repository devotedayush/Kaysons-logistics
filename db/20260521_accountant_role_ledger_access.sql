alter type public.user_role add value if not exists 'accountant';

drop policy if exists "accountants read operational profiles" on public.profiles;
create policy "accountants read operational profiles"
on public.profiles
for select
to authenticated
using (
  public."current_role"()::text = 'accountant'
  and role::text in ('transporter', 'logistics_manager', 'dispatch_manager', 'accountant')
);

drop policy if exists "accountants manage ledger freights" on public.freights;
create policy "accountants manage ledger freights"
on public.freights
for all
to authenticated
using (public."current_role"()::text = 'accountant')
with check (public."current_role"()::text = 'accountant');

drop policy if exists "accountants manage invoices" on public.invoices;
create policy "accountants manage invoices"
on public.invoices
for all
to authenticated
using (public."current_role"()::text = 'accountant')
with check (public."current_role"()::text = 'accountant');

drop policy if exists "accountants manage freight charges" on public.freight_charges;
create policy "accountants manage freight charges"
on public.freight_charges
for all
to authenticated
using (public."current_role"()::text = 'accountant')
with check (public."current_role"()::text = 'accountant');

drop policy if exists "accountants manage product lines" on public.freight_product_lines;
create policy "accountants manage product lines"
on public.freight_product_lines
for all
to authenticated
using (public."current_role"()::text = 'accountant')
with check (public."current_role"()::text = 'accountant');

drop policy if exists "accountants read alerts" on public.admin_alerts;
create policy "accountants read alerts"
on public.admin_alerts
for select
to authenticated
using (public."current_role"()::text = 'accountant');

drop policy if exists "accountants read ai reports" on public.ai_daily_reports;
create policy "accountants read ai reports"
on public.ai_daily_reports
for select
to authenticated
using (public."current_role"()::text = 'accountant');

drop policy if exists "accountants write ai reports" on public.ai_daily_reports;
create policy "accountants write ai reports"
on public.ai_daily_reports
for insert
to authenticated
with check (public."current_role"()::text = 'accountant');

drop policy if exists "accountants update own ai reports" on public.ai_daily_reports;
create policy "accountants update own ai reports"
on public.ai_daily_reports
for update
to authenticated
using (public."current_role"()::text = 'accountant')
with check (public."current_role"()::text = 'accountant');
