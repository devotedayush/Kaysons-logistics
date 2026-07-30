# Android release runbook

## Release files

The private release credentials are intentionally ignored by Git:

- `android/upload-keystore.jks`
- `android/key.properties`

The public certificate is safe to share and is committed at:

- `docs/play-store/assets/upload-certificate.pem`

Upload certificate fingerprints:

- SHA-1:
  `81:C3:17:BA:46:9A:E6:FB:A3:33:11:00:B3:A4:61:09:A5:7F:4C:85`
- SHA-256:
  `4A:74:E9:C4:B7:5A:CC:27:99:5D:94:AB:02:91:EE:D6:54:71:1F:8F:A0:9D:B5:80:1F:AC:8C:86:48:74:12:DB`
- Certificate expiry: December 15, 2053

## Immediate key-backup action

Completed locally on July 30, 2026:

- private backup directory:
  `~/Documents/Kaysons-Logistics-Release-Backup/`
- `upload-keystore.jks` and `key.properties` copied with owner-only permissions
- source and backup keystore SHA-256 values verified to match

Before uploading the first bundle, also make an off-device backup:

1. Copy `upload-keystore.jks` to an encrypted company vault.
2. Store the alias and passwords from `key.properties` in a password manager.
3. Keep at least one encrypted offline backup controlled by the business.
4. Do not email the keystore, commit it, place it in shared source control or
   store the keystore and its only password copy together.

Google Play App Signing should manage the app-signing key. This local key is
the upload key used to authenticate future bundles.

## Build

From the repository root:

```bash
ANDROID_HOME="$HOME/Library/Android/sdk" \
ANDROID_SDK_ROOT="$HOME/Library/Android/sdk" \
flutter build appbundle \
  --release \
  --target-platform android-arm,android-arm64,android-x64
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

The build deliberately fails if `android/key.properties` is missing, preventing
an accidental debug-signed release.

## Versioning

Before every upload, increase the build number in `pubspec.yaml`:

```yaml
version: 1.0.1+2
```

- `1.0.1` becomes Android `versionName`
- `2` becomes Android `versionCode`
- Every Play upload must use a version code higher than all previous uploads.

## Verification

Verify the signature:

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab
```

Verify bundle structure with Google's Bundletool:

```bash
java -jar bundletool-all.jar validate \
  --bundle=build/app/outputs/bundle/release/app-release.aab
```

Expected release metadata:

- Package: `com.kaysons.kaysons_logistics`
- Version: `1.0.0 (1)`
- Min SDK: 24
- Target SDK: 36
- ABIs: armeabi-v7a, arm64-v8a, x86_64
- App label: Kaysons Logistics
- Signing: upload certificate above, not Android debug certificate

## First Play Console upload

1. Create the app using the exact permanent package ID.
2. Enrol in Play App Signing and allow Google to generate/protect the app
   signing key unless the business has a different cross-store key policy.
3. Upload `app-release.aab` to Internal testing first.
4. Fix all pre-review and device-catalog warnings.
5. Add reviewer access, store listing, privacy URL and Data safety answers.
6. Run internal testing, then closed testing.
7. If the developer account is a personal account created after November 13,
   2023, maintain at least 12 opted-in closed testers continuously for 14 days
   before applying for production access.
8. Promote only after crash, authentication, upload and role tests pass.

## Package ID warning

Google Play permanently associates the application with
`com.kaysons.kaysons_logistics` after first upload. Confirm ownership and naming
before uploading. Changing it later creates a different app.

**Decision recorded July 30, 2026:** use
`com.kaysons.kaysons_logistics` as the permanent Google Play package ID.

## Toolchain maintenance

The current bundle is valid, but Flutter warns that future releases will need
newer Gradle, Android Gradle Plugin and Kotlin versions. Plan that upgrade before
the next Flutter major update rather than during an urgent production release.
