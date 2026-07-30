create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  email text not null,
  source text not null,
  status text not null default 'pending',
  reason text,
  requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  verified_at timestamptz,
  completed_at timestamptz,
  constraint account_deletion_requests_email_length
    check (char_length(email) between 3 and 320),
  constraint account_deletion_requests_source
    check (source in ('in_app', 'web')),
  constraint account_deletion_requests_status
    check (
      status in (
        'pending',
        'verifying',
        'approved',
        'completed',
        'rejected',
        'cancelled'
      )
    ),
  constraint account_deletion_requests_reason_length
    check (reason is null or char_length(reason) <= 1000)
);

comment on table public.account_deletion_requests is
  'Account and associated-data deletion requests submitted in-app or through the public web form.';

create unique index account_deletion_requests_one_active_email_idx
  on public.account_deletion_requests (lower(email))
  where status in ('pending', 'verifying', 'approved');

create index account_deletion_requests_user_requested_idx
  on public.account_deletion_requests (user_id, requested_at desc)
  where user_id is not null;

alter table public.account_deletion_requests enable row level security;
alter table public.account_deletion_requests force row level security;

create policy "users read own deletion requests"
  on public.account_deletion_requests
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "users submit own deletion requests"
  on public.account_deletion_requests
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and source = 'in_app'
    and lower(email) = lower(coalesce(((select auth.jwt()) ->> 'email'), ''))
    and status = 'pending'
  );

create policy "users cancel own deletion requests"
  on public.account_deletion_requests
  for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    and status in ('pending', 'verifying')
  )
  with check (
    (select auth.uid()) = user_id
    and status = 'cancelled'
  );

revoke all on table public.account_deletion_requests from public, anon;
grant select, insert, update on table public.account_deletion_requests
  to authenticated;

create trigger account_deletion_requests_touch_updated_at
before update on public.account_deletion_requests
for each row execute function public.touch_updated_at();
