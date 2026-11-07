import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';

/// Recovers a product photo if Android destroys the app while an older build
/// or a device-specific camera provider is handling capture outside the app.
///
/// New captures use the in-app camera route, but this is retained as a safe
/// fallback so an already captured image is not silently lost on restart.
class ProductImageRecoveryService {
  ProductImageRecoveryService._();

  static final ImagePicker _picker = ImagePicker();
  static String? _recoveredImagePath;
  static bool _checkedForLostData = false;

  static Future<void> recoverLostProductImage() async {
    if (kIsWeb || _checkedForLostData) return;
    _checkedForLostData = true;

    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return;

      final image = response.file;
      if (image != null) {
        _recoveredImagePath = image.path;
        debugPrint('Recovered a product image after Android camera return.');
      } else if (response.exception != null) {
        debugPrint(
          'Product image recovery failed: ${response.exception!.message}',
        );
      }
    } catch (error) {
      // Recovery must never block the app's normal startup path.
      debugPrint('Unable to check for a recovered product image: $error');
    }
  }

  /// Returns the recovered image once, so a later, unrelated product form
  /// cannot accidentally receive it.
  static String? takeRecoveredProductImage() {
    final path = _recoveredImagePath;
    _recoveredImagePath = null;
    return path;
  }
}
