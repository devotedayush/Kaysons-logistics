-- Kaysons Logistics — seed demo data
-- Prereq: accounts admin@/lm@/ta@/tb@kaysons.demo must exist (register via app)
--         and their roles must be promoted (see DEMO.md step A4).
-- Safe to re-run: appends more rows each time. Use the reset SQL in DEMO.md for a clean slate.

do $$
declare
  lm_id uuid; ta_id uuid; tb_id uuid;
  f1 uuid; f2 uuid; f3 uuid; f4 uuid;
begin
  select id into lm_id from profiles where email = 'lm@kaysons.demo';
  select id into ta_id from profiles where email = 'ta@kaysons.demo';
  select id into tb_id from profiles where email = 'tb@kaysons.demo';

  if lm_id is null or ta_id is null or tb_id is null then
    raise exception 'Run DEMO.md A3 (register demo accounts) and A4 (promote roles) before seeding.';
  end if;

  -- 1) OPEN bidding freight, already has two live bids
  insert into freights (created_by, origin, destination_town, cases, weight_kg, internal_calling_bid,
                        bid_opens_at, bid_closes_at, status)
    values (lm_id, 'Hoshiyarpur', 'Ludhiyana', 174, 34, 15000,
            now() - interval '10 min', now() + interval '1 hour 50 min', 'bidding')
    returning id into f1;
  insert into bids (freight_id, transporter_id, amount, state) values
    (f1, ta_id, 14500, 'active'),
    (f1, tb_id, 14200, 'active');

  -- 2) OPEN bidding freight, no bids yet
  insert into freights (created_by, origin, destination_town, cases, weight_kg, internal_calling_bid,
                        bid_opens_at, bid_closes_at, status)
    values (lm_id, 'Jalandhar', 'Amritsar', 160, 28, 11000,
            now(), now() + interval '3 hours', 'bidding')
    returning id into f2;

  -- 3) AWARDED + dispatched, Transporter A won
  insert into freights (created_by, origin, destination_town, cases, weight_kg, internal_calling_bid,
                        status, winner_profile_id, vehicle_number, driver_name, driver_phone, dispatched_at)
    values (lm_id, 'Delhi', 'Gurugram', 120, 20, 9000,
            'awarded', ta_id, 'DL-01-CX-9001', 'Ravi Kumar', '+91 98765 43210',
            now() - interval '30 min')
    returning id into f3;
  insert into bids (freight_id, transporter_id, amount, state) values
    (f3, ta_id, 8500, 'won'),
    (f3, tb_id, 9200, 'lost');

  -- 4) LOCKED with invoice + charges, Transporter B won
  insert into freights (created_by, origin, destination_town, cases, weight_kg, internal_calling_bid,
                        status, winner_profile_id, vehicle_number, driver_name, driver_phone,
                        dispatched_at, locked_at)
    values (lm_id, 'Chandigarh', 'Mohali', 90, 12, 4500,
            'locked', tb_id, 'PB-08-AB-1234', 'Rakesh Kumar', '+91 98765 12345',
            now() - interval '2 hours', now() - interval '30 min')
    returning id into f4;
  insert into bids (freight_id, transporter_id, amount, state) values
    (f4, ta_id, 4800, 'lost'),
    (f4, tb_id, 4200, 'won');
  insert into invoices (freight_id, invoice_number, gr_number, transporter_id, validated)
    values (f4, 'INV-2026-0001', 'GR-7001', tb_id, true);
  insert into freight_charges (freight_id, kind, amount, approved) values
    (f4, 'toll', 450, true),
    (f4, 'club', 100, true);
end $$;
