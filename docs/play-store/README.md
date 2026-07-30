# Google Play submission pack

This directory contains the working material for publishing Kaysons Logistics
to Google Play.

## Ready artifacts

- Signed Android App Bundle:
  `build/app/outputs/bundle/release/app-release.aab`
- Play icon: `assets/app-icon-512.png`
- Feature graphic: `assets/feature-graphic-1024x500.png`
- Official supplied logo: `assets/kaysons-official-logo.png`
- Public upload certificate: `assets/upload-certificate.pem`
- Store copy: `STORE_LISTING.md`
- Play Console declarations: `PLAY_CONSOLE_ANSWERS.md`
- Privacy-policy draft: `PRIVACY_POLICY_DRAFT.md`
- Release procedure: `RELEASE_RUNBOOK.md`
- Testing and graphics checklist: `TESTING_AND_ASSETS.md`

## Publication blockers that require an owner decision

Do not submit to production until these are completed:

1. Replace every `[REQUIRED: ...]` field in the policy and Console documents.
2. Obtain legal approval for the privacy policy and publish it at a public URL.
3. Add a working in-app account-deletion request path and a public web deletion
   request URL. Account creation exists, so both are required by Google Play.
4. Create permanent reviewer accounts for every role that needs review.
5. Capture phone screenshots from the signed release connected to production or
   review-safe data.
6. Confirm that `com.kaysons.kaysons_logistics` is the permanent package ID.
   It cannot be changed after the first Play upload.
7. Back up `android/upload-keystore.jks` and `android/key.properties` in
   separate secure locations. They are intentionally excluded from Git.

## Current release identity

- App name: Kaysons Logistics
- Package ID: `com.kaysons.kaysons_logistics`
- Version name: `1.0.0`
- Version code: `1`
- Minimum Android: API 24
- Target Android: API 36
- Ads: No
- Category: Business
- Intended audience: Adults operating logistics businesses

The Console answers are a technical draft based on the current source code.
The app owner remains responsible for confirming operational practices,
retention periods, contracts with service providers, and legal wording.
