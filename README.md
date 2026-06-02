# smart_monitoring_system

A new Flutter project.

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

