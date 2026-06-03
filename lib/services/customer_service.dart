import 'package:uuid/uuid.dart';

import '../models/customer.dart';
import '../models/loyalty_ledger_entry.dart';
import '../models/cart_item.dart';
import 'database_service.dart';

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
    if (customer.id == null) {
      return _databaseService.insertCustomer(customer);
    }
    return _databaseService.updateCustomer(customer);
  }

  Future<void> deactivateCustomer(int id) {
    return _databaseService.deactivateCustomer(id);
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
