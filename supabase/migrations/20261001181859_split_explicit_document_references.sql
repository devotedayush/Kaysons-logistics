-- The historical importer joined separate references with " / ". Split only
-- that explicit separator; hyphens and number ranges remain untouched.
insert into public.invoice_documents(invoice_id, document_kind, document_number)
select d.invoice_id, d.document_kind, btrim(part)
from public.invoice_documents d
cross join lateral regexp_split_to_table(d.document_number, '\s+/\s+') as part
where d.document_number ~ '\s+/\s+' and nullif(btrim(part), '') is not null
on conflict do nothing;

delete from public.invoice_documents
where document_number ~ '\s+/\s+';

create or replace function private.mirror_invoice_scalar_documents()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if old.e_way_bill_number is distinct from new.e_way_bill_number then
      delete from public.invoice_documents d
      where d.invoice_id = new.id and d.document_kind = 'e_way_bill'
        and lower(btrim(d.document_number)) in (
          select lower(btrim(part))
          from regexp_split_to_table(old.e_way_bill_number, '\s+/\s+') as part
        );
    end if;
    if old.gr_number is distinct from new.gr_number then
      delete from public.invoice_documents d
      where d.invoice_id = new.id and d.document_kind = 'gr_bilty'
        and lower(btrim(d.document_number)) in (
          select lower(btrim(part))
          from regexp_split_to_table(old.gr_number, '\s+/\s+') as part
        );
    end if;
    if old.lr_number is distinct from new.lr_number then
      delete from public.invoice_documents d
      where d.invoice_id = new.id and d.document_kind = 'gr_bilty'
        and lower(btrim(d.document_number)) in (
          select lower(btrim(part))
          from regexp_split_to_table(old.lr_number, '\s+/\s+') as part
        );
    end if;
  end if;

  insert into public.invoice_documents(invoice_id, document_kind, document_number)
  select new.id, 'e_way_bill', btrim(part)
  from regexp_split_to_table(new.e_way_bill_number, '\s+/\s+') as part
  where nullif(btrim(part), '') is not null
  on conflict do nothing;

  insert into public.invoice_documents(invoice_id, document_kind, document_number)
  select new.id, 'gr_bilty', btrim(part)
  from (values (new.gr_number), (new.lr_number)) as source(number)
  cross join lateral regexp_split_to_table(source.number, '\s+/\s+') as part
  where nullif(btrim(part), '') is not null
  on conflict do nothing;
  return new;
end
$$;
revoke all on function private.mirror_invoice_scalar_documents()
  from public, anon, authenticated;
