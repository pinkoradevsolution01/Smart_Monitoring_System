import 'package:flutter/foundation.dart';
import '../models/subscription_record.dart';
import 'backend_api_service.dart';
import 'backend_config.dart';

/// Service to fetch and manage subscription records from the MySQL backend
class CloudSubscriptionService extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<SubscriptionRecord> _subscriptions = [];
  bool _isLoading = false;
  String? _error;

  // Statistics
  int _totalSubscriptions = 0;
  int _activeSubscriptions = 0;
  int _expiredSubscriptions = 0;
  final Map<String, int> _packageCounts = {};

  List<SubscriptionRecord> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalSubscriptions => _totalSubscriptions;
  int get activeSubscriptions => _activeSubscriptions;
  int get expiredSubscriptions => _expiredSubscriptions;
  Map<String, int> get packageCounts => _packageCounts;

  /// Fetch all subscription records from backend
  Future<void> fetchSubscriptions() async {
    if (!BackendConfig.useRestBackend) {
      _error =
          'Backend not configured. Please set up MySQL backend credentials.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('CloudSubscriptionService: Fetching subscriptions from backend...');

      final response = await _api.getJson('license/subscriptions');
      final rows = response is Map<String, dynamic> && response['subscriptions'] is List
          ? List<Map<String, dynamic>>.from(response['subscriptions'] as List)
          : const <Map<String, dynamic>>[];

      _subscriptions = rows.map((json) => SubscriptionRecord.fromJson(json)).toList();
      _calculateStatistics();

      debugPrint(
        'CloudSubscriptionService: Fetched ${_subscriptions.length} subscriptions',
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('CloudSubscriptionService: Error fetching subscriptions: $e');
      _error = 'Failed to fetch subscriptions: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate statistics from subscription data
  void _calculateStatistics() {
    _totalSubscriptions = _subscriptions.length;
    _activeSubscriptions = _subscriptions.where((s) => s.isActive).length;
    _expiredSubscriptions = _subscriptions.where((s) => s.isExpired).length;

    _packageCounts.clear();
    for (var subscription in _subscriptions) {
      _packageCounts[subscription.packageName] =
          (_packageCounts[subscription.packageName] ?? 0) + 1;
    }
  }

  int get uniqueDeviceCount {
    final uniqueDeviceIds = <String>{};
    for (var subscription in _subscriptions) {
      uniqueDeviceIds.add(subscription.deviceId);
    }
    return uniqueDeviceIds.length;
  }

  int get activeUniqueDeviceCount {
    final uniqueDeviceIds = <String>{};
    for (var subscription in _subscriptions.where((s) => s.isActive)) {
      uniqueDeviceIds.add(subscription.deviceId);
    }
    return uniqueDeviceIds.length;
  }

  List<SubscriptionRecord> getSubscriptionsByPackage(String packageName) {
    return _subscriptions.where((s) => s.packageName == packageName).toList();
  }

  List<SubscriptionRecord> getActiveSubscriptions() {
    return _subscriptions.where((s) => s.isActive).toList();
  }

  List<SubscriptionRecord> getExpiredSubscriptions() {
    return _subscriptions.where((s) => s.isExpired).toList();
  }

  List<SubscriptionRecord> searchSubscriptions(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _subscriptions.where((s) {
      return (s.deviceName?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          s.activationCode.toLowerCase().contains(lowercaseQuery) ||
          s.packageName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Future<void> refresh() async {
    await fetchSubscriptions();
  }

  SubscriptionRecord? getSubscriptionByDeviceId(String deviceId) {
    try {
      return _subscriptions.firstWhere((s) => s.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  String exportToCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'ID,Device ID,Device Name,Activation Code,Package,Status,Activated At,Expires At,Days Remaining',
    );

    for (var sub in _subscriptions) {
      buffer.writeln(
        '${sub.id},'
        '"${sub.deviceId}",'
        '"${sub.deviceName ?? 'Unknown'}",'
        '"${sub.activationCode}",'
        '"${sub.packageName}",'
        '"${sub.status}",'
        '"${sub.activatedAt.toLocal()}",'
        '"${sub.expiresAt?.toLocal() ?? 'Perpetual'}",'
        '${sub.remainingDays}',
      );
    }

    return buffer.toString();
  }
}
