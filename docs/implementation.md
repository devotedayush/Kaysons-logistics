# Kaysons Logistics — Implementation

Flutter implementation of the Kaysons Logistics freight-bidding app, built from the Figma file `q4TnDMnEIPHxl5VAiGTnv8` and `userflow.md`.

## Stack
- **Flutter** (Material 3, Roboto via `google_fonts`)
- **go_router** — declarative routing
- Pure widgets, no state-mgmt library yet (sample data inline; ready to swap in Riverpod/Provider later)

## Project layout

```
lib/
├── main.dart                       # MaterialApp.router root
├── core/
│   ├── theme/app_theme.dart        # M3 theme, purple #CB97FF primary
│   ├── routing/app_router.dart     # All go_router routes
│   └── widgets/
│       ├── primary_button.dart     # Black/Purple/Outlined CTA pill
│       ├── pill_text_field.dart    # 28-radius outlined text input
│       └── social_button.dart      # Google/Facebook/Apple outlined
└── features/
    ├── onboarding/                 # Splash → Welcome
    ├── auth/                       # Login + OTP + 5-step register
    ├── transporter/                # Bidder role
    ├── logistics_manager/          # Freight publisher / bid runner
    └── admin/                      # Platform oversight
```

## Routes (`lib/core/routing/app_router.dart`)

| Path | Screen |
|------|--------|
| `/` | Splash (auto-advances after 2s) |
| `/welcome` | Onboarding welcome (incl. demo links to all 3 roles) |
| `/login` → `/otp` | Email/phone entry → 5-digit OTP w/ 60s countdown |
| `/register`, `/register/{password,name,bank,contact}` | 5-step registration |
| `/home`, `/fleet`, `/profile` | Transporter screens |
| `/bid/:id`, `/bid/:id/after` | Live bidding + post-close status |
| `/lm/home`, `/lm/bid/new`, `/lm/bid/:id`, `/lm/bid/:id/invoice` | Logistics Manager flow |
| `/admin`, `/admin/users`, `/admin/analytics` | Admin flow |

## Implemented screens

### Onboarding & Auth
- **Splash** — Kaysons wordmark + circular progress, redirects to `/welcome`.
- **Welcome** — illustration tile, "Login with email/mobile" (black) and "Register with us" (purple) CTAs split by an OR divider; demo-shortcut row for all three role homes.
- **Login** — pill email/phone input, "Get OTP" → `/otp`; Google/Facebook/Apple outlined buttons.
- **OTP** — 5 pill input boxes with auto-advance focus, live MM:SS countdown (red), Resend enables at 00:00, "Couldn't login? Contact admin".
- **Registration (5 steps)** — Email → Password+T&C checkbox → Name+Company → Bank holder/account+blank-check upload → Mobile+landline. Shared `RegistrationShell` (`features/auth/registration_shell.dart`) renders step indicator, title, subtitle, Next CTA, "Go Back" footer.

### Transporter (`features/transporter/`)
- **Home** — Welcome + Latest Bids list (route, QT/WT/Freight, anonymous bidder count, time-left turning red <30 min) + Won Bids horizontal carousel + Quick Options 2×2 grid.
- **Bid Detail** — Hero with route, time-left & stops chips, "Live Bidding" lowest price, Asc/Desc segmented sort, bidder list with stars + reputation, Add-your-Bid input → submits to Afterbid.
- **Afterbid** — "BIDDING CLOSED" + winning price, winner card (5 stars, company, success rate), 4 status steps (Dispatched → Pickup → In Transit → Delivered), red Call Bid Manager CTA.
- **Fleet** — "Bids Won" list with overline status (Dispatched / Not Yet Dispatched / Penalized), route, QT/WT/Freight.
- **Profile** — hero with avatar + Verified/Successful-bids chips, Edit Self/Business, Help, Logout.
- **Bottom nav** — Dashboard / Bids / Fleet pill nav (`widgets/transporter_bottom_nav.dart`), reused by LM screens.

### Logistics Manager (`features/logistics_manager/`)
- **Home** — Welcome Lokesh + Latest Bids + Completed Bids (with winning price) + User Requests list (approve/reject icons) + Quick Options + FAB **Publish bid**.
- **Bid Setup** — From/To, Cases/Weight, Base Freight, optional anonymous internal calling bid, transporter preference filter chips, publishes to bid management.
- **Bid Management** — Bidder radio list (stars + price) → tapping a bidder reveals inline **Dispatch form** (Vehicle Number, Driver Name, Driver Phone) → confirms to invoice link.
- **Invoice Link** — Invoice Number, GR/Bilty, plus mid-cost adjustments (toll, club, dalla, other) submitted for admin approval (per userflow §5/§4.5).

### Admin (`features/admin/`)
- **Home** — KPI tiles (active bids, monthly freight, pending approvals — pending shown in red), 6 quick-action cards (Users / Analytics / All Bids / Freight Lock / Invoice Mapping / Alerts), Pending review list (mid-cost adjustments, post-lock remarks, new transporter requests).
- **Users** — Tabbed (Users / Pending). Expand a row to toggle permissions (Edit Freight / View Analytics / Finalise Booking / View Only) via filter chips; remove user button.
- **Analytics** — Stat cards (monthly freight, per-case/per-unit, invoice match%), transporter business-volume bars, situation-wise freight-match bars (within / above / penalty), duplicate-freight alert tiles, PDF/Excel/CSV export bottom sheet.

## How Figma was translated

For each screen I called the Figma MCP `get_design_context` (`q4TnDMnEIPHxl5VAiGTnv8` + node id) to fetch the React+Tailwind reference, screenshot, and design tokens. The output was used as a *visual spec only* — translated by hand to idiomatic Flutter widgets (`Scaffold`, `ListView`, `Stack`, etc.) using the project's shared widgets and the M3 theme. Hardcoded mockup placeholder images were replaced with `Container`s and Material icons. The "BidPort" name from the mockups was replaced everywhere with **Kaysons** per the user's instruction.

## Sample data

Lives inline in feature folders (`transporter/models/bid_summary.dart`, list literals in LM/Admin home screens). Replace with API integration when backend is ready — the screens already accept the relevant model types.

## What's stubbed / not yet built

- **Backend & state management** — no API layer; everything is local sample data. Add Riverpod + Dio next.
- **Auth** — login/register submit just navigates forward; no token persistence.
- **Bid Detail variants** — Figma has 4 variants per role showing different bid states (open, ascending leaderboard, after submission, etc.). Implemented as a single screen that handles state via the input + sort, not 4 separate screens.
- **Drivers / Vehicle / Bid History / Invoice History** sub-screens linked from Quick Options — placeholder taps only.
- **Notifications & settings icons** — wired but no destinations.
- **Accounts Manager role** — userflow lists 4 roles; only Transporter/LM/Admin have screens (Accounts Manager wasn't in Figma).
- **Reporting export** — UI present, no actual file generation.

## Running

```bash
flutter pub get
flutter run
```

Splash → Welcome. From Welcome you can tap **Demo: Transporter / Logistics / Admin** to jump directly into each role flow without going through auth.
