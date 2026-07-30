drop policy "users submit own deletion requests"
  on public.account_deletion_requests;

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
