# iOS simulator preparation — 23 September 2026

The repository has an iOS Runner project. Its configuration and dependencies
have been prepared, but an iOS build and simulator launch are **not yet
verified**: Xcode 27.0 on this Mac rejects simulator/build commands until its
license is accepted.

## Changes

- Set the Runner Debug, Profile, and Release minimum target and CocoaPods
  platform to iOS 13, matching the installed Flutter 3.44 engine requirement.
- Removed the obsolete iOS 12 framework metadata override, following Flutter's
  own deployment-target migration.
- Installed and locked the six Flutter plugins and their native dependencies,
  and integrated CocoaPods into the Runner workspace.
- Added a dedicated Profile configuration that includes the correct CocoaPods
  settings; `pod install` now completes without the base-configuration warning.
- Added the photo-library purpose string for cheque and delivery-proof image
  selection, including the plugin's older iOS photo-picker path.
- Refreshed Flutter SDK-pinned packages in `pubspec.lock` using `flutter pub get`.
- Added `scripts/run-ios-simulator.sh` and README instructions. The script checks
  setup, selects an installed iPhone simulator, boots it, and runs Flutter.

## Checks

| Check | Result |
| --- | --- |
| Flutter iOS engine cache | Available |
| Flutter dependency resolution | Passed |
| CocoaPods dependency install/integration | Passed; 10 total pods |
| Plist and Xcode project syntax | Passed |
| Podfile and launcher shell syntax | Passed |
| Flutter test suite | 29 tests passed |
| Flutter analyzer | No issues found |
| Simulator debug build | Blocked before compilation by unaccepted Xcode license |
| Native launch, login, chat, and file picking | Not verified on iOS |
| Physical device/App Store archive/signing | Not verified |
| Native ledger CSV save | File picker path added; mock channel test passed, iOS UI not verified |

## Resume

The Mac owner needs to review and accept Apple's license in Terminal:

```bash
sudo xcodebuild -license
sudo xcodebuild -runFirstLaunch
```

Then check `xcrun simctl list devices available`. If an iOS runtime is missing,
install it with `xcodebuild -downloadPlatform iOS` and create an iPhone simulator
in Xcode. From the repository root, run:

```bash
bash scripts/run-ios-simulator.sh
```

The simulator requires no signing account. The existing physical-device signing
team and bundle identifier have been retained; they must be validated with the
owner's Apple account before a device/archive release. The keychain currently
shows an Apple Development identity, but no Apple Distribution identity; an App
Store archive and upload have not been established.

Ledger CSV export now passes UTF-8 content to the installed native file picker
for saving. This passed a Flutter method-channel test, but still needs a real
iOS save-dialog check after Xcode is usable.

Reference: [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup).
