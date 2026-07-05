Place your new logo image file at the repository root named `SMS_LOGO_NBG.png` (PNG recommended, transparent background supported).

Steps:
1. Ensure the file `SMS_LOGO_NBG.png` exists at the project root `C:\\Smart_Monitoring_System\\SMS_LOGO_NBG.png` (it already appears present).
2. Regenerate platform icons with:

```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```

3. Rebuild the app:

```bash
flutter clean
flutter run
```

Notes:
- I updated `pubspec.yaml` and the splash/loading screens to use `SMS_LOGO_NBG.png` at the repo root.
- If you want the asset moved into `assets/` instead, tell me and I will copy it and update paths accordingly.