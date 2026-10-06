# Hindi support status — 23 September 2026

## Implemented locally

- One English/Hindi language choice is available before sign-in and in each role's account/More menu. The choice is saved on the device, applies without signing out, and survives a web reload.
- Flutter Material/Cupertino controls and app text use generated English/Hindi catalogues. A bundled, open-licensed Noto Sans Devanagari UI font makes Hindi visible offline.
- Welcome, login, registration, account/privacy, shared navigation, transporter workflows, logistics-manager workflows, and the main admin/accountant screens have Hindi labels. The selected locale is passed to Clawd chat and saved-prompt requests in the local Edge Function code.
- Hindi was visually checked in a narrow web viewport for Welcome and Login, including the language menu and persistence after reload. On an Android 15 emulator, the login language menu and Hindi login screen rendered correctly. `flutter analyze --no-pub`, all 29 Flutter tests, and a release web build passed. Tests also cover Hindi transporter navigation at 360 px and Hindi ledger summary controls at 390 px.

## Release gaps

- Hindi coverage is still **partial**. Some operational detail text, validation/error messages, server-provided alerts, and generated/historic AI report bodies remain English. CSV schemas, identifiers, user-entered text, units, and business data deliberately retain their original values.
- Operational and legal wording needs review by Hindi-speaking users before a Hindi release. Bilingual authenticated journeys and financial regressions on Android and iOS remain to be completed.
- The local Clawd locale-routing change has not been deployed. The currently deployed v18 function answered tested Hindi questions in Hindi, but it does not yet use the app's selected language for every request.
- iOS simulator and archive checks remain blocked by this Mac's unaccepted Xcode license. See `docs/ios-simulator-status.md`.

Do not market this build as a fully translated Hindi app or iOS-ready release yet.
