# Android release signing — جمعية التعاون الخيرية

Official initial version: `1.0.0+1` (in `pubspec.yaml`).

## Important
Do **not** commit a keystore, passwords, `key.properties`, or base64 key material to this public repository. Generate the release key on a trusted computer and keep an encrypted offline backup. GitHub Actions Secrets are not a substitute for a backup.

## Required GitHub Actions repository secrets
- `ANDROID_KEYSTORE_BASE64`: base64-encoded release keystore file
- `ANDROID_KEYSTORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: alias of the signing key
- `ANDROID_KEY_PASSWORD`: signing key password

Set these at **Settings → Secrets and variables → Actions → New repository secret**. Never paste secret values in an issue, chat, PR, workflow log, or repository file.

## Release plan
1. Confirm final Android `applicationId` and Firebase Android application registration before the first Play upload.
2. Configure Android Gradle release signing to read environment variables or a generated `key.properties` file; do not use Flutter's default debug signing.
3. Build `flutter build appbundle --release --build-name=1.0.0 --build-number=1` for Play and `flutter build apk --release --build-name=1.0.0 --build-number=1` for website distribution.
4. Verify both artifacts have the expected package ID, versionCode, and certificate fingerprint. Test a website APK upgrade before public distribution.
5. Review **Play App Signing** carefully: to support updates across Play and website, the Play-delivered APK and website APK must use the **same app-signing certificate**. The upload key alone is not sufficient when Play signs delivery with a different app-signing key.
6. Store production keystore securely and do not rotate the signing identity without a migration plan.
7. Before release, test login, orphan sponsorship/cart, payments, notifications, privacy disclosures, and Play policies.

**Status:** This file documents the signing requirements only. No production keystore, GitHub secrets, signed release artifacts, or Play submission have been created yet.
