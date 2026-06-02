// Exposes PlatformHttpClient with a uniform API across platforms.
export 'platform_http_io.dart' if (dart.library.html) 'platform_http_web.dart';
