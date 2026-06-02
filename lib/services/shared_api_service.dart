import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/shared_data.dart';
import '../utils/platform_http_client.dart';

/// Service that fetches a single shared data object from a remote API
/// and exposes it via `sharedData`. It caches the last value in
/// SharedPreferences so all platforms can read the same persisted data.
class SharedApiService extends ChangeNotifier {
  static final SharedApiService _instance = SharedApiService._internal();
  factory SharedApiService() => _instance;
  SharedApiService._internal();

  SharedData? _sharedData;
  String? _endpointUrl;

  SharedData? get sharedData => _sharedData;
  String? get endpointUrl => _endpointUrl;

  static const _prefsKey = 'shared_api_cached_data';
  static const _prefsUrlKey = 'shared_api_endpoint_url';
  static const _prefsAutoRefreshEnabled = 'shared_api_auto_refresh_enabled';
  static const _prefsAutoRefreshInterval =
      'shared_api_auto_refresh_interval_seconds';

  final PlatformHttpClient _http = PlatformHttpClient();
  Timer? _refreshTimer;
  bool _autoRefreshEnabled = false;
  int _autoRefreshIntervalSeconds = 300; // default 5 minutes

  bool get autoRefreshEnabled => _autoRefreshEnabled;
  int get autoRefreshIntervalSeconds => _autoRefreshIntervalSeconds;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    _endpointUrl = prefs.getString(_prefsUrlKey);
    _autoRefreshEnabled = prefs.getBool(_prefsAutoRefreshEnabled) ?? false;
    _autoRefreshIntervalSeconds =
        prefs.getInt(_prefsAutoRefreshInterval) ?? _autoRefreshIntervalSeconds;

    if (cached != null) {
      try {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        _sharedData = SharedData.fromJson(json);
      } catch (e) {
        debugPrint('SharedApiService: failed to decode cached data: $e');
      }
    }

    // Start auto-refresh if enabled
    if (_autoRefreshEnabled) {
      _startTimer();
    }
  }

  /// Configure the remote endpoint URL and persist it.
  Future<void> configureEndpoint(String url) async {
    _endpointUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUrlKey, url);
    notifyListeners();
  }

  /// Enable/disable automatic periodic refresh. Interval is in seconds.
  Future<void> setAutoRefresh(bool enabled, {int? intervalSeconds}) async {
    _autoRefreshEnabled = enabled;
    if (intervalSeconds != null) {
      _autoRefreshIntervalSeconds = intervalSeconds;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsAutoRefreshEnabled, _autoRefreshEnabled);
    await prefs.setInt(_prefsAutoRefreshInterval, _autoRefreshIntervalSeconds);

    if (_autoRefreshEnabled) {
      _startTimer();
    } else {
      _stopTimer();
    }

    notifyListeners();
  }

  void _startTimer() {
    _stopTimer();
    _refreshTimer = Timer.periodic(
      Duration(seconds: _autoRefreshIntervalSeconds),
      (_) async => await fetchSharedData(force: true),
    );
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Fetch the shared data from the remote API. If `force` is false
  /// the service will return cached data when available and only
  /// attempt a network call when there is no cached value.
  Future<bool> fetchSharedData({bool force = false}) async {
    if (_endpointUrl == null) {
      debugPrint('SharedApiService: endpoint not configured');
      return false;
    }

    if (!force && _sharedData != null) {
      return true;
    }

    try {
      final uri = Uri.parse(_endpointUrl!);
      final resp = await _http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body);
        _sharedData = SharedData.fromJson(body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(_sharedData!.toJson()));
        notifyListeners();
        return true;
      } else {
        debugPrint('SharedApiService: server returned ${resp.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('SharedApiService: fetch error: $e');
      return false;
    }
  }

  /// Clear cached shared data (local only)
  Future<void> clearCache() async {
    _sharedData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }

  void disposeClient() {
    _http.close();
  }
}
