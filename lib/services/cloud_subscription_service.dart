import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_record.dart';
import 'supabase_config.dart';

/// Service to fetch and manage subscription records from Supabase cloud database
class CloudSubscriptionService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  /// Fetch all subscription records from Supabase
  Future<void> fetchSubscriptions() async {
    if (!SupabaseConfig.isConfigured) {
      _error =
          'Supabase not configured. Please set up cloud database credentials.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        'CloudSubscriptionService: Fetching subscriptions from Supabase...',
      );

      // Fetch all subscriptions, ordered by most recent first
      final response = await _supabase
          .from('subscriptions')
          .select()
          .order('activated_at', ascending: false);

      _subscriptions = (response as List)
          .map((json) => SubscriptionRecord.fromJson(json))
          .toList();

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

    // Count subscriptions by package
    _packageCounts.clear();
    for (var subscription in _subscriptions) {
      _packageCounts[subscription.packageName] =
          (_packageCounts[subscription.packageName] ?? 0) + 1;
    }
  }

  /// Get count of unique devices (subscribers)
  int get uniqueDeviceCount {
    final uniqueDeviceIds = <String>{};
    for (var subscription in _subscriptions) {
      uniqueDeviceIds.add(subscription.deviceId);
    }
    return uniqueDeviceIds.length;
  }

  /// Get count of active unique devices
  int get activeUniqueDeviceCount {
    final uniqueDeviceIds = <String>{};
    for (var subscription in _subscriptions.where((s) => s.isActive)) {
      uniqueDeviceIds.add(subscription.deviceId);
    }
    return uniqueDeviceIds.length;
  }

  /// Get subscriptions by package name
  List<SubscriptionRecord> getSubscriptionsByPackage(String packageName) {
    return _subscriptions.where((s) => s.packageName == packageName).toList();
  }

  /// Get active subscriptions only
  List<SubscriptionRecord> getActiveSubscriptions() {
    return _subscriptions.where((s) => s.isActive).toList();
  }

  /// Get expired subscriptions only
  List<SubscriptionRecord> getExpiredSubscriptions() {
    return _subscriptions.where((s) => s.isExpired).toList();
  }

  /// Search subscriptions by device name or activation code
  List<SubscriptionRecord> searchSubscriptions(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _subscriptions.where((s) {
      return (s.deviceName?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          s.activationCode.toLowerCase().contains(lowercaseQuery) ||
          s.packageName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Refresh subscriptions (refetch from database)
  Future<void> refresh() async {
    await fetchSubscriptions();
  }

  /// Get subscription by device ID
  SubscriptionRecord? getSubscriptionByDeviceId(String deviceId) {
    try {
      return _subscriptions.firstWhere((s) => s.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  /// Export subscription data as CSV string
  String exportToCsv() {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(
      'ID,Device ID,Device Name,Activation Code,Package,Status,Activated At,Expires At,Days Remaining',
    );

    // CSV Rows
    for (var sub in _subscriptions) {
      buffer.writeln(
        '${sub.id},'
        '"${sub.deviceId}",'
        '"${sub.deviceName ?? 'Unknown'}",'
        '"${sub.activationCode}",'
        '"${sub.packageName}",'
        '"${sub.status}",'
        '"${sub.activatedAt.toLocal()}",'
        '"${sub.expiresAt.toLocal()}",'
        '${sub.remainingDays}',
      );
    }

    return buffer.toString();
  }
}
