# Ledger Automation Audit Documentation Plan

## Summary
Create a new markdown document at `docs/ledger-automation-audit.md` that audits every user role’s inputs, how those inputs currently reach the ledger/AI pipeline, what is missing, and how to reduce manual ledger work.

The document will use the repo’s current implementation as source of truth and include a Mermaid flowchart showing how data should move from operational actions into `admin_freight_ledger_view`, analytics, CSV export, and Clawd.

## Documentation Content
- **Current Ledger Pipeline**
  - Explain that the ledger view is built from `freights`, `invoices`, `freight_charges`, `freight_product_lines`, and transporter `profiles`.
  - Explain that Analytics already reads `admin_freight_ledger_view`.
  - Explain that Clawd currently reads base tables, but should also read ledger/reporting views for better freight accounting analysis.

- **Role-by-Role Input Audit**
  - **Admin**
    - User management: roles, approvals, manager assignment.
    - Manual ledger entry: company, party, invoice lines, charges, products, ack, transporter, vehicle.
    - Clawd/daily report triggers.
  - **Accountant**
    - Same ledger/analytics/Clawd capabilities as admin, without admin power.
    - Gap: no edit/approval workflow yet for existing ledger rows.
  - **Logistics Manager**
    - Freight creation, bid/direct assignment, award winner, invoice link, charges, vehicle confirmation, dispatch team assignment.
    - Gap: accepted bid amount is not automatically stored as ledger freight; company/party/bill dates are not captured in operational invoice link yet.
  - **Dispatch Manager**
    - Vehicle confirm, wrong vehicle/driver issue, transit location update.
    - Gap: useful dispatch facts remain operational and do not update accounting/ack fields except vehicle status.
  - **Transporter**
    - Bid amount, vehicle/driver records, dispatch details, pickup invoice proof, GR/e-way, transit location, POD, extra bill reason/photo.
    - Gap: many fields are trapped in `freights.delivery_stages` JSON and do not become structured invoice/ledger rows.

- **Mermaid Flowchart**
  - Include a `flowchart LR` diagram with these nodes:
    - Admin/Accountant manual ledger entry
    - LM freight creation
    - Transporter bid
    - LM award/direct assign
    - Transporter dispatch/pickup/transit/delivery
    - Dispatch manager verification
    - Auto-sync layer
    - `freights`
    - `invoices`
    - `freight_charges`
    - `freight_product_lines`
    - `admin_freight_ledger_view`
    - Analytics / CSV / Clawd
  - Mark current weak links:
    - Winning bid amount not copied to ledger freight.
    - Pickup/delivery proof stuck in `delivery_stages`.
    - Charge kind mismatch: `toll`, `club`, `dalla` vs ledger kinds.
    - Clawd missing ledger views.

## Improvement Plan To Document
- Add an **auto-sync layer** through a database RPC/trigger or shared repository method so clients do not duplicate ledger-sync logic.
- On LM award/direct assign:
  - Store accepted price as `freight_charges(kind='freight')` or make ledger view use winning `bids.amount`.
- Expand LM invoice link:
  - Capture company, party, bill date, dispatch date, vehicle type, base freight, LR/GR, e-way bill, and transporter.
  - Insert/update `invoices` as the primary structured invoice source.
  - Attach charges to `invoice_id` where possible.
- Normalize charge kinds:
  - Map old/current `toll`, `club`, `dalla` into ledger-supported categories such as `toll_tax`, `point_charge`, `out_route`, or `other`.
- Auto-promote transporter stage data:
  - Pickup invoice number/photo creates or updates invoice draft.
  - In-transit/delivered GR and e-way reconcile against invoice rows.
  - Vehicle selection mirrors vehicle type/capacity into freight/ledger fields.
  - Extra bill reason/photo creates a pending `freight_charges` review item.
- Acknowledgement default:
  - When transporter submits POD at delivered stage, set `freights.ack_status = 'received'` and `ack_received_at = now()`.
  - Keep accountant/admin manual override.
- Improve Clawd:
  - Include `admin_freight_ledger_view`, transporter/company/town/ack summary views, and `freight_product_lines` in the Edge Function snapshot.
  - Add AI checks for missing POD, invoice mismatch, delayed dispatch, unapproved extra charges, missing ack, and high PMT.

## Test Cases To Include
- Awarded bid auto-populates accepted freight value in ledger totals.
- LM invoice link creates a complete invoice row visible in the ledger without manual entry.
- Transporter pickup invoice number/photo appears as invoice draft/reconciliation data.
- Transporter delivered POD automatically marks acknowledgement received.
- Charge kinds from LM invoice link appear correctly in `total_freight`.
- Clawd can answer ledger questions using total freight, PMT, delay, ack status, company, town, transporter, and product breakdown.
- Manual ledger entry still works for accountant/admin when operational data is incomplete.

## Assumptions
- Target doc path: `docs/ledger-automation-audit.md`.
- Flowchart format: Mermaid inside markdown.
- Acknowledgement automation default: POD submitted means acknowledgement received, with manual override.
- Primary source for company/party/bill-date/invoice details: expanded LM invoice-link flow.
- Manual ledger entry remains as fallback, but the goal is exception handling, not primary data entry.
