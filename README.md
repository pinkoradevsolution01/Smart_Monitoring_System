# smart_monitoring_system

A new Flutter project.

## System Documentation

For a full system overview, feature map, backend summary, and module list, see [SYSTEM_DOCUMENTATION.md](SYSTEM_DOCUMENTATION.md).

For the project introduction, development history, implemented features, fixes, and six-month development experience, see [PROJECT_INTRODUCTION_AND_DEVELOPMENT_JOURNEY.md](PROJECT_INTRODUCTION_AND_DEVELOPMENT_JOURNEY.md).

For a portfolio-ready overview of the system, technology stack, achievements, and lessons learned, see [PROJECT_DOCUMENTATION_AND_LEARNING_REFLECTION.md](PROJECT_DOCUMENTATION_AND_LEARNING_REFLECTION.md).

## Backend Launcher

To start the Node.js backend from the repo root:

```bat
start_backend.bat
```

That script starts local XAMPP MySQL if needed, then changes into `backend/` and runs `npm start` with the current `.env`.

If you are using Bash:

```bash
bash start_backend.sh
```

## Auto-start On Windows

If you want the backend to start automatically every time you sign in to Windows, run this once from the repo root:

```bat
install_backend_autostart.bat
```

To disable it later:

```bat
remove_backend_autostart.bat
```

This creates a shortcut in your Windows Startup folder, so the backend launches without opening VS Code first.
If your backend depends on MySQL, make sure the database server is already running before the backend starts.

## Android Build Notes

If Android builds fail with a Java home error like:

```text
Value '.../Android Studio/jbr' given for org.gradle.java.home Gradle property is invalid
```

check `android/gradle.properties` and make sure `org.gradle.java.home` is not hardcoded to a machine-specific path. This repo leaves that setting unset so Gradle can use the JDK configured on each PC or laptop.

## Boot-Time Startup

If you want the backend to start at Windows boot before you sign in, run this once from the repo root:

```bat
install_backend_startup_task.bat
```

You will need to approve the Windows UAC prompt because creating a boot-time task as `SYSTEM` requires Administrator privileges.

To remove the boot-time task:

```bat
remove_backend_startup_task.bat
```

This registers a scheduled task named `Smart Monitoring System Backend` that runs `start_backend.bat --no-pause` as `SYSTEM` at startup.
That is the closest built-in Windows option to a service without installing a third-party wrapper like NSSM.
If MySQL is part of your backend setup, confirm the database service is available at boot too.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Windows Camera & Image Selection

This project supports product images via camera capture on mobile (Android/iOS) and gallery/file selection across all platforms. On Windows desktop:

- There is no separate camera permission manifest to modify (unlike Android `AndroidManifest.xml` and iOS `Info.plist`).
- Direct camera capture is not enabled; the app falls back to selecting existing images using `file_picker`.
- The `image_picker` plugin requires a camera delegate for Windows which is not configured here; attempting `ImageSource.camera` will throw a StateError.

### Current Behavior
- Inventory product bottom sheet offers both Capture (mobile) and Gallery selection; on Windows, Capture routes to the same picker screen but effectively relies on file selection.
- Selected image paths are stored in the `Product.imagePath` and displayed as thumbnails.

### Enabling Experimental Windows Camera
If you wish to experiment with native camera capture on Windows:
1. Add the `camera` plugin to `pubspec.yaml`.
2. Implement a platform check and a Windows-specific preview widget (plugin APIs may be unstable).
3. Provide a fallback to file selection when initialization fails.

### Troubleshooting
- If image thumbnails do not appear, verify the stored file path still exists (files moved or deleted externally will break display).
- For permission-related errors on mobile, confirm camera and photo library usage descriptions are present (already added for Android/iOS).

### Future Improvements
- Optional: Maintain a lightweight copy of selected images inside the app data directory to avoid broken external paths.
- Optional: Add validation for maximum image dimensions and file size before saving.

