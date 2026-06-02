// Conditionally export a platform-specific DatabaseService implementation.
// On web, `database_service_web.dart` is used; on IO platforms, `database_service_io.dart`.
export 'database_service_io.dart'
    if (dart.library.html) 'database_service_web.dart';
