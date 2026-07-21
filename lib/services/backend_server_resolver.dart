import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_config.dart';

/// Probes configured backend URLs on startup and selects the first healthy one.
class BackendServerResolver {
  static const Duration _probeTimeout = Duration(seconds: 2);
  static final http.Client _client = http.Client();

  static bool _initialized = false;

  static String? get activeBaseUrl => BackendConfig.resolvedApiBaseUrl;

  /// Probe all configured backend base URLs and select the first one that
  /// responds to `/api/health`.
  static Future<String> initialize({List<String>? candidates}) async {
    if (_initialized && BackendConfig.resolvedApiBaseUrl != null) {
      return BackendConfig.resolvedApiBaseUrl!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString(BackendConfig.backendApiBaseUrlPrefsKey);
    final savedBaseUrls = prefs.getString(
      BackendConfig.backendApiBaseUrlsPrefsKey,
    );

    final candidateUrls = normalizeCandidates(
      [
        ..._splitCandidates(savedBaseUrl ?? ''),
        ..._splitCandidates(savedBaseUrls ?? ''),
        ...(candidates ?? BackendConfig.configuredApiBaseUrls),
      ],
    );
    if (candidateUrls.isEmpty) {
      throw StateError('No backend URLs were configured for auto-detection.');
    }

    debugPrint(
      'BackendServerResolver: probing ${candidateUrls.length} candidate(s)...',
    );

    final healthyUrl = await _probeCandidates(candidateUrls);
    final selectedUrl = healthyUrl ?? candidateUrls.first;
    BackendConfig.setResolvedApiBaseUrl(selectedUrl);
    if (healthyUrl != null) {
      await _saveSelectedUrl(prefs, selectedUrl);
    }
    _initialized = true;

    if (healthyUrl != null) {
      debugPrint('BackendServerResolver: selected $selectedUrl');
    } else {
      debugPrint(
        'BackendServerResolver: no healthy backend responded, falling back to $selectedUrl',
      );
    }

    return selectedUrl;
  }

  static List<String> normalizeCandidates(List<String> candidates) {
    return candidates
        .map((candidate) => candidate.trim().replaceAll(RegExp(r'/+$'), ''))
        .where((candidate) => candidate.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _splitCandidates(String rawCandidates) {
    return rawCandidates
        .split(RegExp(r'[,\n; ]+'))
        .map((candidate) => candidate.trim())
        .where((candidate) => candidate.isNotEmpty)
        .toList(growable: false);
  }

  static Future<String?> _probeCandidates(List<String> candidates) async {
    final results = await Future.wait(candidates.map(_probe));
    for (var i = 0; i < results.length; i++) {
      if (results[i]) {
        return candidates[i];
      }
    }
    return null;
  }

  static Future<bool> _probe(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await _client.get(uri).timeout(_probeTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('BackendServerResolver: probe failed for $baseUrl: $e');
      return false;
    }
  }

  static Future<bool> testBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      return Future.value(false);
    }
    return _probe(normalized);
  }

  static Future<bool> testBaseUrls(List<String> baseUrls) async {
    final normalized = normalizeCandidates(baseUrls);
    if (normalized.isEmpty) {
      return false;
    }

    for (final baseUrl in normalized) {
      if (await testBaseUrl(baseUrl)) {
        return true;
      }
    }
    return false;
  }

  static Future<void> savePreferredBaseUrl(String baseUrl) async {
    await savePreferredBaseUrls([baseUrl]);
  }

  static Future<void> savePreferredBaseUrls(List<String> baseUrls) async {
    final normalized = normalizeCandidates(baseUrls);
    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await prefs.remove(BackendConfig.backendApiBaseUrlPrefsKey);
      await prefs.remove(BackendConfig.backendApiBaseUrlsPrefsKey);
      BackendConfig.setResolvedApiBaseUrl('');
      _initialized = false;
      return;
    }

    if (normalized.length == 1) {
      await prefs.setString(BackendConfig.backendApiBaseUrlPrefsKey, normalized.first);
      await prefs.remove(BackendConfig.backendApiBaseUrlsPrefsKey);
      BackendConfig.setResolvedApiBaseUrl(normalized.first);
    } else {
      await prefs.setString(
        BackendConfig.backendApiBaseUrlsPrefsKey,
        normalized.join(','),
      );
      await prefs.remove(BackendConfig.backendApiBaseUrlPrefsKey);
      BackendConfig.setResolvedApiBaseUrl(normalized.first);
    }
    _initialized = true;
  }

  static Future<void> _saveSelectedUrl(
    SharedPreferences prefs,
    String selectedUrl,
  ) async {
    await prefs.setString(BackendConfig.backendApiBaseUrlPrefsKey, selectedUrl);
    await prefs.remove(BackendConfig.backendApiBaseUrlsPrefsKey);
  }

  static void resetForTests() {
    _initialized = false;
    BackendConfig.setResolvedApiBaseUrl('');
  }
}
