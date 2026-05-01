# Kaysons Logistics — Demo Script

Live 8-minute demo. App is wired to Supabase (project `rdfjfvtaehykzbuahjce`). Every tap persists and streams live.

**Auth**: email + password. **No OTP.** Email confirmation is turned OFF in Supabase.

---

## Part A — Pre-flight (do this BEFORE the demo)

### A1. Supabase: confirm email OFF

Dashboard → **Authentication → Providers → Email** → **Confirm email: OFF** → Save.

If some accounts were created while the toggle was ON, run:

```sql
update auth.users set email_confirmed_at = now();
```

### A2. Build & boot the app

```bash
cd "/Volumes/New Volume/code-external/Rajesh Freelance/logistics"
flutter pub get
flutter run            # pick a device; -d chrome is fastest for a single screen
```

For a two-device story (impressive but optional):

```bash
flutter devices
flutter run -d <device-1-id>   # terminal 1
flutter run -d <device-2-id>   # terminal 2
```

Or install the built APK on a phone:

```bash
adb install -r "dist/kaysons-arm64-v8a-release.apk"
```

### A3. Seed four demo accounts (≈3 min)

One password for everyone: `demopass123`. Emails are fake — no inbox needed.

| Role | Email | Password |
|---|---|---|
| Admin | `admin@kaysons.demo` | `demopass123` |
| Logistics Manager | `lm@kaysons.demo` | `demopass123` |
| Transporter A | `ta@kaysons.demo` | `demopass123` |
| Transporter B | `tb@kaysons.demo` | `demopass123` |

For each row:

1. **Welcome → Register with us** → walk the 5 steps:
   - Email → Password (twice + accept terms) → Name + Company → Bank → Contact
2. **Submit** → you're instantly signed in as `transporter / pending`.
3. Profile → **Logout**.

### A4. Promote roles + approve (one SQL run)

Supabase → SQL editor → New query → paste + run:

```sql
update profiles set role = 'admin',             status = 'approved' where email = 'admin@kaysons.demo';
update profiles set role = 'logistics_manager', status = 'approved' where email = 'lm@kaysons.demo';
update profiles set role = 'transporter',       status = 'approved', business_name = 'Jagdamba Enterprises' where email = 'ta@kaysons.demo';
update profiles set role = 'transporter',       status = 'approved', business_name = 'Karan Transport'      where email = 'tb@kaysons.demo';
```

### A5. (Optional) Pre-load fake freights, bids, invoices

If you want the LM home and transporter Fleet tabs to have rich-looking history **before** you walk on stage, run `seed_demo_data.sql` (same SQL editor). It creates:

- 1 open bidding freight with two live bids (so the transporters can still place their own on top)
- 1 open freight with no bids yet (so you can demo "first to bid")
- 1 awarded + dispatched freight (Transporter A won)
- 1 fully locked freight with invoice + toll/club charges (Transporter B won)

**Note:** every Act in Part B still works on top of this — the "Act 3 publish + Act 4 bid" freight is a *new* row you create live. The seeded rows just make the background richer.

```sql
-- Copy-paste the entire block below, or run the file `db/seed_demo_data.sql` (same content).
-- Safe to run repeatedly: re-running appends more rows. Use the reset SQL first if you want a clean slate.

do $$
declare
  lm_id uuid; ta_id uuid; tb_id uuid;
  f1 uuid; f2 uuid; f3 uuid; f4 uuid;
begin
  select id into lm_id from profiles where email = 'lm@kaysons.demo';
  select id into ta_id from profiles where email = 'ta@kaysons.demo';
  select id into tb_id from profiles where email = 'tb@kaysons.demo';

  if lm_id is null or ta_id is null or tb_id is null then
    raise exception 'Run A3 (register demo accounts) and A4 (promote roles) before seeding.';
  end if;

  -- 1) OPEN, already has two live bids
  insert into freights (created_by, origin, destination_town, cases, weight_kg, internal_calling_bid, bid_opens_at, bid_closes_at, status)
    values (lm_id, 'Hoshiyarpur', 'Ludhiyana', 174, 34, 15000,
            now() - interval '10 min', now() + interval '1 hour 50 min', 'bidding')
    returning id into f1;
  insert into bids (freight_id, transporter_id, amount, state) values
    (f1, ta_id, 14500, 'active'),
    (f1, tb_id, 14200, 'active');

  -- 2) OPEN, no bids yet
  insert into freights (created_by, origin, destination_town, cases, weight_kg, internal_calling_bid, bid_opens_at, bid_closes_at, status)
    values (lm_id, 'Jalandhar', 'Amritsar', 160, 28, 11000,
            now(), now() + interval '3 hours', 'bidding')
    returning id into f2;

  -- 3) AWARDED + dispatched (Transporter A won)
  insert into freights (created_by, origin, destination_town, cases, weight_kg, internal_calling_bid,
                        status, winner_profile_id, vehicle_number, driver_name, driver_phone, dispatched_at)
    values (lm_id, 'Delhi', 'Gurugram', 120, 20, 9000,
            'awarded', ta_id, 'DL-01-CX-9001', 'Ravi Kumar', '+91 98765 43210',
            now() - interval '30 min')
    returning id into f3;
  insert into bids (freight_id, transporter_id, amount, state) values
    (f3, ta_id, 8500, 'won'),
    (f3, tb_id, 9200, 'lost');

  -- 4) LOCKED with invoice + charges (Transporter B won)
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
```

The same SQL is mirrored at `db/seed_demo_data.sql` in the repo so you can re-run it easily.

### A6. Tabs to keep open during the demo

- App(s) on device(s)
- Supabase → **Table editor → `freights`** (proof tab)
- Supabase → **Table editor → `bids`** (proof tab)
- `DEMO.md` on a side monitor (glance, don't read)

---

## Part B — Live demo (8 min)

### Act 1 — New transporter joins (2 min)

**Do**

1. Fresh app → **Welcome** → **Register with us**.
2. Walk the 5 steps:
   - email: `live@kaysons.demo`
   - password: `demopass123` (twice) + accept terms
   - name: `Iqbal Qureshi`, company: `Iqbal Transports`
   - bank: holder name + account number
   - contact: mobile + BRN + GST (optional)
3. **Submit** → instantly on transporter home.

**Say**

> *"No OTP, no email confirmation — tapping Submit just wrote the profile and bank details straight into Postgres."*

(Optional flex: flip to the dashboard `profiles` tab, show the new row with `status = pending`.)

### Act 2 — Admin reviews & approves (1 min)

**Do**

1. Transporter profile → **Logout**.
2. Login as `admin@kaysons.demo` / `demopass123` → **Admin console**.
3. Tap **Users** row.
4. **Pending** tab → Iqbal's row → **Approve** → he moves to the **Users** tab.
5. Expand his row → toggle a permission chip — it persists.

**Say**

> *"Row-level security makes this admin-only. A transporter token calling the same endpoint gets rejected by Postgres — not by app code."*

### Act 3 — LM publishes a bid (2 min)

**Do**

1. Logout → login as `lm@kaysons.demo` / `demopass123` → LM home.
   - (If you seeded, you already see 4 freights with different statuses — good material for a "here's the history" sentence.)
2. Tap **Publish bid** (FAB).
3. Fill:
   - From: `Hoshiyarpur`
   - To: `Ludhiyana`
   - Cases: `174`, Weight: `34`
   - Base freight: `6500`
   - Internal calling bid: `15000`
   - Preferences: leave empty (open to all) **or** chip-pick Jagdamba + Karan.
4. Tap **Publish** → bid management screen opens; status `bidding`, bidders list empty.

**Say**

> *"One tap wrote to `freights`, started a 2-hour bidding window, and is now broadcasting to every subscribed transporter via Supabase Realtime."*

### Act 4 — Transporters bid live (2 min)

*(Device 2, or sign in on the same device.)*

**Do**

1. Login as `ta@kaysons.demo`. Transporter home already shows the new freight (no refresh).
2. Tap it → hero header with the route.
3. Enter `14500` → **Place bid**.
4. Swap to `tb@kaysons.demo` → same freight → bid `14200`.

*(Back on LM device — no refresh, no tap.)*

5. Bidders list shows both bids, sorted ascending. Lowest at top.

**Say**

> *"Two devices, zero custom websocket code. Supabase publishes the `bids` table; every subscribed client receives the row on commit."*

### Act 5 — Award, dispatch, invoice, lock (1 min)

**Do**

1. LM bid management: tap **Karan Transport** → dispatch form slides in.
2. Vehicle `PB-08-AB-1234`, driver `Rakesh Kumar`, phone `+91 98765 43210`.
3. **Confirm dispatch** → freight → `awarded`, winning bid → `won`, other → `lost`.
4. Routes to **Link invoice**.
5. Invoice `INV-2026-0042`, GR `GR-7821`, Toll `450`, Club `100`.
6. **Submit & lock freight** → freight → `locked`; invoice + charges saved.

**Say**

> *"One row in `freights` moved through five states — bidding → awarded → locked — with foreign-key rows in `bids`, `invoices`, and `freight_charges`. Close the app and reopen, state survives."*

### Closing beat

> *"Figma flows wired end-to-end to Supabase in one session: schema, RLS, realtime, auth. Still on the list — notifications, analytics aggregates, PDF/CSV export, post-lock remarks. All in `suggestion.md`."*

---

## Part C — Contingency & Q&A

### If realtime stalls on one device

The transporter shell doesn't pull-to-refresh the bids stream, but swiping the bottom-nav to another tab and back re-subscribes. That clears most stale-state issues.

### If a demo account's password is forgotten mid-demo

```sql
-- Supabase can't reset passwords via SQL. Easiest path: delete + re-register.
delete from auth.users where email = 'X@kaysons.demo';
```

Then re-register via the app and re-run the A4 promote SQL.

### Reset state between runs

```sql
-- Wipe all freight/bid/invoice state. Keeps users and bank_accounts.
truncate freight_charges, invoices, bids, freight_preferred_transporters, freights restart identity cascade;
```

After this, re-run the **A5 seed SQL** if you want the pre-populated rows back.

### Nuclear reset (wipe users too)

```sql
truncate freight_charges, invoices, bids, freight_preferred_transporters, freights,
  bank_accounts, vehicles, drivers, documents, profiles restart identity cascade;
delete from auth.users where email like '%@kaysons.demo';
```

After this you have to redo A3 + A4 + (optionally) A5.

### Likely questions

**Q: Where's the server?** — Supabase. Postgres + Auth + Realtime. No Node backend.

**Q: How are permissions enforced?** — Postgres RLS policies keyed on `auth.uid()` and a `public.current_role()` helper. Admin UI persists permission chips into a `permissions` array column; per-screen enforcement is in the backlog.

**Q: What if the network drops mid-bid?** — `upsert` on `(freight_id, transporter_id)` is idempotent; retrying is safe. No offline queue yet.

**Q: Is this production-ready?** — No. See `suggestion.md`: notifications, analytics aggregates, scheduled reports, post-lock UI.

**Q: Can I see the DB?** — Dashboard → Table editor → `freights` / `bids` / `profiles`.

---

## Part D — Known gaps (don't volunteer unless asked)

- `AfterbidScreen` timeline steps are static copy (not driven by real status yet)
- Analytics screen shows mock aggregates
- Notifications: none — no FCM, no in-app toasts for "bid published", "you won", etc.
- Registration password is never re-verified — by design for this demo

---

## Part E — Rehearsal checklist

- [ ] Supabase `Confirm email` toggle is **OFF**
- [ ] 4 accounts registered via the app + A4 promote SQL ran (verify with `select email, role, status from profiles;`)
- [ ] Optional: A5 seed SQL ran (verify with `select count(*) from freights;`)
- [ ] `truncate … freights restart identity cascade;` run if you want a clean slate, plus re-seed if desired
- [ ] Two devices/emulators connected, both logged out
- [ ] Supabase Table editor open on a spare monitor
- [ ] One full rehearsal (Act 1 → Act 5) done without reading this script
- [ ] Laptop charged, Wi-Fi solid, HDMI cable handy
