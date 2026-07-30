# Testing and store-asset checklist

## Included graphics

| Asset | File | Status |
|---|---|---|
| Play icon, 512 × 512 PNG | `assets/app-icon-512.png` | Ready from supplied official mark |
| Feature graphic, 1024 × 500 PNG | `assets/feature-graphic-1024x500.png` | Ready; review final brand presentation |
| Official wordmark source | `assets/kaysons-official-logo.png` | Ready |
| Phone screenshots | `assets/screenshots/phone/` | Ready; 7 genuine 432 × 768 app captures |
| 7-inch tablet screenshots | Not generated | Optional unless tablet targeting/quality requires them |
| 10-inch tablet screenshots | Not generated | Optional unless tablet targeting/quality requires them |
| Promo video | Not generated | Optional |

Do not use fabricated UI mockups as screenshots. Capture the signed release
with review-safe data so screenshots match the current app.

## Captured phone screenshots

All captures use the real Flutter mobile layout at 432 × 768 pixels, which is
inside Google Play's accepted phone-screenshot size and aspect-ratio range.
Only synthetic demo routes and dedicated Google Play reviewer identities are
visible.

1. `01-transporter-home.png` — transporter overview
2. `02-awarded-freight.png` — delivered freight milestones
3. `03-logistics-dashboard.png` — logistics-manager summary and quick links
4. `04-logistics-bids.png` — closed bid list and publish action
5. `05-delivery-tracking.png` — delivery progress
6. `06-account-privacy-path.png` — discoverable mobile account/privacy menu
7. `07-account-deletion-controls.png` — privacy and deletion screen

The first five are suitable store-listing candidates. The last two are useful
for policy review and account-deletion evidence; include them in the store
listing only if privacy controls are part of the marketing story.

## Recommended phone screenshots

Capture portrait screenshots without device frames:

1. Transporter dashboard — open and won freight
2. Freight bid details
3. Fleet/active delivery view
4. Logistics-manager dashboard
5. Bid publishing or management
6. Dispatch tracking and vehicle verification
7. Ledger or analytics view, if legible on the release phone layout
8. Role-aware navigation/profile

Remove or replace real names, phone numbers, bank details, Aadhaar, GST,
vehicle plates, invoices, e-way bills and customer information before capture.

## Functional release test matrix

### Authentication

- Register a transporter
- Confirm pending approval behavior
- Sign in and sign out
- Verify incorrect password and unapproved account handling
- Verify every reviewer credential from a clean install
- Open Account & privacy from each role
- Submit and cancel an in-app deletion request
- Submit a request from the public webpage without signing in

### Transporter

- Browse and filter bids
- Submit/update a bid
- Add/edit vehicle and driver
- Open awarded freight
- Upload each required document type
- Save dispatch, pickup, transit and delivery milestones

### Logistics and dispatch

- Publish and edit a freight requirement
- Prefer/block transporters
- Award a bid
- Assign/remove dispatch managers
- Confirm vehicle arrival and raise an issue
- Review delivery stages and update transit location

### Accountant and admin

- Review ledger data
- Add/edit a ledger entry
- Verify report/CSV behavior where supported
- Review analytics and notifications
- Approve/reject users and change roles
- Verify Clawd failure and success states

### Device and reliability

- Android 7/API 24 device or emulator
- Android 16/API 36 device or emulator
- ARM64 physical phone
- Offline/poor-network behavior
- Rotation, keyboard and small-screen layout
- File picker denial/cancellation
- Large image/document upload
- App restart with an existing session
- Upgrade install over the internal-test build

## Pre-production checks

- No production secrets other than a public Supabase client key are bundled
- Supabase RLS and storage policies are deployed and verified
- Edge Function service-role and AI keys remain server-side
- Demo/reviewer accounts contain no real customer data
- Account deletion request paths work
- Privacy and deletion URLs load without authentication
- Support inbox is monitored
- Play pre-launch report has no blocking crashes or accessibility issues

## Official references

- Android app signing:
  https://developer.android.com/studio/publish/app-signing
- Target API requirements:
  https://developer.android.com/google/play/requirements/target-sdk
- Play app-content preparation:
  https://support.google.com/googleplay/android-developer/answer/9859455
- Data safety:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Account deletion:
  https://support.google.com/googleplay/android-developer/answer/13327111
- Preview assets:
  https://support.google.com/googleplay/android-developer/answer/9866151
- New personal account testing:
  https://support.google.com/googleplay/android-developer/answer/14151465
