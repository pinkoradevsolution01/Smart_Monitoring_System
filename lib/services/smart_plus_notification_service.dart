import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/sale.dart';
import 'backend_api_service.dart';
import 'pos_service.dart';

enum SmartPlusNotificationLevel { info, warning, critical }

enum SmartPlusInsightKind { rule, forecast }

class SmartPlusNotificationPreferences {
  const SmartPlusNotificationPreferences({
    this.inAppEnabled = true,
    this.emailEnabled = true,
    this.lowStockEnabled = true,
    this.salesEnabled = true,
    this.discountEnabled = true,
    this.forecastEnabled = true,
  });

  final bool inAppEnabled;
  final bool emailEnabled;
  final bool lowStockEnabled;
  final bool salesEnabled;
  final bool discountEnabled;
  final bool forecastEnabled;

  Map<String, dynamic> toApiMap() => {
    'in_app_enabled': inAppEnabled,
    'email_enabled': emailEnabled,
    'low_stock_enabled': lowStockEnabled,
    'sales_enabled': salesEnabled,
    'discount_enabled': discountEnabled,
    'forecast_enabled': forecastEnabled,
  };

  factory SmartPlusNotificationPreferences.fromMap(Map<String, dynamic> map) =>
      SmartPlusNotificationPreferences(
        inAppEnabled: map['in_app_enabled'] != false,
        emailEnabled: map['email_enabled'] != false,
        lowStockEnabled: map['low_stock_enabled'] != false,
        salesEnabled: map['sales_enabled'] != false,
        discountEnabled: map['discount_enabled'] != false,
        forecastEnabled: map['forecast_enabled'] != false,
      );

  SmartPlusNotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? lowStockEnabled,
    bool? salesEnabled,
    bool? discountEnabled,
    bool? forecastEnabled,
  }) => SmartPlusNotificationPreferences(
    inAppEnabled: inAppEnabled ?? this.inAppEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    lowStockEnabled: lowStockEnabled ?? this.lowStockEnabled,
    salesEnabled: salesEnabled ?? this.salesEnabled,
    discountEnabled: discountEnabled ?? this.discountEnabled,
    forecastEnabled: forecastEnabled ?? this.forecastEnabled,
  );
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
    this.requiresOwnerConfirmation = true,
    this.isRead = false,
  });

  SmartPlusNotification copyWith({bool? isRead}) => SmartPlusNotification(
    id: id,
    title: title,
    message: message,
    level: level,
    insightKind: insightKind,
    sourceData: sourceData,
    dataRange: dataRange,
    proposedAction: proposedAction,
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
  final POSService _pos;
  final Set<String> _readIds = <String>{};
  final Set<String> _reviewedIds = <String>{};
  final Map<String, SmartPlusNotification> _milestones =
      <String, SmartPlusNotification>{};
  List<SmartPlusNotification> _notifications = const [];
  SmartPlusNotificationPreferences _preferences =
      const SmartPlusNotificationPreferences();

  SmartPlusNotificationService(this._pos) {
    _pos.addListener(_onBusinessDataChanged);
    refresh();
  }

  List<SmartPlusNotification> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.isRead).length;
  SmartPlusNotificationPreferences get preferences => _preferences;
  bool isReviewed(String id) => _reviewedIds.contains(id);

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

  void refresh() {
    final visible = _preferences.inAppEnabled
        ? [..._milestones.values, ..._evaluate()]
        : const <SmartPlusNotification>[];
    _notifications = visible
        .map((item) => item.copyWith(isRead: _readIds.contains(item.id)))
        .toList(growable: false);
    notifyListeners();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reviewedKey, _reviewedIds.toList());
    refresh();
  }

  List<SmartPlusNotification> _evaluate() {
    final products = _pos.products;
    final completedSales = _pos.recentSales
        .where((sale) => sale.status == SaleStatus.completed)
        .toList();
    final suggestions = <SmartPlusNotification>[];

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
        ),
      );
    }

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
        ),
      );
    }

    final recentSaleCount = completedSales
        .where(
          (sale) => sale.saleDate.isAfter(
            DateTime.now().subtract(const Duration(days: 90)),
          ),
        )
        .length;
    if (_preferences.forecastEnabled &&
        recentSaleCount > 0 &&
        recentSaleCount < 30) {
      suggestions.add(
        SmartPlusNotification(
          id: 'forecast-data-readiness',
          title: 'More history improves demand signals',
          message:
              'Only $recentSaleCount completed sale(s) exist in the last 90 days. Keep recording sales, including seasonal periods, before relying on demand forecasts.',
          level: SmartPlusNotificationLevel.info,
          insightKind: SmartPlusInsightKind.forecast,
          sourceData: 'Completed sales count',
          dataRange: 'Last 90 days',
          proposedAction:
              'Keep recording sales, including seasonal periods, before relying on forecasts.',
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

  @override
  void dispose() {
    _pos.removeListener(_onBusinessDataChanged);
    super.dispose();
  }
}
