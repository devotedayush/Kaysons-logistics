# App update reminders

Available from Kaysons Logistics 1.0.5 (4007).

## Android

The app checks Google Play on launch and when resumed. Startup checks are
non-blocking. The Dart scheduler limits automatic checks to once every six hours;
the native bridge also refreshes an ongoing download when the activity resumes.
Google Play decides which version is available to the signed-in tester's track.

When a newer build is available, a dismissible **Update now / Later** dialog
appears. **Later** defers that build for 24 hours. A newly available build can
prompt sooner. A prompt is shown at most once per build and state in a session.

**Update now** starts Play's flexible update consent flow. The user may keep
working during the download. A second optional dialog offers **Restart and
install** once the download is complete. The app never starts an immediate,
mandatory update flow or restarts without the user's choice. If Play does not
permit a flexible flow, the action opens the app's Play Store listing instead.

Under **More → App updates**, users can disable reminders, manually check for
updates, or open Google Play. Reminder and deferral preferences are local to the
device. A failed/offline check never blocks the workspace. Updates require an
eligible Google Play installation and a higher version code available to that
account. A sideloaded APK may need to be updated through its original source.

Existing installations older than 4007 need to install 4007 once through Google
Play before future in-app prompts can work.

## iOS TestFlight

Under **More → App updates**, the iPhone app explains how to turn on **TestFlight
→ Kaysons Logistics → App Information → Automatic Updates**, with a link to
Apple's official instructions. TestFlight controls update notifications and
installation. Kaysons does not present a switch that pretends to change
TestFlight's device setting and does not query private App Store Connect APIs.
This release is distributed through the existing internal TestFlight group.

## Validation

- Controller tests cover eligible releases, persistent Later deferral, new-build
  deferral bypass, reminder preferences, throttling, store failures, cancellation,
  and downloaded events while the app stays in the foreground.
- Widget tests cover the optional prompt actions and phone layouts in English
  and Hindi, at normal and 2× text sizes.
- Native Android Kotlin compilation and signed Android/iOS release builds are
  required before upload. A full Google Play install/update check requires a
  Play-owned device running a lower build that already includes this feature.

References: [Google Play in-app updates](https://developer.android.com/guide/playcore/in-app-updates/kotlin-java),
[testing requirements](https://developer.android.com/guide/playcore/in-app-updates/test),
[TestFlight automatic updates](https://testflight.apple.com/).
