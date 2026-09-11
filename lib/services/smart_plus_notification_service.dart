import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/sale.dart';
import 'pos_service.dart';

enum SmartPlusNotificationLevel { info, warning, critical }

class SmartPlusNotification {
  final String id;
  final String title;
  final String message;
  final SmartPlusNotificationLevel level;
  final bool isRead;

  const SmartPlusNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.level,
    this.isRead = false,
  });

  SmartPlusNotification copyWith({bool? isRead}) => SmartPlusNotification(
        id: id,
        title: title,
        message: message,
        level: level,
        isRead: isRead ?? this.isRead,
      );
}

/// Produces in-app owner alerts from observed business data. It does not make
/// remote AI calls, send operating-system notifications, or mutate business
/// data. Rules are recalculated whenever POS data changes.
class SmartPlusNotificationService extends ChangeNotifier {
  final POSService _pos;
  final Set<String> _readIds = <String>{};
  final Map<String, SmartPlusNotification> _milestones =
      <String, SmartPlusNotification>{};
  List<SmartPlusNotification> _notifications = const [];

  SmartPlusNotificationService(this._pos) {
    _pos.addListener(_onBusinessDataChanged);
    refresh();
  }

  List<SmartPlusNotification> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  void _onBusinessDataChanged() => refresh();

  void refresh() {
    _notifications = [..._milestones.values, ..._evaluate()]
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

  List<SmartPlusNotification> _evaluate() {
    final products = _pos.products;
    final completedSales = _pos.recentSales
        .where((sale) => sale.status == SaleStatus.completed)
        .toList();
    final suggestions = <SmartPlusNotification>[];

    final outOfStock = products
        .where((product) => product.quantity <= 0)
        .toList();
    if (outOfStock.isNotEmpty) {
      suggestions.add(
        SmartPlusNotification(
          id: 'out-of-stock',
          title: 'Products are out of stock',
          message:
              '${outOfStock.length} product(s) cannot be sold. Review Inventory and restock before the next sale.',
          level: SmartPlusNotificationLevel.critical,
        ),
      );
    }

    final lowStock = products
        .where((product) => product.quantity > 0 && product.lowStock)
        .toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    if (lowStock.isNotEmpty) {
      final examples = lowStock.take(2).map((item) => item.name).join(', ');
      suggestions.add(
        SmartPlusNotification(
          id: 'low-stock',
          title: 'Low-stock reorder suggested',
          message:
              '${lowStock.length} product(s) are at their reorder level, including $examples. Open SmartPlus for suggested quantities.',
          level: SmartPlusNotificationLevel.warning,
        ),
      );
    }

    final topSellerAtRisk = _topSellerAtRisk(products, completedSales);
    if (topSellerAtRisk != null) {
      suggestions.add(
        SmartPlusNotification(
          id: 'top-seller-low-stock-${topSellerAtRisk.id}',
          title: 'Top-selling product needs attention',
          message:
              '${topSellerAtRisk.name} is a recent seller and has only ${topSellerAtRisk.quantity} item(s) left.',
          level: SmartPlusNotificationLevel.warning,
        ),
      );
    }

    final salesChange = _weeklySalesChange(completedSales);
    if (salesChange != null && salesChange <= -15) {
      suggestions.add(
        SmartPlusNotification(
          id: 'weekly-sales-drop',
          title: 'Weekly sales need review',
          message:
              'Completed sales are down ${salesChange.abs().toStringAsFixed(1)}% compared with the preceding 7 days. SmartPlus can show the exact totals; it cannot infer the cause without foot-traffic or campaign data.',
          level: SmartPlusNotificationLevel.warning,
        ),
      );
    }

    final discountReviewCount = _largeDiscountCount(completedSales);
    if (discountReviewCount > 0) {
      suggestions.add(
        SmartPlusNotification(
          id: 'discount-review',
          title: 'Large discounts require review',
          message:
              '$discountReviewCount completed sale(s) in the last 30 days used a discount of 20% or more. This is a review rule, not a fraud finding.',
          level: SmartPlusNotificationLevel.info,
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
    if (recentSaleCount > 0 && recentSaleCount < 30) {
      suggestions.add(
        SmartPlusNotification(
          id: 'forecast-data-readiness',
          title: 'More history improves demand signals',
          message:
              'Only $recentSaleCount completed sale(s) exist in the last 90 days. Keep recording sales, including seasonal periods, before relying on demand forecasts.',
          level: SmartPlusNotificationLevel.info,
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
        quantities[item.productId] = (quantities[item.productId] ?? 0) +
            item.quantity;
      }
    }
    final atRisk = products
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
