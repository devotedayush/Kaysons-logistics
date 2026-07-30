# Google Play submission pack

This directory contains the working material for publishing Kaysons Logistics
to Google Play.

## Ready artifacts

- Signed Android App Bundle:
  `build/app/outputs/bundle/release/app-release.aab`
- Current AAB SHA-256:
  `442d59f3e3e13ead3e99fe02cc15c6932f22fdaa1f5af8372379ec3853936d4f`
- Play icon: `assets/app-icon-512.png`
- Feature graphic: `assets/feature-graphic-1024x500.png`
- Official supplied logo: `assets/kaysons-official-logo.png`
- Public upload certificate: `assets/upload-certificate.pem`
- Store copy: `STORE_LISTING.md`
- Play Console declarations: `PLAY_CONSOLE_ANSWERS.md`
- Privacy-policy publication record: `PRIVACY_POLICY.md`
- Release procedure: `RELEASE_RUNBOOK.md`
- Testing and graphics checklist: `TESTING_AND_ASSETS.md`

## Completed release-readiness work

- Android upload key copied to the private release backup at
  `~/Documents/Kaysons-Logistics-Release-Backup/`
- Package ID confirmed as `com.kaysons.kaysons_logistics`
- Legal operator, address, support email, phone and official website filled
- In-app account-deletion request implemented
- Public privacy policy and no-login deletion request pages created
- Five permanent, approved, role-specific Play reviewer accounts created and
  login-verified
- Reviewer passwords stored in the private release backup, not Git

## Remaining publication checks

Do not submit to production until these are completed:

1. Have qualified counsel approve the privacy and retention wording.
2. Confirm `ksopltd@hotmail.com` is actively monitored for deletion and Play
   review correspondence.
3. Add reviewer passwords from the private credential file to Play Console.
4. Upload screenshots listed in `TESTING_AND_ASSETS.md`.
5. Determine whether the Play developer account is a new personal account. If
   so, complete the 12-tester/14-continuous-day closed test before applying for
   production access.
6. Copy the private signing backup into an encrypted company vault or password
   manager-controlled storage; the local private backup is not a substitute for
   an off-device disaster-recovery copy.

## Current release identity

- App name: Kaysons Logistics
- Package ID: `com.kaysons.kaysons_logistics`
- Package ID decision: Confirmed for first Google Play upload
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
