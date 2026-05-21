Here’s the condensed project/chat summary and the main design decisions we took.

**Supabase / Backend**
Supabase MCP is connected to project:

`https://rdfjfvtaehykzbuahjce.supabase.co`

We added/confirmed backend support for:
- `dispatch_manager` role
- `profiles.manager_id` to connect each dispatch manager to one logistics manager
- RLS so dispatch managers only see accepted deliveries under their assigned logistics manager
- RLS so dispatch managers cannot see or manage bids
- LM-side permission so logistics managers can assign registered users as dispatch managers under themselves
- Freight ledger fields on `freights`
- Invoice ledger fields on `invoices`
- `freight_product_lines` for dynamic product/category quantities
- Reporting views:
  - `admin_freight_ledger_view`
  - `admin_transporter_summary_view`
  - `admin_company_summary_view`
  - `admin_town_summary_view`
  - `admin_ack_summary_view`

**Auth Decisions**
We temporarily stopped OTP work.
Current auth direction:
- Use email + password signup/login for now
- Keep OTP work/documentation around, but do not use it in the active login flow yet
- Phone OTP requires SMS provider setup later

Demo accounts checked:
- `admin@kaysons.demo`
- `lm@kaysons.demo`
- `ta@kaysons.demo`
- `tb@kaysons.demo`

Password shown by you:
`demopass123`

**Dispatch Manager Design**
We added a new `dispatch_manager` role.

Decision:
- Dispatch manager sits under exactly one logistics manager.
- Admin can assign dispatch managers.
- Logistics manager can also add dispatch managers under themselves.
- Dispatch manager gets LM-like tracking/fleet access, but no bidding access.

Dispatch manager can:
- See accepted/awarded deliveries for their LM
- Confirm vehicle arrival
- Raise vehicle/driver mismatch issue
- Update transit location

Dispatch manager cannot:
- See bids
- Create bids
- Award bids
- Publish freight
- Edit bid window
- Link invoices
- Access admin routes

Routes added:
- `/dm/home`
- `/dm/fleet`
- `/dm/profile`
- `/dm/track/:id`

LM also got:
- `/lm/dispatch`
- Dispatch team screen for assigning registered transporter users as dispatch managers

**Freight Ledger / Admin Analytics Design**
We inspected demo Excel files in `docs/Demo Data/`.

Key conclusion:
The client’s real workflow is not only bid tracking. They also need a monthly freight accounting ledger similar to Excel.

We decided:
- Do not create a totally separate freight system.
- Extend existing `freights`, `invoices`, and `freight_charges`.
- Store spreadsheet-style product columns as dynamic rows in `freight_product_lines`.
- Build reporting views for admin dashboard/CSV instead of calculating everything only in Flutter.

Ledger supports:
- Company
- Party/customer
- Bill date
- Dispatch date
- Delay
- Invoice number
- E-way bill
- LR/GR number
- Town
- Cases
- Weight/MT
- Vehicle number/type
- Transporter
- Freight
- Extra freight
- Labour
- Detention
- Toll tax
- Point charge
- Out-route charge
- Deduction
- Total freight
- Acknowledgement status
- Remarks
- Product/category breakdown

Admin UI added:
- Admin Ledger tab at `/admin/ledger`
- Filters by date, company, transporter, town, acknowledgement status, delayed only
- Manual ledger entry form
- Multiple invoice lines
- Multiple charges
- Product rows
- CSV export

CSV decision:
- CSV first, Excel/PDF later
- Export file format:
  `kaysons-freight-ledger-YYYY-MM-DD.csv`

**Analytics Design**
We replaced mocked analytics with Supabase-backed ledger data.

Analytics now uses:
- `admin_freight_ledger_view`

Shows:
- Total freight
- Cases
- MT/weight
- PMT
- Pending acknowledgements
- Transporter-wise freight volume
- Company-wise freight
- Town-wise freight
- Delay/ack alerts

**Important Technical Fixes**
We fixed a Supabase RLS recursion issue:
- Error was: infinite recursion detected in policy for `profiles`
- Fixed by moving dispatch manager related profile read logic into a private security-definer helper function.

We also verified:
- `flutter analyze --no-pub` passes
- `flutter build web --no-pub` passes
- Local server has been run on:
  `http://127.0.0.1:8081`

**Current Caveats**
- Worktree contains multiple changes from OTP, dispatch manager, ledger, and Supabase skill install work.
- Supabase advisor still reports pre-existing security warnings:
  - public `SECURITY DEFINER` functions
  - leaked password protection disabled
- OTP is not active right now.
- Ledger import from Excel is not implemented yet; only in-app data entry and CSV export are in scope for v1.
- CSV export is implemented for web.