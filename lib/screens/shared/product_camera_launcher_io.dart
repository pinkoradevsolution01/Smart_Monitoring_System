import 'package:flutter/material.dart';

import 'product_camera_screen.dart';

/// Opens the in-app camera instead of handing the workflow to Android's
/// external camera application. Keeping capture in this Flutter route avoids
/// Android reclaiming the inventory form while a product photo is taken.
Future<String?> captureProductImage(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const ProductCameraScreen()),
  );
}
