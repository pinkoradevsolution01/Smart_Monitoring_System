import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Utility to generate a unique device fingerprint for license tracking
class DeviceFingerprint {
  static const String _deviceIdKey = 'device_fingerprint_id';

  /// Get or generate a unique device ID
  /// This ID persists across app restarts and is used to track activations
  static Future<String> getDeviceId() async {
    // Try to get existing ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString(_deviceIdKey);

    if (existingId != null && existingId.isNotEmpty) {
      debugPrint('DeviceFingerprint: Using existing ID: $existingId');
      return existingId;
    }

    // Generate new ID based on device info
    final deviceId = await _generateDeviceId();

    // Save for future use
    await prefs.setString(_deviceIdKey, deviceId);
    debugPrint('DeviceFingerprint: Generated new ID: $deviceId');

    return deviceId;
  }

  /// Generate a unique device ID based on hardware/system info
  static Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String identifier = '';

    try {
      if (kIsWeb) {
        // Web: Use browser fingerprint
        final webInfo = await deviceInfo.webBrowserInfo;
        identifier =
            '${webInfo.browserName}_${webInfo.platform}_${webInfo.userAgent}';
      } else if (Platform.isWindows) {
        // Windows: Use computer name + username
        final windowsInfo = await deviceInfo.windowsInfo;
        identifier =
            '${windowsInfo.computerName}_${windowsInfo.userName}_${windowsInfo.systemMemoryInMegabytes}';
      } else if (Platform.isLinux) {
        // Linux: Use machine ID + hostname
        final linuxInfo = await deviceInfo.linuxInfo;
        identifier = '${linuxInfo.machineId}_${linuxInfo.name}_${linuxInfo.id}';
      } else if (Platform.isMacOS) {
        // macOS: Use system GUID
        final macInfo = await deviceInfo.macOsInfo;
        identifier =
            '${macInfo.systemGUID}_${macInfo.computerName}_${macInfo.model}';
      } else if (Platform.isAndroid) {
        // Android: Use device fingerprint
        final androidInfo = await deviceInfo.androidInfo;
        identifier =
            '${androidInfo.id}_${androidInfo.model}_${androidInfo.device}';
      } else if (Platform.isIOS) {
        // iOS: Use identifier for vendor
        final iosInfo = await deviceInfo.iosInfo;
        identifier =
            '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.systemName}';
      }

      // Hash the identifier to create a consistent ID
      final bytes = utf8.encode(identifier);
      final hash = sha256.convert(bytes);
      return hash.toString().substring(0, 32).toUpperCase();
    } catch (e) {
      debugPrint('DeviceFingerprint: Error generating ID: $e');

      // Fallback: Generate random ID and persist it
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final fallbackId = 'DEVICE_$timestamp';
      return fallbackId;
    }
  }

  /// Get human-readable device info for display
  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return {
          'platform': 'Web',
          'browser': webInfo.browserName.name,
          'userAgent': webInfo.userAgent ?? 'Unknown',
        };
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return {
          'platform': 'Windows',
          'computer': windowsInfo.computerName,
          'version': windowsInfo.displayVersion,
          'username': windowsInfo.userName,
        };
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return {
          'platform': 'Linux',
          'name': linuxInfo.name,
          'version': linuxInfo.versionId ?? 'Unknown',
        };
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return {
          'platform': 'macOS',
          'model': macInfo.model,
          'version': macInfo.osRelease,
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'version': iosInfo.systemVersion,
          'name': iosInfo.name,
        };
      }
    } catch (e) {
      debugPrint('DeviceFingerprint: Error getting device info: $e');
    }

    return {'platform': 'Unknown', 'error': 'Unable to detect device'};
  }

  /// Reset device ID (useful for testing)
  static Future<void> resetDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    debugPrint('DeviceFingerprint: Device ID reset');
  }
}
