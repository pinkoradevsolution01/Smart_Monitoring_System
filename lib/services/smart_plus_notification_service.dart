import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/sale.dart';
import '../models/expense_record.dart';
import 'backend_api_service.dart';
import 'customer_service.dart';
import 'database_service.dart';
import 'financial_reporting_service.dart';
import 'pos_service.dart';
import 'supabase_sync_service.dart';

enum SmartPlusNotificationLevel { info, warning, critical }

enum SmartPlusInsightKind { rule, forecast }

enum SmartPlusDataQuality { checking, weak, limited, strong }

enum SmartPlusRecordTarget { inventory, sales, customers, suppliers }

/// A transparent summary of whether the local business records are suitable
/// for a SmartPlus insight. Forecasts are deliberately blocked when this is
/// weak or still being checked.
class SmartPlusDataTrust {
  const SmartPlusDataTrust({
    this.quality = SmartPlusDataQuality.checking,
    this.lastSyncedAt,
    this.syncConfigured = false,
    this.issues = const [],
    this.completedSales = 0,
  });

  final SmartPlusDataQuality quality;
  final DateTime? lastSyncedAt;
  final bool syncConfigured;
  final List<String> issues;
  final int completedSales;

  bool get allowsForecast {
    if (quality != SmartPlusDataQuality.strong &&
        quality != SmartPlusDataQuality.limited) {
      return false;
    }
    if (!syncConfigured || lastSyncedAt == null) return true;
    return DateTime.now().difference(lastSyncedAt!) <=
        const Duration(hours: 24);
  }

  String get qualityLabel => switch (quality) {
    SmartPlusDataQuality.checking => 'Checking data quality',
    SmartPlusDataQuality.weak => 'Weak data quality',
    SmartPlusDataQuality.limited => 'Limited data quality',
    SmartPlusDataQuality.strong => 'Strong data quality',
  };

  String get confidenceLabel => switch (quality) {
    SmartPlusDataQuality.strong => 'High confidence',
    SmartPlusDataQuality.limited => 'Moderate confidence',
    SmartPlusDataQuality.weak => 'Low confidence',
    SmartPlusDataQuality.checking => 'Confidence pending',
  };

  String get freshnessLabel {
    if (!syncConfigured) return 'Local device data; cloud sync is not active.';
    if (lastSyncedAt == null) return 'Not synced yet.';
    final age = DateTime.now().difference(lastSyncedAt!);
    if (age.inMinutes < 1) return 'Last synced just now.';
    if (age.inMinutes < 60) {
      return 'Last synced ${age.inMinutes} minute(s) ago.';
    }
    if (age.inHours < 24) return 'Last synced ${age.inHours} hour(s) ago.';
    return 'Last synced ${age.inDays} day(s) ago.';
  }
}

/// Read-only owner summary for the current business day. An unavailable
/// expense total is represented by null rather than pretending it is zero.
class SmartPlusDailyBrief {
  const SmartPlusDailyBrief({
    this.sales = 0,
    this.grossProfit = 0,
    this.expenses,
    this.lowStockCount = 0,
    this.topProducts = const [],
    this.unusualDiscountCount = 0,
  });

  final double sales;
  final double grossProfit;
  final double? expenses;
  final int lowStockCount;
  final List<String> topProducts;
  final int unusualDiscountCount;
  double? get netProfit => expenses == null ? null : grossProfit - expenses!;
}

class SmartPlusNotificationPreferences {
  const SmartPlusNotificationPreferences({
    this.inAppEnabled = true,
    this.emailEnabled = true,
    this.lowStockEnabled = true,
    this.salesEnabled = true,
    this.discountEnabled = true,
    this.forecastEnabled = true,
    this.supplierDeliveryEnabled = true,
    this.customerLoyaltyEnabled = true,
    this.minimumSeverity = SmartPlusNotificationLevel.info,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final bool inAppEnabled;
  final bool emailEnabled;
  final bool lowStockEnabled;
  final bool salesEnabled;
  final bool discountEnabled;
  final bool forecastEnabled;
  final bool supplierDeliveryEnabled;
  final bool customerLoyaltyEnabled;
  final SmartPlusNotificationLevel minimumSeverity;

  /// Local-hours 0–23. Null means quiet hours are disabled.
  final int? quietHoursStart;
  final int? quietHoursEnd;

  Map<String, dynamic> toApiMap() => {
    'in_app_enabled': inAppEnabled,
    'email_enabled': emailEnabled,
    'low_stock_enabled': lowStockEnabled,
    'sales_enabled': salesEnabled,
    'discount_enabled': discountEnabled,
    'forecast_enabled': forecastEnabled,
    'supplier_delivery_enabled': supplierDeliveryEnabled,
    'customer_loyalty_enabled': customerLoyaltyEnabled,
    'minimum_severity': minimumSeverity.name,
    'quiet_hours_start': quietHoursStart,
    'quiet_hours_end': quietHoursEnd,
  };

  factory SmartPlusNotificationPreferences.fromMap(Map<String, dynamic> map) =>
      SmartPlusNotificationPreferences(
        inAppEnabled: map['in_app_enabled'] != false,
        emailEnabled: map['email_enabled'] != false,
        lowStockEnabled: map['low_stock_enabled'] != false,
        salesEnabled: map['sales_enabled'] != false,
        discountEnabled: map['discount_enabled'] != false,
        forecastEnabled: map['forecast_enabled'] != false,
        supplierDeliveryEnabled: map['supplier_delivery_enabled'] != false,
        customerLoyaltyEnabled: map['customer_loyalty_enabled'] != false,
        minimumSeverity: SmartPlusNotificationLevel.values.firstWhere(
          (value) => value.name == map['minimum_severity'],
          orElse: () => SmartPlusNotificationLevel.info,
        ),
        quietHoursStart: _validHour(map['quiet_hours_start']),
        quietHoursEnd: _validHour(map['quiet_hours_end']),
      );

  SmartPlusNotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? lowStockEnabled,
    bool? salesEnabled,
    bool? discountEnabled,
    bool? forecastEnabled,
    bool? supplierDeliveryEnabled,
    bool? customerLoyaltyEnabled,
    SmartPlusNotificationLevel? minimumSeverity,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool clearQuietHours = false,
  }) => SmartPlusNotificationPreferences(
    inAppEnabled: inAppEnabled ?? this.inAppEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    lowStockEnabled: lowStockEnabled ?? this.lowStockEnabled,
    salesEnabled: salesEnabled ?? this.salesEnabled,
    discountEnabled: discountEnabled ?? this.discountEnabled,
    forecastEnabled: forecastEnabled ?? this.forecastEnabled,
    supplierDeliveryEnabled:
        supplierDeliveryEnabled ?? this.supplierDeliveryEnabled,
    customerLoyaltyEnabled:
        customerLoyaltyEnabled ?? this.customerLoyaltyEnabled,
    minimumSeverity: minimumSeverity ?? this.minimumSeverity,
    quietHoursStart: clearQuietHours
        ? null
        : quietHoursStart ?? this.quietHoursStart,
    quietHoursEnd: clearQuietHours ? null : quietHoursEnd ?? this.quietHoursEnd,
  );

  static int? _validHour(dynamic value) {
    final hour = value is num ? value.toInt() : int.tryParse('$value');
    return hour != null && hour >= 0 && hour <= 23 ? hour : null;
  }
}

class SmartPlusNotification {
  final String id;
  final String title;
  final String message;
  final SmartPlusNotificationLevel level;
  final SmartPlusInsightKind insightKind;
  final String sourceData;
  final String dataRange;
  final String proposedAction;
  final SmartPlusDataQuality dataQuality;
  final String confidence;
  final String why;
  final SmartPlusRecordTarget? recordTarget;
  final String? draftActionType;
  final Map<String, dynamic>? draftProposal;
  final bool requiresOwnerConfirmation;
  final bool isRead;

  const SmartPlusNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.level,
    this.insightKind = SmartPlusInsightKind.rule,
    this.sourceData = 'Current local business records',
    this.dataRange = 'Current data',
    this.proposedAction = 'Review the related records.',
    this.dataQuality = SmartPlusDataQuality.limited,
    this.confidence = 'Moderate confidence',
    this.why = 'SmartPlus evaluated the stated source data and rule.',
    this.recordTarget,
    this.draftActionType,
    this.draftProposal,
    this.requiresOwnerConfirmation = true,
    this.isRead = false,
  });

  SmartPlusNotification copyWith({
    bool? isRead,
    SmartPlusDataQuality? dataQuality,
    String? confidence,
    String? why,
    SmartPlusRecordTarget? recordTarget,
    String? draftActionType,
    Map<String, dynamic>? draftProposal,
  }) => SmartPlusNotification(
    id: id,
    title: title,
    message: message,
    level: level,
    insightKind: insightKind,
    sourceData: sourceData,
    dataRange: dataRange,
    proposedAction: proposedAction,
    dataQuality: dataQuality ?? this.dataQuality,
    confidence: confidence ?? this.confidence,
    why: why ?? this.why,
    recordTarget: recordTarget ?? this.recordTarget,
    draftActionType: draftActionType ?? this.draftActionType,
    draftProposal: draftProposal ?? this.draftProposal,
    requiresOwnerConfirmation: requiresOwnerConfirmation,
    isRead: isRead ?? this.isRead,
  );
}

/// Produces in-app owner alerts from observed business data. It does not make
/// remote AI calls, send operating-system notifications, or mutate business
/// data. Rules are recalculated whenever POS data changes.
class SmartPlusNotificationService extends ChangeNotifier {
  static const _preferencesKey = 'smartplus_notification_preferences_v1';
  static const _reviewedKey = 'smartplus_reviewed_suggestions_v1';
  static const _feedbackKey = 'smartplus_suggestion_feedback_v1';
  final POSService _pos;
  final Set<String> _readIds = <String>{};
  final Set<String> _reviewedIds = <String>{};
  final Map<String, DateTime> _detectedAtByNotification = <String, DateTime>{};
  final Map<String, String> _feedbackByNotification = <String, String>{};
  final Map<String, SmartPlusNotification> _milestones =
      <String, SmartPlusNotification>{};
  List<SmartPlusNotification> _supplierDeliveryNotifications = const [];
  List<SmartPlusNotification> _customerIntelligenceNotifications = const [];
  List<PurchaseOrder> _purchaseOrders = const [];
  bool _supplierRefreshInFlight = false;
  DateTime? _lastSupplierRefresh;
  SmartPlusDataTrust _dataTrust = const SmartPlusDataTrust();
  SmartPlusDailyBrief _dailyBrief = const SmartPlusDailyBrief();
  List<SmartPlusNotification> _notifications = const [];
  SmartPlusNotificationPreferences _preferences =
      const SmartPlusNotificationPreferences();
  final SupabaseSyncService? _syncService;

  SmartPlusNotificationService(this._pos)
    : _syncService = GetIt.I.isRegistered<SupabaseSyncService>()
          ? GetIt.I<SupabaseSyncService>()
          : null {
    _pos.addListener(_onBusinessDataChanged);
    _syncService?.addListener(_onBusinessDataChanged);
    refresh();
  }

  List<SmartPlusNotification> get notifications =>
      List.unmodifiable(_notifications);

  /// The bell represents work that still needs the owner's attention.
  /// A confirmed review is persisted, while a transient "read" state is not,
  /// so always exclude reviewed suggestions here as well.
  int get unreadCount => _notifications
      .where((item) => !item.isRead && !_reviewedIds.contains(item.id))
      .length;
  SmartPlusNotificationPreferences get preferences => _preferences;
  SmartPlusDataTrust get dataTrust => _dataTrust;
  SmartPlusDailyBrief get dailyBrief => _dailyBrief;
  bool isReviewed(String id) => _reviewedIds.contains(id);
  String? feedbackFor(String notificationId) =>
      _feedbackByNotification[notificationId];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPreferences = prefs.getString(_preferencesKey);
    if (rawPreferences != null) {
      try {
        _preferences = SmartPlusNotificationPreferences.fromMap(
          Map<String, dynamic>.from(jsonDecode(rawPreferences) as Map),
        );
      } catch (_) {
        // Defaults are safe if an older/corrupt local setting cannot be read.
      }
    }
    _reviewedIds.addAll(prefs.getStringList(_reviewedKey) ?? const []);
    final rawFeedback = prefs.getString(_feedbackKey);
    if (rawFeedback != null) {
      try {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(rawFeedback) as Map,
        );
        _feedbackByNotification.addAll(
          decoded.map((key, value) => MapEntry(key, value.toString())),
        );
      } catch (_) {
        // Feedback is optional; ignore an older or malformed local cache.
      }
    }
    refresh();
  }

  /// Saves owner choices locally first, then syncs them to the tenant-scoped
  /// backend. A temporary server failure never re-enables a disabled alert.
  Future<String?> updatePreferences(
    SmartPlusNotificationPreferences next,
  ) async {
    _preferences = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, jsonEncode(next.toApiMap()));
    refresh();
    try {
      await ApiClient().putJson('smartplus/preferences', body: next.toApiMap());
      return null;
    } catch (error) {
      return safeApiError(error);
    }
  }

  Future<String?> refreshPreferencesFromServer() async {
    try {
      final response = await ApiClient().get('smartplus/preferences');
      final raw = response['preferences'];
      if (raw is Map) {
        _preferences = SmartPlusNotificationPreferences.fromMap(
          Map<String, dynamic>.from(raw),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _preferencesKey,
          jsonEncode(_preferences.toApiMap()),
        );
        refresh();
      }
      return null;
    } catch (error) {
      return safeApiError(error);
    }
  }

  void _onBusinessDataChanged() => refresh();

  void refresh({bool forceSupplierCheck = false}) {
    _applyVisibleNotifications();
    unawaited(_refreshSupplierDeliveryNotifications(force: forceSupplierCheck));
  }

  void _applyVisibleNotifications() {
    final visible = _preferences.inAppEnabled
        ? [
            ..._milestones.values,
            ..._evaluate(),
            ..._supplierDeliveryNotifications,
            ..._customerIntelligenceNotifications,
          ]
        : const <SmartPlusNotification>[];
    final now = DateTime.now();
    for (final notification in visible) {
      _detectedAtByNotification.putIfAbsent(notification.id, () => now);
    }
    _detectedAtByNotification.removeWhere(
      (id, _) => !visible.any((notification) => notification.id == id),
    );

    _notifications =
        visible
            .map(
              (item) => item.copyWith(
                // A review is a durable acknowledgement and must remain read
                // after a refresh or application restart.
                isRead:
                    _readIds.contains(item.id) ||
                    _reviewedIds.contains(item.id),
                dataQuality: _dataTrust.quality,
                confidence: _dataTrust.confidenceLabel,
              ),
            )
            .where(_shouldShowNotification)
            .toList(growable: false)
          ..sort(
            (first, second) =>
                (_detectedAtByNotification[second.id] ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      _detectedAtByNotification[first.id] ??
                          DateTime.fromMillisecondsSinceEpoch(0),
                    ),
          );
    notifyListeners();
  }

  Future<void> _refreshSupplierDeliveryNotifications({
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (_supplierRefreshInFlight ||
        (!force &&
            _lastSupplierRefresh != null &&
            now.difference(_lastSupplierRefresh!) <
                const Duration(seconds: 30))) {
      return;
    }
    _supplierRefreshInFlight = true;
    _lastSupplierRefresh = now;
    try {
      final database = DatabaseService();
      final orders = await database.getAllPurchaseOrders();
      _purchaseOrders = List.unmodifiable(orders);
      _dataTrust = _assessDataTrust(orders);
      _dailyBrief = await _buildDailyBrief();
      _supplierDeliveryNotifications = _preferences.supplierDeliveryEnabled
          ? await _evaluateSupplierDeliveryRules()
          : const [];
      _customerIntelligenceNotifications = _preferences.customerLoyaltyEnabled
          ? await _evaluateCustomerIntelligenceRules()
          : const [];
      _applyVisibleNotifications();
    } catch (error) {
      // SmartPlus must never interrupt a normal POS/inventory workflow if a
      // local data source is temporarily unavailable.
      debugPrint('SmartPlus supplier delivery review unavailable: $error');
    } finally {
      _supplierRefreshInFlight = false;
    }
  }

  void notifySetupCompleted() {
    const id = 'business-setup-complete';
    _milestones[id] = const SmartPlusNotification(
      id: id,
      title: 'Business setup complete',
      message:
          'Congratulations! SmartPlus and the User Manual are now available to support your business decisions.',
      level: SmartPlusNotificationLevel.info,
    );
    refresh();
  }

  /// Adds an in-app acknowledgement after an owner completes a guided
  /// SmartPlus follow-up. The business change itself was made by the owner in
  /// its normal module; SmartPlus only records and communicates the outcome.
  void notifyActionCompleted({
    required String actionId,
    required String title,
    required String message,
  }) {
    _milestones['action-completed-$actionId'] = SmartPlusNotification(
      id: 'action-completed-$actionId',
      title: title,
      message: message,
      level: SmartPlusNotificationLevel.info,
      sourceData: 'Owner-completed SmartPlus guided workflow',
      dataRange: 'Current action',
      proposedAction: 'Review the related record if any details need updating.',
      why:
          'The owner completed the required follow-up and SmartPlus recorded the acknowledgement.',
      requiresOwnerConfirmation: false,
    );
    refresh();
  }

  void markAllRead() {
    _readIds.addAll(_notifications.map((item) => item.id));
    refresh();
  }

  void markRead(String id) {
    _readIds.add(id);
    refresh();
  }

  Future<void> confirmOwnerReview(String id) async {
    _reviewedIds.add(id);
    _readIds.add(id);
    // Update the inbox and bell immediately; saving the acknowledgement must
    // not make the owner wait for storage I/O before the count changes.
    refresh();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reviewedKey, _reviewedIds.toList());
  }

  /// Feedback is tenant-scoped and owner-only on the backend. It is used for
  /// periodic accuracy review; it does not train or contact any third party.
  Future<String?> recordFeedback(String notificationId, String verdict) async {
    const allowed = {'useful', 'ignored', 'inaccurate'};
    if (!allowed.contains(verdict)) {
      return 'Choose Useful, Ignore, or Inaccurate.';
    }
    final previous = _feedbackByNotification[notificationId];
    _feedbackByNotification[notificationId] = verdict;
    await _saveFeedback();
    notifyListeners();
    try {
      await ApiClient().postJson(
        'smartplus/feedback',
        body: {'notificationId': notificationId, 'verdict': verdict},
      );
      return null;
    } catch (error) {
      if (previous == null) {
        _feedbackByNotification.remove(notificationId);
      } else {
        _feedbackByNotification[notificationId] = previous;
      }
      await _saveFeedback();
      notifyListeners();
      return safeApiError(error);
    }
  }

  Future<void> _saveFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedbackKey, jsonEncode(_feedbackByNotification));
  }

  bool _shouldShowNotification(SmartPlusNotification notification) {
    int rank(SmartPlusNotificationLevel value) => switch (value) {
      SmartPlusNotificationLevel.info => 0,
      SmartPlusNotificationLevel.warning => 1,
      SmartPlusNotificationLevel.critical => 2,
    };
    if (rank(notification.level) < rank(_preferences.minimumSeverity)) {
      return false;
    }
    // Quiet hours defer non-critical in-app alerts. The source records remain
    // available and the next refresh shows them when quiet hours end.
    if (notification.level != SmartPlusNotificationLevel.critical &&
        _isInQuietHours(DateTime.now())) {
      return false;
    }
    return true;
  }

  bool _isInQuietHours(DateTime now) {
    final start = _preferences.quietHoursStart;
    final end = _preferences.quietHoursEnd;
    if (start == null || end == null || start == end) return false;
    final hour = now.hour;
    return start < end
        ? hour >= start && hour < end
        : hour >= start || hour < end;
  }

  Future<List<SmartPlusNotification>>
  _evaluateCustomerIntelligenceRules() async {
    try {
      final summary = await CustomerService().getIntelligenceSummary();
      final results = <SmartPlusNotification>[];
      if (summary.pointsExpiringSoon.isNotEmpty) {
        results.add(
          SmartPlusNotification(
            id: 'loyalty-points-expiring',
            title: 'Loyalty points expiring soon',
            message:
                '${summary.pointsExpiringSoon.length} customer account(s) have points expiring within 30 days. Open Customer Management to review the consent and loyalty record before any contact.',
            level: SmartPlusNotificationLevel.info,
            sourceData: 'Local loyalty ledger and active customer records',
            dataRange: 'Next 30 days',
            proposedAction: 'Review the affected customer loyalty records.',
            why:
                'Unredeemed earned points have a recorded expiry within 30 days.',
            recordTarget: SmartPlusRecordTarget.customers,
          ),
        );
      }
      if (summary.consentEligibleFollowUps.isNotEmpty) {
        results.add(
          SmartPlusNotification(
            id: 'consented-customer-follow-up',
            title: 'Consented customer follow-up available',
            message:
                '${summary.consentEligibleFollowUps.length} at-risk or inactive customer account(s) have recorded marketing consent. SmartPlus will not send a message automatically.',
            level: SmartPlusNotificationLevel.info,
            sourceData:
                'Local customer segments and recorded marketing consent',
            dataRange: 'Current customer records',
            proposedAction:
                'Review consent and draft an owner-approved follow-up.',
            why:
                'The customer segment is at-risk or inactive and consent is explicitly recorded.',
            recordTarget: SmartPlusRecordTarget.customers,
          ),
        );
      }
      return results;
    } catch (error) {
      debugPrint('SmartPlus customer intelligence review unavailable: $error');
      return const [];
    }
  }

  List<SmartPlusNotification> _evaluate() {
    final products = _pos.products;
    final completedSales = _pos.recentSales
        .where((sale) => sale.status == SaleStatus.completed)
        .toList();
    final suggestions = <SmartPlusNotification>[];

    suggestions.add(_dailyBriefNotification());

    suggestions.add(
      SmartPlusNotification(
        id: 'smartplus-data-freshness',
        title: 'Data freshness',
        message: _dataTrust.freshnessLabel,
        level: _dataTrust.allowsForecast
            ? SmartPlusNotificationLevel.info
            : SmartPlusNotificationLevel.warning,
        sourceData: 'Sync state and local business records',
        dataRange: 'Current device state',
        proposedAction: _dataTrust.allowsForecast
            ? 'Keep syncing regularly so SmartPlus can use current records.'
            : 'Sync and resolve the listed data-quality issues before relying on forecasts.',
        why:
            'SmartPlus checks freshness before presenting data-dependent guidance.',
      ),
    );

    if (!_dataTrust.allowsForecast) {
      final issues = _dataTrust.issues.isEmpty
          ? 'SmartPlus is still checking the available records.'
          : _dataTrust.issues.join(' ');
      suggestions.add(
        SmartPlusNotification(
          id: 'smartplus-forecast-paused',
          title: 'Forecasts are paused until data improves',
          message:
              'Rule: SmartPlus will not generate a forecast while data quality is insufficient. $issues',
          level: SmartPlusNotificationLevel.warning,
          sourceData: 'Sales, inventory, supplier, and sync validation',
          dataRange: 'Current business records',
          proposedAction: 'Resolve the data issues, then refresh SmartPlus.',
          why:
              'Forecasts can mislead decisions when source records are missing, duplicated, conflicting, or stale.',
        ),
      );
    }

    final outOfStock = products
        .where((product) => product.quantity <= 0)
        .toList();
    if (_preferences.lowStockEnabled && outOfStock.isNotEmpty) {
      suggestions.add(
        SmartPlusNotification(
          id: 'out-of-stock',
          title: 'Products are out of stock',
          message:
              '${outOfStock.length} product(s) cannot be sold. Review Inventory and restock before the next sale.',
          level: SmartPlusNotificationLevel.critical,
          sourceData: 'Product stock quantities',
          dataRange: 'Current inventory',
          proposedAction:
              'Review stock and create a restock order if appropriate.',
          why:
              'One or more product quantities are zero or below zero in current inventory.',
          recordTarget: SmartPlusRecordTarget.inventory,
        ),
      );
    }

    final lowStock =
        products
            .where((product) => product.quantity > 0 && product.lowStock)
            .toList()
          ..sort((a, b) => a.quantity.compareTo(b.quantity));
    if (_preferences.lowStockEnabled && lowStock.isNotEmpty) {
      final examples = lowStock.take(2).map((item) => item.name).join(', ');
      suggestions.add(
        SmartPlusNotification(
          id: 'low-stock',
          title: 'Low-stock reorder suggested',
          message:
              '${lowStock.length} product(s) are at their reorder level, including $examples. Open SmartPlus for suggested quantities.',
          level: SmartPlusNotificationLevel.warning,
          sourceData: 'Product quantity and reorder level',
          dataRange: 'Current inventory',
          proposedAction:
              'Review stock and supplier availability before creating an order.',
          why: 'Current quantity is at or below the saved reorder level.',
          recordTarget: SmartPlusRecordTarget.inventory,
        ),
      );
    }

    suggestions.addAll(_smartInventoryRules(products, completedSales));

    final topSellerAtRisk = _topSellerAtRisk(products, completedSales);
    if (_preferences.lowStockEnabled && topSellerAtRisk != null) {
      suggestions.add(
        SmartPlusNotification(
          id: 'top-seller-low-stock-${topSellerAtRisk.id}',
          title: 'Top-selling product needs attention',
          message:
              '${topSellerAtRisk.name} is a recent seller and has only ${topSellerAtRisk.quantity} item(s) left.',
          level: SmartPlusNotificationLevel.warning,
          sourceData: 'Completed sale items and product stock',
          dataRange:
              'Completed sales from the last 30 days plus current inventory',
          proposedAction: 'Review this product before ordering more stock.',
          why:
              'Recent completed sales and current inventory both identify this product as at risk.',
          recordTarget: SmartPlusRecordTarget.inventory,
        ),
      );
    }

    final salesChange = _weeklySalesChange(completedSales);
    if (_preferences.salesEnabled &&
        salesChange != null &&
        salesChange <= -15) {
      suggestions.add(
        SmartPlusNotification(
          id: 'weekly-sales-drop',
          title: 'Weekly sales need review',
          message:
              'Completed sales are down ${salesChange.abs().toStringAsFixed(1)}% compared with the preceding 7 days. SmartPlus can show the exact totals; it cannot infer the cause without foot-traffic or campaign data.',
          level: SmartPlusNotificationLevel.warning,
          sourceData: 'Completed sales totals',
          dataRange: 'Most recent 7 days compared with the preceding 7 days',
          proposedAction:
              'Review sales records and operational context before making a decision.',
          why:
              'The most recent completed-sale total is compared with the preceding seven days.',
          recordTarget: SmartPlusRecordTarget.sales,
        ),
      );
    }

    final discountReviewCount = _largeDiscountCount(completedSales);
    if (_preferences.discountEnabled && discountReviewCount > 0) {
      suggestions.add(
        SmartPlusNotification(
          id: 'discount-review',
          title: 'Large discounts require review',
          message:
              '$discountReviewCount completed sale(s) in the last 30 days used a discount of 20% or more. This is a review rule, not a fraud finding.',
          level: SmartPlusNotificationLevel.info,
          sourceData: 'Completed sale subtotal and discount amount',
          dataRange: 'Last 30 days',
          proposedAction:
              'Review the approved discount reason with the responsible staff member.',
          why:
              'A completed sale meets the configured 20% discount review threshold.',
          recordTarget: SmartPlusRecordTarget.sales,
        ),
      );
    }

    final unusualRefunds = _pos.recentSales
        .where((sale) => sale.status == SaleStatus.returned)
        .length;
    if (unusualRefunds > 0) {
      suggestions.add(
        SmartPlusNotification(
          id: 'refund-review',
          title: 'Refund activity needs review',
          message:
              '$unusualRefunds returned sale(s) are recorded in the current data. This is a review reminder, not an accusation of fraud.',
          level: SmartPlusNotificationLevel.warning,
          sourceData: 'Recorded returned-sale status',
          dataRange: 'Available completed and returned sales',
          proposedAction:
              'Review the receipt, return reason, and approval record.',
          why:
              'Returned transactions require owner visibility because they can affect revenue and inventory.',
          recordTarget: SmartPlusRecordTarget.sales,
        ),
      );
    }

    if (_preferences.forecastEnabled && !_dataTrust.allowsForecast) {
      suggestions.add(
        SmartPlusNotification(
          id: 'forecast-data-readiness',
          title: 'Forecast requires stronger records',
          message:
              'SmartPlus did not generate a forecast. ${_dataTrust.issues.isEmpty ? 'Current validation is still in progress.' : _dataTrust.issues.join(' ')}',
          level: SmartPlusNotificationLevel.info,
          sourceData:
              'Completed sales count, inventory, supplier records, and sync state',
          dataRange: 'Last 90 days',
          proposedAction:
              'Resolve the quality issues and keep recording completed sales before relying on forecasts.',
          why:
              'SmartPlus suppresses forecasts when source data is weak, incomplete, duplicated, conflicting, or stale.',
          recordTarget: SmartPlusRecordTarget.sales,
        ),
      );
    }

    return suggestions;
  }

  SmartPlusNotification _dailyBriefNotification() {
    final expense = _dailyBrief.expenses == null
        ? 'Expenses: unavailable until the secure financial report is available.'
        : 'Expenses: ${_dailyBrief.expenses!.toStringAsFixed(2)}.';
    final top = _dailyBrief.topProducts.isEmpty
        ? 'No completed products sold yet today.'
        : 'Top products: ${_dailyBrief.topProducts.join(', ')}.';
    return SmartPlusNotification(
      id: 'smartplus-daily-brief',
      title: 'Today’s decision brief',
      message:
          'Sales: ${_dailyBrief.sales.toStringAsFixed(2)}. Gross profit: ${_dailyBrief.grossProfit.toStringAsFixed(2)}. $expense Low stock: ${_dailyBrief.lowStockCount}. Unusual discounts: ${_dailyBrief.unusualDiscountCount}. $top',
      level: _dailyBrief.lowStockCount > 0
          ? SmartPlusNotificationLevel.warning
          : SmartPlusNotificationLevel.info,
      sourceData:
          'Today’s completed sales, current inventory, and financial expenses',
      dataRange: 'Today',
      proposedAction:
          'Open What needs attention today for prioritized records.',
      why:
          'SmartPlus summarizes the current business day so the owner can review the most urgent work first.',
      recordTarget: SmartPlusRecordTarget.sales,
    );
  }

  List<SmartPlusNotification> _smartInventoryRules(
    List<Product> products,
    List<Sale> completedSales,
  ) {
    final now = DateTime.now();
    final suggestions = <SmartPlusNotification>[];
    final soldLast30 = <int, int>{};
    final soldLast90 = <int, int>{};
    for (final sale in completedSales) {
      for (final item in sale.items) {
        if (sale.saleDate.isAfter(now.subtract(const Duration(days: 30)))) {
          soldLast30[item.productId] =
              (soldLast30[item.productId] ?? 0) + item.quantity;
        }
        if (sale.saleDate.isAfter(now.subtract(const Duration(days: 90)))) {
          soldLast90[item.productId] =
              (soldLast90[item.productId] ?? 0) + item.quantity;
        }
      }
    }

    final expired = products
        .where(
          (item) =>
              item.expirationDate != null &&
              item.expirationDate!.isBefore(
                DateTime(now.year, now.month, now.day),
              ),
        )
        .toList();
    if (expired.isNotEmpty) {
      suggestions.add(
        SmartPlusNotification(
          id: 'expired-stock',
          title: 'Expired stock needs immediate review',
          message:
              '${expired.length} product(s), including ${expired.take(3).map((item) => item.name).join(', ')}, have passed their recorded expiry date.',
          level: SmartPlusNotificationLevel.critical,
          sourceData: 'Product expiry dates and current inventory',
          dataRange: 'Current inventory',
          proposedAction:
              'Remove these items from sale and record the stock adjustment reason.',
          why: 'The recorded expiry date is before today.',
          recordTarget: SmartPlusRecordTarget.inventory,
        ),
      );
    }
    final nearExpiry = products.where((item) {
      final expiry = item.expirationDate;
      return expiry != null &&
          !expiry.isBefore(now) &&
          expiry.difference(now).inDays <= 30;
    }).toList();
    if (nearExpiry.isNotEmpty) {
      suggestions.add(
        SmartPlusNotification(
          id: 'near-expiry-stock',
          title: 'Near-expiry stock needs review',
          message:
              '${nearExpiry.length} product(s) expire within 30 days, including ${nearExpiry.take(3).map((item) => item.name).join(', ')}.',
          level: SmartPlusNotificationLevel.warning,
          sourceData: 'Product expiry dates and current inventory',
          dataRange: 'Next 30 days',
          proposedAction:
              'Review pricing, promotion, transfer, or removal according to your stock policy.',
          why: 'The recorded expiry date falls within the next 30 days.',
          recordTarget: SmartPlusRecordTarget.inventory,
        ),
      );
    }

    final deadStock = products
        .where(
          (item) =>
              item.id != null &&
              item.quantity > 0 &&
              item.createdAt.isBefore(now.subtract(const Duration(days: 90))) &&
              (soldLast90[item.id] ?? 0) == 0,
        )
        .toList();
    if (deadStock.isNotEmpty) {
      suggestions.add(
        SmartPlusNotification(
          id: 'dead-stock',
          title: 'Potential dead stock detected',
          message:
              '${deadStock.length} stocked product(s) have no completed sale in the last 90 days, including ${deadStock.take(3).map((item) => item.name).join(', ')}.',
          level: SmartPlusNotificationLevel.warning,
          sourceData: 'Product age, current quantity, and completed sale items',
          dataRange: 'Last 90 days',
          proposedAction:
              'Review product demand, display, price, or markdown strategy before ordering more.',
          why:
              'The products remain in stock but have no recorded completed sale for 90 days.',
          recordTarget: SmartPlusRecordTarget.inventory,
        ),
      );
    }

    for (final product
        in products.where((item) => item.id != null && item.lowStock).take(3)) {
      final productId = product.id!;
      final units30 = soldLast30[productId] ?? 0;
      final velocity = units30 / 30;
      final history =
          _purchaseOrders
              .where(
                (order) =>
                    order.items.any((item) => item.productId == productId),
              )
              .toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
      final leadTimes = history
          .where((order) => order.expectedDeliveryDate != null)
          .map(
            (order) =>
                order.expectedDeliveryDate!.difference(order.orderDate).inDays,
          )
          .where((days) => days > 0)
          .toList();
      final leadDays = leadTimes.isEmpty
          ? 7
          : (leadTimes.reduce((a, b) => a + b) / leadTimes.length).round();
      final safetyStock = product.reorderLevel;
      final target = (velocity * (leadDays + 7)).ceil() + safetyStock;
      final recommended = (target - product.quantity).clamp(
        safetyStock,
        999999,
      );
      final lastOrder = history.isEmpty ? null : history.first;
      PurchaseOrderItem? lastItem;
      if (lastOrder != null) {
        for (final item in lastOrder.items) {
          if (item.productId == productId) {
            lastItem = item;
            break;
          }
        }
      }
      final supplierDetail = lastOrder == null
          ? 'No supplier purchase history is recorded.'
          : 'Last supplier: ${lastOrder.supplierName}; last price: ${lastItem?.unitPrice.toStringAsFixed(2) ?? 'not recorded'}; planned lead time: $leadDays day(s).';
      final supplierComparison = <String>[];
      final bySupplier = <int, List<PurchaseOrder>>{};
      for (final order in history) {
        bySupplier.putIfAbsent(order.supplierId, () => []).add(order);
      }
      for (final supplierOrders in bySupplier.values.take(3)) {
        final latest = supplierOrders.first;
        PurchaseOrderItem? latestProductItem;
        for (final item in latest.items) {
          if (item.productId == productId) {
            latestProductItem = item;
            break;
          }
        }
        final overdue = supplierOrders.where((order) {
          final expected = order.expectedDeliveryDate;
          return expected != null &&
              !['received', 'cancelled'].contains(order.status.toLowerCase()) &&
              expected.isBefore(now);
        }).length;
        supplierComparison.add(
          '${latest.supplierName}: ${supplierOrders.length} order(s), last ${latestProductItem?.unitPrice.toStringAsFixed(2) ?? 'price unavailable'}, $overdue overdue',
        );
      }
      final comparisonDetail = supplierComparison.isEmpty
          ? ''
          : ' Supplier comparison: ${supplierComparison.join(' • ')}.';
      suggestions.add(
        SmartPlusNotification(
          id: 'smart-reorder-$productId',
          title: 'Reorder recommendation: ${product.name}',
          message:
              'Rule: current stock ${product.quantity}; sales velocity ${velocity.toStringAsFixed(2)} unit(s)/day; reorder level $safetyStock. Suggested order: $recommended unit(s). $supplierDetail$comparisonDetail',
          level: product.quantity <= 0
              ? SmartPlusNotificationLevel.critical
              : SmartPlusNotificationLevel.warning,
          sourceData:
              'Last 30 days of completed sales, current stock, reorder level, and purchase-order history',
          dataRange: 'Last 30 days plus current supplier history',
          proposedAction:
              'Review the quantity, supplier price, and delivery date before creating a purchase order.',
          why:
              'The suggested quantity covers expected sales during the recorded/default lead time plus safety stock.',
          recordTarget: SmartPlusRecordTarget.suppliers,
          draftActionType: 'reorder',
          draftProposal: {'productId': productId, 'quantity': recommended},
        ),
      );
    }

    final firstSale = completedSales.isEmpty
        ? null
        : completedSales
              .map((sale) => sale.saleDate)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    if (_preferences.forecastEnabled &&
        _dataTrust.allowsForecast &&
        firstSale != null &&
        now.difference(firstSale).inDays >= 365) {
      suggestions.add(
        SmartPlusNotification(
          id: 'seasonal-forecast-ready',
          title: 'Seasonal demand forecast is ready to review',
          message:
              'Forecast: SmartPlus has at least one year of completed-sale history and can provide a seasonal demand signal. This is an estimate, not a guarantee.',
          level: SmartPlusNotificationLevel.info,
          insightKind: SmartPlusInsightKind.forecast,
          sourceData: 'Completed item-level sales',
          dataRange: 'At least 12 months of recorded sales',
          proposedAction:
              'Ask SmartPlus about the next seasonal period, then review the supporting sales records.',
          why:
              'A full year of completed sales is available and current data quality permits a forecast.',
          recordTarget: SmartPlusRecordTarget.sales,
        ),
      );
    }
    return suggestions;
  }

  Product? _topSellerAtRisk(List<Product> products, List<Sale> sales) {
    final cutoff = DateTime.now().subtract(const Duration(days: 31));
    final quantities = <int, int>{};
    for (final sale in sales.where((sale) => sale.saleDate.isAfter(cutoff))) {
      for (final item in sale.items) {
        quantities[item.productId] =
            (quantities[item.productId] ?? 0) + item.quantity;
      }
    }
    final atRisk =
        products
            .where((product) => product.lowStock && product.id != null)
            .toList()
          ..sort(
            (a, b) => (quantities[b.id] ?? 0).compareTo(quantities[a.id] ?? 0),
          );
    if (atRisk.isEmpty || (quantities[atRisk.first.id] ?? 0) == 0) return null;
    return atRisk.first;
  }

  double? _weeklySalesChange(List<Sale> sales) {
    final now = DateTime.now();
    final recentStart = now.subtract(const Duration(days: 7));
    final previousStart = now.subtract(const Duration(days: 14));
    final recent = sales
        .where((sale) => sale.saleDate.isAfter(recentStart))
        .fold<double>(0, (sum, sale) => sum + sale.totalAmount);
    final previous = sales
        .where(
          (sale) =>
              sale.saleDate.isAfter(previousStart) &&
              !sale.saleDate.isAfter(recentStart),
        )
        .fold<double>(0, (sum, sale) => sum + sale.totalAmount);
    if (previous <= 0) return null;
    return ((recent - previous) / previous) * 100;
  }

  int _largeDiscountCount(List<Sale> sales) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return sales.where((sale) {
      return sale.saleDate.isAfter(cutoff) &&
          sale.subtotal > 0 &&
          sale.discountAmount / sale.subtotal >= 0.20;
    }).length;
  }

  Future<SmartPlusDailyBrief> _buildDailyBrief() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completed = _pos.recentSales
        .where(
          (sale) =>
              sale.status == SaleStatus.completed &&
              !sale.saleDate.isBefore(today),
        )
        .toList();
    final productsById = {
      for (final product in _pos.products)
        if (product.id != null) product.id!: product,
    };
    final sales = completed.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final grossProfit = completed.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(
            0,
            (itemTotal, item) =>
                itemTotal +
                ((item.unitPrice -
                        (productsById[item.productId]?.buyingPrice ??
                            item.unitPrice)) *
                    item.quantity),
          ),
    );
    final quantities = <String, int>{};
    for (final sale in completed) {
      for (final item in sale.items) {
        quantities[item.productName] =
            (quantities[item.productName] ?? 0) + item.quantity;
      }
    }
    final topProducts = quantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    double? expenses;
    try {
      final records = await FinancialReportingService().getExpenses(
        from: today,
        to: today,
      );
      expenses = records.fold<double>(
        0,
        (sum, ExpenseRecord item) => sum + item.amount,
      );
    } catch (_) {
      // Some subscriptions do not have expense tracking. Do not turn an
      // unavailable secure report into a misleading zero value.
    }
    return SmartPlusDailyBrief(
      sales: sales,
      grossProfit: grossProfit,
      expenses: expenses,
      lowStockCount: _pos.products
          .where((item) => item.lowStock || item.quantity <= 0)
          .length,
      topProducts: topProducts
          .take(3)
          .map((item) => '${item.key} (${item.value})')
          .toList(growable: false),
      unusualDiscountCount: _largeDiscountCount(completed),
    );
  }

  SmartPlusDataTrust _assessDataTrust(List<PurchaseOrder> orders) {
    final products = _pos.products;
    final completedSales = _pos.recentSales
        .where((sale) => sale.status == SaleStatus.completed)
        .toList();
    final issues = <String>[];
    final saleNumbers = <String>{};
    var duplicateSales = 0;
    for (final sale in completedSales) {
      if (sale.saleNumber.trim().isNotEmpty &&
          !saleNumbers.add(sale.saleNumber)) {
        duplicateSales += 1;
      }
      if (sale.items.isEmpty || sale.totalAmount < 0) {
        issues.add(
          'Some completed sales are missing line items or have an invalid total.',
        );
        break;
      }
    }
    if (duplicateSales > 0) {
      issues.add(
        '$duplicateSales duplicate completed sale number(s) were detected.',
      );
    }
    final barcodes = <String>{};
    final hasInventoryConflict = products.any((product) {
      final barcode = product.barcode.trim().toLowerCase();
      return product.quantity < 0 ||
          (barcode.isNotEmpty && !barcodes.add(barcode));
    });
    if (hasInventoryConflict) {
      issues.add('Inventory has a negative quantity or duplicate barcode.');
    }
    final incompleteOrders = orders.where((order) {
      final open = ![
        'received',
        'cancelled',
      ].contains(order.status.toLowerCase());
      return open &&
          (order.supplierName.trim().isEmpty ||
              order.items.isEmpty ||
              order.expectedDeliveryDate == null);
    }).length;
    if (incompleteOrders > 0) {
      issues.add(
        '$incompleteOrders open supplier order(s) are missing supplier, items, or an expected delivery date.',
      );
    }

    final sync = _syncService;
    final syncConfigured = sync?.isConfigured ?? false;
    final lastSyncedAt = sync?.lastSyncTime;
    if (syncConfigured && lastSyncedAt == null) {
      issues.add('Cloud sync has not completed yet.');
    } else if (syncConfigured &&
        DateTime.now().difference(lastSyncedAt ?? DateTime.now()) >
            const Duration(hours: 24)) {
      issues.add('Cloud data is more than 24 hours old.');
    }

    final recentSales = completedSales
        .where(
          (sale) => sale.saleDate.isAfter(
            DateTime.now().subtract(const Duration(days: 90)),
          ),
        )
        .length;
    if (recentSales < 30) {
      issues.add(
        'Only $recentSales completed sale(s) exist in the last 90 days.',
      );
    }
    final quality = products.isEmpty || recentSales < 30 || issues.length >= 3
        ? SmartPlusDataQuality.weak
        : issues.isNotEmpty || recentSales < 60
        ? SmartPlusDataQuality.limited
        : SmartPlusDataQuality.strong;
    return SmartPlusDataTrust(
      quality: quality,
      lastSyncedAt: lastSyncedAt,
      syncConfigured: syncConfigured,
      issues: List.unmodifiable(issues),
      completedSales: completedSales.length,
    );
  }

  Future<List<SmartPlusNotification>> _evaluateSupplierDeliveryRules() async {
    final database = DatabaseService();
    final orders = await database.getAllPurchaseOrders();
    final restocks = await database.getAllRestockRecords();
    final today = _dateOnly(DateTime.now());
    final productsById = {
      for (final product in _pos.products)
        if (product.id != null) product.id!: product,
    };
    final suggestions = <SmartPlusNotification>[];

    for (final order in orders) {
      final status = order.status.trim().toLowerCase();
      if (status == 'cancelled') continue;
      final expected = order.expectedDeliveryDate == null
          ? null
          : _dateOnly(order.expectedDeliveryDate!);
      final orderedItems = _orderedItems(order);
      final impact = _stockImpact(order, productsById);
      final context = _deliveryContext(order, expected, today, impact);

      if (status == 'pending' &&
          today.difference(_dateOnly(order.orderDate)).inDays >= 2) {
        final waitDays = today.difference(_dateOnly(order.orderDate)).inDays;
        suggestions.add(
          _supplierRule(
            id: 'supplier-awaiting-confirmation-${order.orderNumber}',
            title: 'Supplier order awaiting confirmation',
            message:
                'Rule: Purchase Order ${order.orderNumber} has been pending for $waitDays day(s). Supplier: ${order.supplierName}. Ordered: $orderedItems. $context',
            level: SmartPlusNotificationLevel.warning,
            source: 'Purchase-order status and order date',
            range:
                'Order date ${_formatDate(order.orderDate)} to ${_formatDate(today)}',
            action: 'Contact supplier and record approval or cancellation.',
          ),
        );
      }

      if (status == 'completed') {
        suggestions.add(
          _supplierRule(
            id: 'supplier-in-transit-not-received-${order.orderNumber}',
            title: 'Shipment marked complete but not received',
            message:
                'Rule: Purchase Order ${order.orderNumber} is marked completed but has not been received into inventory. Supplier: ${order.supplierName}. Ordered: $orderedItems. $context',
            level: SmartPlusNotificationLevel.warning,
            source: 'Purchase-order status and delivery receipt records',
            range: expected == null
                ? 'Current purchase-order status'
                : 'Expected ${_formatDate(expected)}; current ${_formatDate(today)}',
            action: 'Check the shipment, then record the delivery quantities.',
          ),
        );
      }

      final partialItems = order.items
          .where(
            (item) =>
                item.receivedQuantity > 0 &&
                item.receivedQuantity < item.quantity,
          )
          .toList();
      if (status == 'partial' || partialItems.isNotEmpty) {
        final received = partialItems.isEmpty
            ? orderedItems
            : partialItems
                  .map(
                    (item) =>
                        '${item.productName} ${item.receivedQuantity}/${item.quantity}',
                  )
                  .join(', ');
        suggestions.add(
          _supplierRule(
            id: 'supplier-partial-delivery-${order.orderNumber}',
            title: 'Partial supplier delivery needs review',
            message:
                'Rule: Purchase Order ${order.orderNumber} has a recorded partial delivery. Supplier: ${order.supplierName}. Ordered: $orderedItems. Received: $received. $context',
            level: SmartPlusNotificationLevel.warning,
            source: 'Recorded purchase-order receipt quantities',
            range: expected == null
                ? 'Current purchase-order receipt'
                : 'Expected ${_formatDate(expected)}; current ${_formatDate(today)}',
            action:
                'Record the remaining delivery or contact the supplier about the shortage.',
          ),
        );
      }

      if (status == 'received' &&
          order.items.any((item) => item.receivedQuantity > 0) &&
          !restocks.any(
            (record) => record.referencedBy.contains(
              'Purchase Order ${order.orderNumber}',
            ),
          )) {
        suggestions.add(
          _supplierRule(
            id: 'supplier-received-stock-unrecorded-${order.orderNumber}',
            title: 'Delivered stock has not been added to inventory',
            message:
                'Rule: Purchase Order ${order.orderNumber} is marked received, but no linked restock record was found. Supplier: ${order.supplierName}. Ordered: $orderedItems. $context',
            level: SmartPlusNotificationLevel.critical,
            source: 'Purchase-order receipt status and restock records',
            range: 'Current records as of ${_formatDate(today)}',
            action:
                'Verify the delivery and record the stock before selling it.',
          ),
        );
      }

      if (status == 'received') continue;

      if (expected == null) continue;
      final overdueDays = today.difference(expected).inDays;
      if (overdueDays == 0) {
        suggestions.add(
          _supplierRule(
            id: 'supplier-delivery-due-${order.orderNumber}',
            title: 'Supplier delivery is due today',
            message:
                'Rule: Purchase Order ${order.orderNumber} is due today. Supplier: ${order.supplierName}. Ordered: $orderedItems. $context',
            level: SmartPlusNotificationLevel.info,
            source: 'Purchase-order expected delivery date',
            range:
                'Expected ${_formatDate(expected)}; current ${_formatDate(today)}',
            action: 'Confirm the delivery schedule with the supplier.',
          ),
        );
      } else if (overdueDays > 0 && _isOverdueReminderDay(overdueDays)) {
        suggestions.add(
          _supplierRule(
            id: 'supplier-delivery-overdue-${order.orderNumber}-$overdueDays',
            title: 'Supplier delivery is overdue',
            message:
                'Rule: Purchase Order ${order.orderNumber} is $overdueDays day(s) overdue. Supplier: ${order.supplierName}. Ordered: $orderedItems. $context',
            level: impact.isEmpty
                ? SmartPlusNotificationLevel.warning
                : SmartPlusNotificationLevel.critical,
            source: 'Purchase-order expected delivery date and current stock',
            range:
                'Expected ${_formatDate(expected)}; current ${_formatDate(today)}',
            action: 'Confirm delivery status with supplier.',
          ),
        );
      }
    }

    suggestions.addAll(_supplierReliabilityRules(orders, today));
    return suggestions;
  }

  SmartPlusNotification _supplierRule({
    required String id,
    required String title,
    required String message,
    required SmartPlusNotificationLevel level,
    required String source,
    required String range,
    required String action,
  }) => SmartPlusNotification(
    id: id,
    title: title,
    message: message,
    level: level,
    insightKind: SmartPlusInsightKind.rule,
    sourceData: source,
    dataRange: range,
    proposedAction: action,
    why:
        'The purchase-order status, expected delivery date, and recorded receipt data meet this delivery review rule.',
    recordTarget: SmartPlusRecordTarget.suppliers,
    requiresOwnerConfirmation: true,
  );

  List<SmartPlusNotification> _supplierReliabilityRules(
    List<PurchaseOrder> orders,
    DateTime today,
  ) {
    final bySupplier = <int, List<PurchaseOrder>>{};
    for (final order in orders) {
      bySupplier.putIfAbsent(order.supplierId, () => []).add(order);
    }
    final results = <SmartPlusNotification>[];
    for (final entries in bySupplier.entries) {
      final supplierOrders = entries.value
        ..sort((a, b) => a.orderDate.compareTo(b.orderDate));
      final supplier = supplierOrders.first.supplierName;
      final delayed = supplierOrders.where((order) {
        final expected = order.expectedDeliveryDate;
        final closed =
            order.status == 'received' || order.status == 'cancelled';
        return !closed &&
            expected != null &&
            _dateOnly(expected).isBefore(today);
      }).length;
      final incomplete = supplierOrders
          .where(
            (order) =>
                order.status == 'partial' ||
                order.items.any(
                  (item) =>
                      item.receivedQuantity > 0 &&
                      item.receivedQuantity < item.quantity,
                ),
          )
          .length;
      final increases = _priceIncreaseCount(supplierOrders);
      if (delayed == 0 && incomplete == 0 && increases == 0) {
        continue;
      }
      final evidence = <String>[];
      if (delayed > 0) evidence.add('$delayed delayed open order(s)');
      if (incomplete > 0) evidence.add('$incomplete partial order(s)');
      if (increases > 0) {
        evidence.add('$increases repeated item price increase(s)');
      }
      results.add(
        _supplierRule(
          id: 'supplier-reliability-${entries.key}',
          title: 'Supplier reliability trend needs review',
          message:
              'Rule: ${supplier.isEmpty ? 'This supplier' : supplier} has ${evidence.join(', ')} in the recorded purchase-order history. This is an operational review trend, not a supplier rating or forecast.',
          level: delayed > 0 || incomplete > 0
              ? SmartPlusNotificationLevel.warning
              : SmartPlusNotificationLevel.info,
          source: 'Purchase-order dates, receipt quantities, and unit prices',
          range:
              '${_formatDate(supplierOrders.first.orderDate)} to ${_formatDate(today)}',
          action:
              'Review supplier performance and confirm future pricing or delivery commitments.',
        ),
      );
    }
    return results;
  }

  int _priceIncreaseCount(List<PurchaseOrder> orders) {
    final lastPriceByProduct = <int, double>{};
    var increases = 0;
    for (final order in orders) {
      for (final item in order.items) {
        final previous = lastPriceByProduct[item.productId];
        if (previous != null && item.unitPrice > previous * 1.05) {
          increases += 1;
        }
        lastPriceByProduct[item.productId] = item.unitPrice;
      }
    }
    return increases;
  }

  String _orderedItems(PurchaseOrder order) {
    final items = order.items
        .take(3)
        .map((item) => '${item.productName} x${item.quantity}')
        .toList();
    if (order.items.length > items.length) {
      items.add('+${order.items.length - items.length} more');
    }
    return items.isEmpty ? 'No line items recorded' : items.join(', ');
  }

  List<Product> _stockImpact(
    PurchaseOrder order,
    Map<int, Product> productsById,
  ) => order.items
      .map((item) => productsById[item.productId])
      .whereType<Product>()
      .where((product) => product.quantity <= 0 || product.lowStock)
      .toList();

  String _deliveryContext(
    PurchaseOrder order,
    DateTime? expected,
    DateTime today,
    List<Product> impact,
  ) {
    final parts = <String>[];
    if (expected != null) {
      final overdue = today.difference(expected).inDays;
      parts.add(
        'Expected delivery: ${_formatDate(expected)}; current date: ${_formatDate(today)}${overdue > 0 ? '; $overdue day(s) overdue' : ''}.',
      );
    } else {
      parts.add('No expected delivery date is recorded.');
    }
    if (impact.isNotEmpty) {
      parts.add(
        'Impact: ${impact.length} affected low-stock or out-of-stock product(s): ${impact.take(3).map((product) => product.name).join(', ')}.',
      );
    }
    return parts.join(' ');
  }

  bool _isOverdueReminderDay(int days) => days == 1 || days % 3 == 0;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime value) =>
      '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1]} ${value.day}, ${value.year}';

  @override
  void dispose() {
    _pos.removeListener(_onBusinessDataChanged);
    _syncService?.removeListener(_onBusinessDataChanged);
    super.dispose();
  }
}
