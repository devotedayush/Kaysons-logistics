insert into storage.buckets (id, name, public)
values ('delivery-documents', 'delivery-documents', false)
on conflict (id) do nothing;

drop policy if exists "transporters_can_upload_delivery_documents" on storage.objects;
create policy "transporters_can_upload_delivery_documents"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'delivery-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "transporters_can_read_own_delivery_documents" on storage.objects;
create policy "transporters_can_read_own_delivery_documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'delivery-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "admins_and_lm_can_read_delivery_documents" on storage.objects;
create policy "admins_and_lm_can_read_delivery_documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'delivery-documents'
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'logistics_manager')
  )
);

drop policy if exists "transporters_can_update_own_delivery_documents" on storage.objects;
create policy "transporters_can_update_own_delivery_documents"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'delivery-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'delivery-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "transporters_can_delete_own_delivery_documents" on storage.objects;
create policy "transporters_can_delete_own_delivery_documents"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'delivery-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
