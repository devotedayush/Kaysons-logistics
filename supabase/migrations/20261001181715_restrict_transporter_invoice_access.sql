-- Goods invoices and their office-managed mappings are not part of the
-- transporter workflow. Delivery GR/Bilty and POD data remain on the freight.
drop policy if exists "invoices transporter self read" on public.invoices;
drop policy if exists "invoice documents winner read" on public.invoice_documents;

comment on table public.invoice_documents is
  'Office-managed invoice-to-e-way/GR references. Read/write access is limited to Admin, Logistics Manager and Accountant.';
