# Kaysons Logistics — Review & Suggestions

Audit across three axes: Flutter code, `userflow.md` spec coverage, and Figma file `q4TnDMnEIPHxl5VAiGTnv8` ("BidPort" in Figma, "Kaysons Logistics" in app).

---

## Critical (fix before shipping)

1. **No auth guards on routes** — `lib/core/routing/app_router.dart`: any deep link reaches `/home`, `/admin`, `/lm/home`. Add GoRouter `redirect` using `AuthService.instance.session` + role.
2. **Registration flow is a dead UI** — `lib/features/auth/register_*.dart` capture Business Name, Owner Name, Email, Bank, Contact but **never insert** into `profiles` / `bank_accounts` / `vehicles` / `drivers` / `documents`. Userflow requires all those fields plus GST, Business Number, Vehicles, Drivers, Documents — screens for those don't exist.
3. **`.env` bundled as Flutter asset** — keys ship inside release APK/IPA. Safe only because it's the anon key + RLS, but still: prefer `--dart-define` build-time injection and remove from `pubspec.yaml` assets.
4. **Logout doesn't sign out** — `transporter/profile_screen.dart:22` navigates to `/welcome` without `AuthService.instance.signOut()`; back button restores the session.
5. **Phone login not supported** — `login_screen.dart:30` rejects anything without `@`, but the copy and userflow §1.1 promise phone-or-email. Either remove phone copy or wire `signInWithOtp(phone:)`.
6. **Invoice link submit routes to `/home`** — `logistics_manager/invoice_link_screen.dart:70` sends logistics managers to the transporter home.

---

## High

7. **Most data is mock** — transporter home, LM home, admin home, analytics, bid setup, bid management, invoice link, afterbid all use hardcoded arrays. Nothing hits `freights`/`bids`/`invoices`/`freight_charges` yet.
8. **No notifications** — userflow §4.3/§8.6 require bid publish, winner, approval alerts. Zero implementation (no FCM, no Supabase realtime subscription wired).
9. **No bidding state machine** — no `bid_opens_at`/`closes_at` enforcement, no penalty flag, no re-bid / manual-assign flow (userflow §4.4 Case A).
10. **No invoice validation / post-lock handling** — userflow §6 and §7 completely unimplemented.
11. **Accounts-manager role is a phantom** — defined in the enum and routed to `/lm/home`. Figma has **no** Accounts Manager frames. Decision needed: drop the role or design/build it.
12. **OTP UX** — 6 boxes fixed at 52×52 overflow on small screens; `_autoFetch` toggle is decorative; no resend timer display fix.
13. **Splash timer not cancelled in `dispose`** — leak risk if user backs out within 2s.
14. **Permissions enum enforced nowhere** — admin toggles `edit_freight` / `view_analytics` / `finalise_booking` / `view_only`, but no screen checks them.

---

## Medium

15. **Admin home doesn't match Figma `69:3978`** — missing KPI tiles, date range picker, line chart, manager filter, color-banded performance list.
16. **Onboarding is 1 of 3 slides** — no pager/dots; Figma has `5:688`, `5:709`, `5:728`.
17. **Missing screens vs Figma**: LM Profile (`25:2026`), LM Fleet (`25:2477`), Admin Profile (`29:4351`), Admin Fleet (`29:5166`), 7 admin bid variants, bid-detail hero (gradient + "Stops in Between" chips + red "Call Bid Manager" CTA), afterbid route-map (`66:3715-3724`), second login variant (`54:3461`).
18. **Theme drift** — `AppColors.primary` is lilac, but Figma primary CTAs on login/registration are **black** pills; outline color `0x1A000000` (10% black) is lighter than Figma's `#CAC4D0`; tint band `0xFFFEF7FF` looks white vs designer `~#F6EDFB`; no danger-red token for "Call Bid Manager"/"Block Transporter".
19. **Typography** — app uses Roboto, Figma uses Inter/SF. Swap `GoogleFonts.robotoTextTheme` → `interTextTheme`.
20. **Inconsistent navigation** — `context.go` vs `context.push` mixed across registration; `analytics_screen.dart:76` uses `Navigator.pop` instead of `context.pop`.
21. **Mock welcome names** — "Welcome Naveen/Lokesh/Admin" hardcoded in all three homes.
22. **Padding grid mismatch** — transporter home uses `fromLTRB(8,8,8,12)` vs Figma 16px grid; section headers use `right: 4`.
23. **No empty / loading / error / offline states** on any list surface.
24. **No live bid board** — Figma implies anonymous ranking updating in real time; no realtime subscription on `bids` even though publication is enabled.
25. **No input validation** in bid-setup, invoice-link forms.
26. **Analytics** — no aggregates, no scheduled reports (userflow §3.3: 15th/30th), no PDF/Excel/CSV export.

---

## Nits

27. Unimplemented Google/Facebook/Apple SSO buttons are live taps that do nothing — disable or implement.
28. `PrimaryButton` hardcoded to 56px; `registration_shell.dart` passes 48px → ignored.
29. Magic color literals in 40+ places; promote to theme.
30. "Demo: Logistics" welcome button actually goes to `/lm/home` (logistics manager, not logistics).
31. Brand: Figma still says "BidPort"; code says "Kaysons". Decide whether to update Figma copy or keep divergence.
32. Dart analyzer currently clean — good. Keep it that way when wiring data.

---

## Userflow spec coverage matrix

| Section | Spec | Implemented | Gap |
|---|---|---|---|
| §1 Auth | Email/phone OTP | Email only | Phone OTP missing |
| §1 Registration | Business/Owner/Email/Biz#/Mobile/GST/Vehicles/Drivers/Docs/Bank | Partial UI, no persistence | GST, Biz#, Vehicles, Drivers, Docs screens absent; no DB writes |
| §1 Admin review | Approve/reject registration | ✅ in `admin/users_screen.dart` | No rejection reason, no email notification |
| §2 Admin | Add/remove users, permissions | ✅ (toggles persist) | Permissions not enforced |
| §2 Admin | Monitor bids, freight lock, invoice map, cost trends | Mock tiles | No data; empty onTaps |
| §3 Analytics | Monthly, per-case, per-unit, match trends, duplicate alerts | Mock UI | No aggregates, no exports, no 15/30 schedule |
| §4 Bidding | Internal calling bid, preferences, publish, notify | Partial UI | No persistence, no notifications |
| §4 Live bid board | Ranking, anonymous competitors | Static | No realtime subscription |
| §4 Time constraint | Penalty, re-bid, manual reassign | ❌ | Not implemented |
| §4 Mid-cost | Toll/club/dalla/other with approval | UI only | No approval workflow |
| §5 Invoice linking | GR/Bilty, transporter, town, weight, cases | Partial UI | No persistence |
| §6 Invoice validation | Alerts, finalize | ❌ | Not implemented |
| §7 Post-lock | Remarks | Mock tile | Not implemented |
| §8 Transporter | Bid notification, view, modify, winner notify | Partial UI | No notifications, no modify flow |

---

## Suggested execution order

1. **Router auth/role guard** + proper logout + splash timer dispose.
2. **Registration persistence**: add GST, Business Number, Vehicles, Drivers, Documents screens; final step inserts rows with `status = pending`; wire Supabase Storage for cheque + docs.
3. **Bid lifecycle**:
   - LM creates `freights` + `freight_preferred_transporters`
   - Transporter home streams `freights` where `status = 'bidding'`
   - Bid detail places/updates `bids` row (one per transporter per freight)
   - LM bid-management subscribes via Supabase Realtime
   - Winner award writes `freights.winner_profile_id`, vehicle/driver dispatch fields
4. **Invoice link + charges persistence** + approval flag + post-lock remarks form.
5. **Decision**: drop `accounts_manager` from role enum or design/build its screens.
6. **Theme pass**: black primary CTA, Inter font, outline token `#CAC4D0`, tint token `#F6EDFB`, danger red token.
7. **Realtime bid board** for transporter + LM screens.
8. **Analytics** against real aggregates (postgres views) + PDF/Excel/CSV export via `syncfusion_flutter_pdf` / `excel` packages.
9. **Notifications** — Supabase Realtime for in-app; FCM for push; Edge Function to send approval/rejection emails.
10. **Permission enforcement** middleware in `app_router` + per-widget gates.

---

## Security follow-ups

- Do NOT store the service_role key anywhere in the Flutter bundle. Keep it server-side (Edge Functions) only.
- Re-run `supabase get_advisors` after every schema change.
- Consider replacing legacy anon JWT with modern `sb_publishable_...` key (Supabase recommends it for new apps).
- Add Supabase Storage buckets with RLS for cheque images and KYC docs before wiring upload UI.
