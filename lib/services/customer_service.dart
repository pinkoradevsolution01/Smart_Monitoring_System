import 'package:uuid/uuid.dart';

import '../models/customer.dart';
import '../models/loyalty_ledger_entry.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';
import 'database_service.dart';

/// A safe, user-facing error raised before a duplicate customer is saved.
///
/// Email and phone values are intentionally checked in the service layer as
/// well as by the UI.  This keeps quick-customer creation and future screens
/// from silently creating duplicate loyalty accounts.
class DuplicateCustomerException implements Exception {
  final String field;
  final String existingCustomerName;

  const DuplicateCustomerException({
    required this.field,
    required this.existingCustomerName,
  });

  @override
  String toString() =>
      'A customer with this $field already exists: $existingCustomerName.';
}

enum CustomerSegment { newCustomer, regular, vip, atRisk }

class CustomerInsights {
  final CustomerSegment segment;
  final List<Sale> purchaseHistory;
  final double completedSalesTotal;
  final DateTime? lastPurchaseAt;

  const CustomerInsights({
    required this.segment,
    required this.purchaseHistory,
    required this.completedSalesTotal,
    required this.lastPurchaseAt,
  });

  String get segmentLabel => switch (segment) {
    CustomerSegment.newCustomer => 'New customer',
    CustomerSegment.regular => 'Regular customer',
    CustomerSegment.vip => 'VIP customer',
    CustomerSegment.atRisk => 'At-risk customer',
  };
}

class LoyaltyExpirySummary {
  final DateTime policyStartDate;
  final DateTime? nextExpiryDate;
  final int pointsExpiringSoon;

  const LoyaltyExpirySummary({
    required this.policyStartDate,
    required this.nextExpiryDate,
    required this.pointsExpiringSoon,
  });
}

class CustomerService {
  final DatabaseService _databaseService = DatabaseService();

  static int pointsForAmount(double amount) {
    if (amount <= 0) return 0;
    return (amount / 100).floor();
  }

  // Compute margin-based points for a cart. Points are proportional to
  // the product's margin percentage: points_per_item = floor(item.total * marginPct)
  // where marginPct = (sellingPrice - buyingPrice) / sellingPrice.
  static int pointsForCart(List<CartItem> cart) {
    int total = 0;
    for (final item in cart) {
      final selling = item.product.sellingPrice;
      final buying = item.product.buyingPrice;
      double marginPct = 0.0;
      if (selling > 0) {
        marginPct = (selling - buying) / selling;
        if (marginPct < 0) marginPct = 0.0;
      }
      final itemAmount = item.total; // already accounts for discount
      final pointsForItem = (itemAmount * marginPct).floor();
      total += pointsForItem;
    }
    return total;
  }

  // Redemption rules
  static const int minRedeemPoints = 500;
  static const double pesoPerPoint = 0.02; // ₱0.02 per point

  // New redemption policy
  // Discount is 2% of the total sales when redeemed
  static const double discountRate = 0.02; // 2%
  // Minimum purchase amount required to apply redemption
  static const double minPurchaseAmount = 100.0; // ₱100

  static double redemptionValuePesos(int points) => points * pesoPerPoint;

  Future<List<Customer>> getCustomers({String? query}) {
    return _databaseService.getCustomers(query: query);
  }

  Future<Customer?> getCustomerById(int id) {
    return _databaseService.getCustomerById(id);
  }

  Future<Customer?> getCustomerByBarcode(String barcodeValue) {
    return _databaseService.getCustomerByBarcode(barcodeValue);
  }

  Future<Customer?> getCustomerByName(String fullName) {
    return _databaseService.getCustomerByName(fullName);
  }

  Future<Customer> saveCustomer(Customer customer) async {
    await _ensureNoDuplicateContact(customer);
    if (customer.id == null) {
      return _databaseService.insertCustomer(customer);
    }
    return _databaseService.updateCustomer(customer);
  }

  /// Matches contacts after removing harmless formatting differences.  An
  /// empty email or phone is not treated as a unique value.
  Future<void> _ensureNoDuplicateContact(Customer candidate) async {
    final email = _normaliseEmail(candidate.email);
    final phone = _normalisePhone(candidate.phoneNumber);
    if (email == null && phone == null) return;

    final customers = await getCustomers();
    for (final existing in customers) {
      if (existing.id == candidate.id || !existing.isActive) continue;
      if (email != null && _normaliseEmail(existing.email) == email) {
        throw DuplicateCustomerException(
          field: 'email address',
          existingCustomerName: existing.fullName,
        );
      }
      if (phone != null && _normalisePhone(existing.phoneNumber) == phone) {
        throw DuplicateCustomerException(
          field: 'phone number',
          existingCustomerName: existing.fullName,
        );
      }
    }
  }

  String? _normaliseEmail(String? value) {
    final normalised = value?.trim().toLowerCase() ?? '';
    return normalised.isEmpty ? null : normalised;
  }

  String? _normalisePhone(String? value) {
    final normalised = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return normalised.isEmpty ? null : normalised;
  }

  Future<CustomerInsights> getInsights(Customer customer) async {
    final sales =
        (await _databaseService.getAllSales())
            .where(
              (sale) =>
                  sale.customerId == customer.id &&
                  sale.status == SaleStatus.completed,
            )
            .toList()
          ..sort((a, b) => b.saleDate.compareTo(a.saleDate));

    final total = sales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
    final lastPurchaseAt = sales.isEmpty ? null : sales.first.saleDate;
    final now = DateTime.now();
    final segment = _segmentFor(
      customer: customer,
      completedSales: sales,
      completedSalesTotal: total,
      lastPurchaseAt: lastPurchaseAt,
      now: now,
    );

    return CustomerInsights(
      segment: segment,
      purchaseHistory: sales,
      completedSalesTotal: total,
      lastPurchaseAt: lastPurchaseAt,
    );
  }

  CustomerSegment _segmentFor({
    required Customer customer,
    required List<Sale> completedSales,
    required double completedSalesTotal,
    required DateTime? lastPurchaseAt,
    required DateTime now,
  }) {
    // Segments are transparent, local labels rather than hidden scoring:
    // VIP = 10 completed purchases or PHP 10,000 completed spend; at-risk =
    // a prior purchase but no purchase in 90 days.
    if (completedSales.length >= 10 || completedSalesTotal >= 10000) {
      return CustomerSegment.vip;
    }
    if (lastPurchaseAt != null && now.difference(lastPurchaseAt).inDays > 90) {
      return CustomerSegment.atRisk;
    }
    if (completedSales.isEmpty &&
        now.difference(customer.createdAt).inDays <= 30) {
      return CustomerSegment.newCustomer;
    }
    return CustomerSegment.regular;
  }

  /// Calculates a visible, FIFO loyalty-expiry forecast.  It does not deduct
  /// points automatically: an owner must review the policy and take any
  /// action deliberately.  The current policy is 365 days from earning.
  Future<LoyaltyExpirySummary> getLoyaltyExpirySummary(
    int customerId, {
    Duration validity = const Duration(days: 365),
    Duration warningWindow = const Duration(days: 30),
  }) async {
    final entries = await getLedger(customerId);
    final earns =
        entries
            .where((entry) => entry.entryType == LoyaltyEntryType.earn)
            .map((entry) => _ExpiringPoints(entry.createdAt, entry.points))
            .toList()
          ..sort((a, b) => a.earnedAt.compareTo(b.earnedAt));

    // Redemptions consume the oldest earned points first.
    var pointsRedeemed = entries
        .where((entry) => entry.entryType == LoyaltyEntryType.redeem)
        .fold<int>(0, (sum, entry) => sum + entry.points.abs());
    for (final earn in earns) {
      final used = pointsRedeemed.clamp(0, earn.remainingPoints);
      earn.remainingPoints -= used;
      pointsRedeemed -= used;
    }

    final now = DateTime.now();
    final warningEnd = now.add(warningWindow);
    DateTime? nextExpiry;
    var expiringSoon = 0;
    for (final earn in earns.where((entry) => entry.remainingPoints > 0)) {
      final expiry = earn.earnedAt.add(validity);
      if (nextExpiry == null || expiry.isBefore(nextExpiry)) {
        nextExpiry = expiry;
      }
      if (!expiry.isBefore(now) && !expiry.isAfter(warningEnd)) {
        expiringSoon += earn.remainingPoints;
      }
    }
    return LoyaltyExpirySummary(
      policyStartDate: now.subtract(validity),
      nextExpiryDate: nextExpiry,
      pointsExpiringSoon: expiringSoon,
    );
  }

  Future<void> deactivateCustomer(int id) {
    return _databaseService.deactivateCustomer(id);
  }

  Future<void> deleteCustomer(int id) {
    return _databaseService.deleteCustomer(id);
  }

  Future<List<LoyaltyLedgerEntry>> getLedger(int customerId) {
    return _databaseService.getLoyaltyLedger(customerId);
  }

  Future<void> awardPoints({
    required int customerId,
    int? saleId,
    required int points,
    String? notes,
  }) {
    return _databaseService.awardCustomerPoints(
      customerId: customerId,
      saleId: saleId,
      points: points,
      notes: notes,
    );
  }

  Future<bool> redeemPoints({
    required int customerId,
    required int points,
    String? notes,
  }) {
    if (points < minRedeemPoints) return Future.value(false);
    return _databaseService.redeemCustomerPoints(
      customerId: customerId,
      points: points,
      notes: notes,
    );
  }

  Future<Customer> createQuickCustomer({
    required String fullName,
    String? phoneNumber,
    String? email,
    String? address,
  }) {
    final code = const Uuid().v4();
    return saveCustomer(
      Customer(
        customerCode: code,
        fullName: fullName,
        phoneNumber: phoneNumber,
        email: email,
        address: address,
      ),
    );
  }
}

class _ExpiringPoints {
  final DateTime earnedAt;
  int remainingPoints;

  _ExpiringPoints(this.earnedAt, this.remainingPoints);
}
