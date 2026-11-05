import 'dart:typed_data';

import 'backend_api_service.dart';

/// Product photo references are opaque IDs; they do not expose a filesystem
/// path, a business ID, or an authentication token to another device.
class ProductImageService {
  static const String referencePrefix = 'server-image:';
  final ApiClient _api;

  ProductImageService([ApiClient? api]) : _api = api ?? ApiClient();

  static bool isRemoteReference(String? value) {
    return RegExp(
      r'^server-image:[0-9a-f-]{36}$',
      caseSensitive: false,
    ).hasMatch(value?.trim() ?? '');
  }

  static String? imageId(String? value) {
    final match = RegExp(
      r'^server-image:([0-9a-f-]{36})$',
      caseSensitive: false,
    ).firstMatch(value?.trim() ?? '');
    return match?.group(1);
  }

  static String contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<String> upload(Uint8List bytes, {required String contentType}) async {
    if (bytes.isEmpty) {
      throw StateError('Select a product image before uploading.');
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw StateError('Product images must be 5 MB or smaller.');
    }
    final response = await _api.postBytes(
      'product-images',
      bytes,
      contentType: contentType,
    );
    final reference = response['imageRef']?.toString();
    if (!isRemoteReference(reference)) {
      throw StateError(
        'The secure image service returned an invalid image reference.',
      );
    }
    return reference!;
  }

  Future<void> delete(String reference) async {
    final id = imageId(reference);
    if (id == null) return;
    await _api.deleteJson('product-images/$id');
  }
}
