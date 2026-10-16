import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/sale.dart';
import 'backend_api_service.dart';
import 'database_service.dart';
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
    this.supplierDeliveryEnabled = true,
  });

  final bool inAppEnabled;
  final bool emailEnabled;
  final bool lowStockEnabled;
  final bool salesEnabled;
  final bool discountEnabled;
  final bool forecastEnabled;
  final bool supplierDeliveryEnabled;

  Map<String, dynamic> toApiMap() => {
    'in_app_enabled': inAppEnabled,
    'email_enabled': emailEnabled,
    'low_stock_enabled': lowStockEnabled,
    'sales_enabled': salesEnabled,
    'discount_enabled': discountEnabled,
    'forecast_enabled': forecastEnabled,
    'supplier_delivery_enabled': supplierDeliveryEnabled,
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
      );

  SmartPlusNotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? lowStockEnabled,
    bool? salesEnabled,
    bool? discountEnabled,
    bool? forecastEnabled,
    bool? supplierDeliveryEnabled,
  }) => SmartPlusNotificationPreferences(
    inAppEnabled: inAppEnabled ?? this.inAppEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    lowStockEnabled: lowStockEnabled ?? this.lowStockEnabled,
    salesEnabled: salesEnabled ?? this.salesEnabled,
    discountEnabled: discountEnabled ?? this.discountEnabled,
    forecastEnabled: forecastEnabled ?? this.forecastEnabled,
    supplierDeliveryEnabled:
        supplierDeliveryEnabled ?? this.supplierDeliveryEnabled,
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
  List<SmartPlusNotification> _supplierDeliveryNotifications = const [];
  bool _supplierRefreshInFlight = false;
  DateTime? _lastSupplierRefresh;
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
          ]
        : const <SmartPlusNotification>[];
    _notifications = visible
        .map((item) => item.copyWith(isRead: _readIds.contains(item.id)))
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> _refreshSupplierDeliveryNotifications({
    bool force = false,
  }) async {
    if (!_preferences.supplierDeliveryEnabled) {
      if (_supplierDeliveryNotifications.isNotEmpty) {
        _supplierDeliveryNotifications = const [];
        _applyVisibleNotifications();
      }
      return;
    }
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
      _supplierDeliveryNotifications = await _evaluateSupplierDeliveryRules();
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
    super.dispose();
  }
}
