import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'dart:io' show Platform;

// Constants for LogonUser
const int logon32LogonInteractive = 2;
const int logon32ProviderDefault = 0;

// Define LogonUser function from advapi32.dll
final _advapi32 = DynamicLibrary.open('advapi32.dll');

final logonUser = _advapi32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16> lpszUsername,
        Pointer<Utf16> lpszDomain,
        Pointer<Utf16> lpszPassword,
        Uint32 dwLogonType,
        Uint32 dwLogonProvider,
        Pointer<HANDLE> phToken,
      ),
      int Function(
        Pointer<Utf16> lpszUsername,
        Pointer<Utf16> lpszDomain,
        Pointer<Utf16> lpszPassword,
        int dwLogonType,
        int dwLogonProvider,
        Pointer<HANDLE> phToken,
      )
    >('LogonUserW');

/// Service for authenticating Windows user credentials
class WindowsAuthService {
  /// Verifies Windows credentials using the LogonUser API
  ///
  /// Returns true if the credentials are valid, false otherwise.
  /// Throws an exception if not running on Windows or if API call fails.
  static Future<bool> verifyWindowsCredentials({
    required String username,
    required String password,
    String? domain,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Windows authentication is only supported on Windows',
      );
    }

    return await _verifyCredentialsNative(
      username: username,
      password: password,
      domain: domain,
    );
  }

  /// Internal method that calls the native Windows LogonUser API
  static Future<bool> _verifyCredentialsNative({
    required String username,
    required String password,
    String? domain,
  }) async {
    // Use local machine if no domain specified
    final domainToUse = domain ?? '.';

    // Convert strings to native UTF-16 pointers
    final usernamePtr = username.toNativeUtf16();
    final passwordPtr = password.toNativeUtf16();
    final domainPtr = domainToUse.toNativeUtf16();

    try {
      // Create a pointer to receive the token handle
      final tokenHandle = calloc<HANDLE>();

      try {
        // Call LogonUser API
        // logon32LogonInteractive = 2
        // logon32ProviderDefault = 0
        final result = logonUser(
          usernamePtr,
          domainPtr,
          passwordPtr,
          logon32LogonInteractive,
          logon32ProviderDefault,
          tokenHandle,
        );

        // If logon succeeded, close the handle
        if (result != 0) {
          final handle = tokenHandle.value;
          if (handle != 0) {
            CloseHandle(handle);
          }
          return true;
        }

        // Get the error code for debugging
        final errorCode = GetLastError();

        // ERROR_LOGON_FAILURE = 1326 means invalid credentials
        if (errorCode == ERROR_LOGON_FAILURE) {
          return false;
        }

        // Other errors might indicate system issues
        return false;
      } finally {
        calloc.free(tokenHandle);
      }
    } finally {
      // Free all allocated strings
      calloc.free(usernamePtr);
      calloc.free(passwordPtr);
      calloc.free(domainPtr);
    }
  }

  /// Gets the current Windows username
  static String getCurrentUsername() {
    if (!Platform.isWindows) {
      return Platform.environment['USER'] ??
          Platform.environment['USERNAME'] ??
          'Unknown';
    }

    final length = calloc<DWORD>();
    length.value = 256;
    final buffer = wsalloc(256);

    try {
      final result = GetUserName(buffer, length);
      if (result != 0) {
        return buffer.toDartString();
      }

      // Fallback to environment variable
      return Platform.environment['USERNAME'] ?? 'Unknown';
    } finally {
      calloc.free(length);
      calloc.free(buffer);
    }
  }

  /// Verifies the current user's password (using current logged-in username)
  static Future<bool> verifyCurrentUserPassword(String password) async {
    final username = getCurrentUsername();
    return await verifyWindowsCredentials(
      username: username,
      password: password,
    );
  }
}
