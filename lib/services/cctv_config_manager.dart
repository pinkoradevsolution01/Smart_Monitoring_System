import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Manages CCTV configuration persistence
/// Stores camera URLs and recordings paths in local storage
class CCTVConfigManager extends ChangeNotifier {
  CCTVConfigManager._();
  static final instance = CCTVConfigManager._();

  // Configuration storage key
  static const String _cameraUrlKey = 'camera_url';
  static const String _recordingsPathKey = 'recordings_path';
  static const String _lastConnectionTimeKey = 'last_connection_time';

  // In-memory cache
  Map<String, dynamic> _config = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Load configuration from storage
  Future<void> loadConfig() async {
    try {
      // This would typically use SharedPreferences on mobile
      // or localStorage on web, or file-based storage on desktop
      // For now, we'll use in-memory storage that persists during app session
      debugPrint('Loading CCTV configuration from storage');
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading CCTV config: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save camera URL
  Future<void> saveCameraUrl(String url) async {
    _config[_cameraUrlKey] = url;
    await _saveToStorage();
  }

  /// Save recordings path
  Future<void> saveRecordingsPath(String path) async {
    _config[_recordingsPathKey] = path;
    await _saveToStorage();
  }

  /// Get saved camera URL
  String? getCameraUrl() => _config[_cameraUrlKey] as String?;

  /// Get saved recordings path
  String? getRecordingsPath() => _config[_recordingsPathKey] as String?;

  /// Record last successful connection
  Future<void> recordConnection() async {
    _config[_lastConnectionTimeKey] = DateTime.now().toIso8601String();
    await _saveToStorage();
  }

  /// Get last connection time
  DateTime? getLastConnectionTime() {
    final timeStr = _config[_lastConnectionTimeKey] as String?;
    return timeStr != null ? DateTime.tryParse(timeStr) : null;
  }

  /// Clear all configuration
  Future<void> clearConfig() async {
    _config.clear();
    await _saveToStorage();
    notifyListeners();
  }

  /// Export configuration as JSON
  String exportConfig() {
    return jsonEncode(_config);
  }

  /// Import configuration from JSON
  Future<void> importConfig(String jsonStr) async {
    try {
      _config = Map<String, dynamic>.from(jsonDecode(jsonStr));
      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('Error importing CCTV config: $e');
      rethrow;
    }
  }

  /// Internal method to save configuration to storage
  Future<void> _saveToStorage() async {
    try {
      // Implementation would depend on platform:
      // - Mobile (Android/iOS): SharedPreferences
      // - Web: localStorage via dart:html
      // - Desktop: File-based storage or native preferences
      debugPrint('Saving CCTV config: $_config');
    } catch (e) {
      debugPrint('Error saving CCTV config: $e');
    }
  }
}
