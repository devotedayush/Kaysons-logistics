# Kaysons login and access

## Current implementation

The login screen supports email and password, plus phone OTP sign-in. Phone numbers are normalized to Indian E.164 format (`+91XXXXXXXXXX`), OTP login uses `shouldCreateUser: false`, and the user enters a six-digit code. Resend is disabled for 60 seconds after sending.

Approved users can link or change their phone from **Account settings → Manage phone number**. Supabase sends a phone-change code to the new number. The app does not treat the number as linked until the code is verified and Supabase reports the phone as confirmed. The verified Auth phone is the credential used for phone OTP login. A phone number stored only in `profiles.phone` is not proof of ownership and cannot be used as the login credential.

New transporter registration asks for a name, mobile number and consent. Contact email is optional and is labeled as contact information, not a login credential. No password, bank documents, GST or vehicle paperwork is required initially. Registration sends an SMS code using `signInWithOtp(phone: ..., shouldCreateUser: true)` and verifies it as `OtpType.sms`. The Auth trigger creates a pending transporter profile. Verification checks the confirmed Auth phone against the requested number, and profile completion updates only a pending profile without changing its role or status. Existing approved accounts enter their assigned area; existing rejected accounts remain rejected. If verification succeeds but a later profile read or save fails, a retry reuses the authenticated, confirmed matching-phone session rather than consuming the code again. A verified registration remains pending until an admin approves it.

The app also has AuthService methods for email OTP, but the login screen does not currently offer email OTP. Email and password remain available.

## Approval and roles

The agreed policy is admin approval for every operational role. Public registration is for transporters. Users enter their identity/contact details but cannot assign themselves staff or admin permissions. Existing admins review a request and choose the actual role; staff should use a company-approved account and be assigned by an admin. No role gets immediate access to bids, dispatch, financial records, or administration solely from phone verification.

New registrations start with a `pending` profile. A pending or rejected profile cannot use operational features. Phone OTP verifies control of a phone number; it does not approve the account or grant a role.

An approved profile is routed by role:

| Role | App area |
| --- | --- |
| `transporter` | `/home` |
| `logistics_manager` | `/lm/home` |
| `dispatch_manager` | `/dm/home` |
| `accountant` | `/acct/ledger` |
| `admin` | `/admin` |

An authorized admin manages users in **Admin → Users**:

1. Open the **Pending** tab and review the profile.
2. Choose the role before approving. A dispatch manager must also be assigned to a logistics manager.
3. Choose **Approve** to grant operational access, or **Reject** to keep the account blocked.
4. The approved-users list lets admins change a role later.

The app checks approval after sign-in and when restoring a saved session. Supabase Row Level Security also checks that the profile is approved before returning an operational role, so the UI route alone does not grant database access. Role and approval fields cannot be changed by the profile owner.

**Remove** in Admin → Users deletes the profile row only. It does not delete the Supabase Auth user, remove its phone credential, or revoke its existing Auth sessions. Use **Reject** to block operational access while retaining the user record. Full account removal requires a server-side Auth user deletion or disable operation with session revocation; the current admin screen does not perform that operation.

## Local phone-first verification status

The new phone-first flow has passed local analyzer and automated tests for consent, Hindi rendering, existing approved/rejected account preservation and retry behavior. The live Auth trigger, nullable profile email, guarded self-update policy, bank self-access policy and own-folder Storage policy were inspected for compatibility. Live SMS signup and the complete new registration/deferred-profile journey have not been tested on a handset in this change. The historical delivery result below covers the older flow and does not verify the new signup journey.

## AWS and Supabase SMS status

The `send-sms-otp` Supabase Edge Function v5 is deployed and uses the dedicated AWS identity `kaysons-supabase-otp` with SNS in Mumbai (`ap-south-1`). AWS credentials belong in Supabase function secrets and must never be placed in the Flutter app.

The hosted Supabase Phone provider and signed HTTPS Send SMS Hook are enabled. Phone confirmations are required; OTPs have six digits and expire after 300 seconds. The project SMS rate limit remains 30/hour. On 2026-10-01, a real Auth OTP reached the authorized test handset and verification returned HTTP 200 with a confirmed phone. The pending test profile could read its own role/status and received no protected bids. The test session was signed out. The updated web app was published and promoted to https://kaysons-logistics.vercel.app on 2026-10-01 (deployment `dpl_84kSvfGhmkiWpMT7VjX1YaYNsmVC`). Public HTML returns 200, the served JavaScript/bootstrap hashes match the verified local build, and the production OTP screen renders the admin-approval guidance. The signed Android 1.0.1 (2002) ARM64 APK is available in `output/releases/kaysons-otp-1.0.1-2002-arm64.apk`; its signature matches the existing release certificate. Device installation and Google Play publication have not been performed.

The first live request hit the five-second Auth hook timeout. Version 5 resolves pinned SDK imports during deployment and reuses the SNS client. Its first unsigned probe returned 401 in 2.98 seconds (previously 4.78 seconds); a real OTP request then returned 200. One controlled test is not a long-term latency guarantee. Always use the newest SMS code after requesting a resend.

The AWS SMS route has a `$0.10` `MaxPrice` setting and an existing `$50` monthly spend limit. The active `india-international` route delivered the test SMS without a domestic sender ID. A branded domestic India route requires DLT sender and template registration, which has not been completed. Do not raise the AWS spend limit without reviewing expected volume and cost.

## Intended user journey

1. A new transporter chooses Register, enters their name and mobile, accepts the registration/contact consent, and verifies their mobile with the SMS code. Contact email is optional.
2. The application is submitted as pending. This grants no access to bidding or internal company data. The confirmation screen offers optional profile completion: business/GST/contact details, bank holder/account/IFSC and a cheque image. These details can also be added after approval. A contact email does not create an email Auth identity.
3. An existing admin opens Admin → Users, reviews the application, selects the appropriate role and (for dispatch managers) reporting manager, then approves or rejects it.
4. An approved user enters their verified mobile and the newest SMS code. The app loads the assigned role and opens its permitted area.
5. Existing email/password users can continue using that login and link a phone in Account settings. Never copy an unverified contact phone into the Auth credential.
6. If an admin rejects a user later, database authorization blocks operational access; the app checks approval when entering protected routes or restoring a session.

A person may request a different identity from the admin, but the final access role is assigned by the admin. There is no public self-service admin registration.

## Phone linkage and data model

Phone numbers may remain in `profiles.phone` as registration/contact data. A profile update must not copy an unverified number into Supabase Auth. The former `sync_profile_phone_to_auth_user` trigger was removed by migration `20261001165557_stop_profile_phone_auth_sync.sql`; do not restore it. New accounts use phone SMS signup verification. Existing accounts link or change their Auth phone through the authenticated phone-change verification flow, which updates the Auth phone only after the user proves control of it. The profile screen shows the Auth phone read-only and links to Manage phone number.

The `profiles.phone` column has a unique index when populated. Keep the Auth phone as the source of truth for OTP sign-in, and make any contact-data synchronization an explicit post-verification step.

## Setup checklist

1. Enable phone authentication for the hosted Supabase project.
2. Configure the Supabase Send SMS Hook to invoke `send-sms-otp` and validate the hook signature.
3. Confirm the function uses the intended AWS region, identity, `MaxPrice`, and monthly spend limit.
4. Complete India's DLT sender and message-template registration before domestic delivery.
5. Verify delivery to an authorized test handset, then verify the code in the app and confirm the Auth phone is marked verified.
6. Test a pending, rejected, and approved user, including a restored session after the profile status changes.

Do not put AWS access keys, Supabase service-role keys, or SMS hook secrets in Flutter assets, source files, or client environment variables.

## References

- [Supabase Flutter `signInWithOtp`](https://supabase.com/docs/reference/dart/auth-signinwithotp)
- [Supabase Flutter `verifyOTP`](https://supabase.com/docs/reference/dart/auth-verifyotp)
- [Supabase phone login](https://supabase.com/docs/guides/auth/phone-login)
- [Supabase Send SMS Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)
