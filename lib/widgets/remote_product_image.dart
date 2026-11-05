import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backend_config.dart';
import '../services/product_image_service.dart';

/// Loads a product photo only through the authenticated API. Images are never
/// public URLs and no session token is placed in an address bar or database.
class RemoteProductImage extends StatefulWidget {
  const RemoteProductImage({
    super.key,
    required this.imageReference,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String imageReference;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? errorBuilder;

  @override
  State<RemoteProductImage> createState() => _RemoteProductImageState();
}

class _RemoteProductImageState extends State<RemoteProductImage> {
  late Future<String?> _token;

  @override
  void initState() {
    super.initState();
    _token = _loadToken();
  }

  @override
  void didUpdateWidget(covariant RemoteProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageReference != widget.imageReference) {
      _token = _loadToken();
    }
  }

  Future<String?> _loadToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('backend_access_token');
  }

  @override
  Widget build(BuildContext context) {
    final imageId = ProductImageService.imageId(widget.imageReference);
    if (imageId == null) return _fallback(context);
    return FutureBuilder<String?>(
      future: _token,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(width: widget.width, height: widget.height);
        }
        final headers = <String, String>{};
        if (snapshot.data?.isNotEmpty == true) {
          headers['Authorization'] = 'Bearer ${snapshot.data}';
        }
        return Image.network(
          '${BackendConfig.apiBaseUrl}/product-images/$imageId',
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          headers: headers,
          errorBuilder: (_, _, _) => _fallback(context),
        );
      },
    );
  }

  Widget _fallback(BuildContext context) =>
      widget.errorBuilder?.call(context) ?? const Icon(Icons.inventory_2);
}
