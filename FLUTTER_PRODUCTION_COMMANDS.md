# Flutter Production Run And Build Commands

Use these commands when testing or building the Smart Monitoring System against the production Droplet backend.

## Production Backend Values

```text
BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api
OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback
GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

## Run Windows App

Use this for local Windows testing:

```bash
flutter run -d windows --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

## Build Windows Release

Use this to create a Windows release build:

```bash
flutter build windows --release --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

Release output:

```text
build/windows/x64/runner/Release
```

## Run Android App

Use this for testing on an Android device or emulator:

```bash
flutter run -d android --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

## Build Android APK

Use this to create a release APK:

```bash
flutter build apk --release --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

Release APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Build Android App Bundle

Use this if publishing to Google Play:

```bash
flutter build appbundle --release --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

Release bundle output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Clean Build If The App Uses Old Settings

Run this if Google OAuth or backend URL still appears stale:

```bash
flutter clean
flutter pub get
```

Then run the Windows or Android command again.

## Verify Backend Before Building

```bash
curl https://api.smartmonitoringsystem.store/api/health
```

Expected result:

```json
{
  "status": "ok",
  "backend": "Smart Monitoring System"
}
```

