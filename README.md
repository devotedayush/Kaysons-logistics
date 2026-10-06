# Kaysons Logistics

Flutter app for transporter, logistics manager, and admin workflows.

## Web

Run the browser version locally with:

```bash
flutter run -d chrome
```

Build production web assets with:

```bash
flutter build web
```

## iOS simulator

The iOS project targets iOS 13 or newer. On a Mac, install Flutter, Xcode,
CocoaPods, and an iOS simulator runtime. Review the Xcode license and finish its
initial setup:

```bash
sudo xcodebuild -license
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
```

Copy `.env.example` to `.env` if needed and configure `SUPABASE_URL` and
`SUPABASE_ANON_KEY` with the project's public client credentials. Then run:

```bash
bash scripts/run-ios-simulator.sh
```

The script selects an available iPhone simulator, boots it, opens Device Hub
(Xcode 27) or Simulator, and starts Flutter with hot reload. To choose a specific
device, set `IOS_SIMULATOR_ID` to a UDID from `xcrun simctl list devices available`.
Set `FLUTTER_BIN` if Flutter is not on your PATH. Extra arguments are passed to
`flutter run`.

To compile a simulator app without launching it:

```bash
flutter pub get
flutter build ios --simulator --debug
```

Simulator runs do not require an Apple signing account. Physical iPhone and
App Store builds require your signing team and provisioning configuration in
`ios/Runner.xcworkspace`; the existing bundle ID is
`com.kaysons.kaysonsLogistics`. Build an archive with `flutter build ipa` after
configuring signing. See [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).
