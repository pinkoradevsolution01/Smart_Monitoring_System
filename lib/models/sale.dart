import 'package:intl/intl.dart';
import 'sale_item.dart';

enum SaleStatus { completed, pending, cancelled, returned }

enum TransactionType { pos, delivery }

enum DeliveryStatus { pending, inTransit, delivered, cancelled }

class Sale {
  final int? id;
  final String saleNumber;
  final List<SaleItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final String paymentMethod;
  final SaleStatus status;
  final String? notes;
  final String cashierName;
  final DateTime saleDate;
  final String? referenceCode; // For GCash/Online Bank transactions
  final String? imagePath; // For captured receipt images
  final String? cancelledReason; // Reason for cancellation
  final String? cancelledBy; // Who cancelled the sale
  final DateTime? cancelledAt; // When it was cancelled
  final TransactionType transactionType; // POS or For Delivery
  final double? reservationFee; // Reservation fee for pending payment orders
  final String? courier; // Courier service (JNT, FLASH, NINJAVAN, LBC)
  final DeliveryStatus? deliveryStatus; // Delivery progress status
  final int? customerId;
  final String? customerName;
  final int loyaltyPointsEarned;
  final int loyaltyPointsRedeemed;

  Sale({
    this.id,
    required this.saleNumber,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    this.notes,
    required this.cashierName,
    required this.saleDate,
    this.referenceCode,
    this.imagePath,
    this.cancelledReason,
    this.cancelledBy,
    this.cancelledAt,
    this.transactionType = TransactionType.pos,
    this.reservationFee,
    this.courier,
    this.deliveryStatus,
    this.customerId,
    this.customerName,
    this.loyaltyPointsEarned = 0,
    this.loyaltyPointsRedeemed = 0,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleNumber': saleNumber,
      'itemCount': itemCount,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'status': status.toString().split('.').last,
      'notes': notes,
      'cashierName': cashierName,
      'saleDate': saleDate.toIso8601String(),
      'referenceCode': referenceCode,
      'imagePath': imagePath,
      'cancelledReason': cancelledReason,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'transactionType': transactionType.toString().split('.').last,
      'reservationFee': reservationFee,
      'courier': courier,
      'deliveryStatus': deliveryStatus?.toString().split('.').last,
      'customerId': customerId,
      'customerName': customerName,
      'loyaltyPointsEarned': loyaltyPointsEarned,
      'loyaltyPointsRedeemed': loyaltyPointsRedeemed,
      // items are sometimes serialized by web storage; include when present
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    final itemsList = <SaleItem>[];
    if (map.containsKey('items') && map['items'] is List) {
      try {
        final rawItems = List.from(map['items'] as List);
        for (final ri in rawItems) {
          itemsList.add(SaleItem.fromMap(Map<String, dynamic>.from(ri as Map)));
        }
      } catch (_) {
        // ignore and leave items empty
      }
    }

    return Sale(
      id: map['id'],
      saleNumber: map['saleNumber'],
      items: itemsList,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? '',
      status: SaleStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['status'] ?? 'completed'),
        orElse: () => SaleStatus.completed,
      ),
      notes: map['notes'],
      cashierName: map['cashierName'] ?? '',
      saleDate: map['saleDate'] is String
          ? DateTime.parse(map['saleDate'])
          : (map['saleDate'] as DateTime? ?? DateTime.now()),
      referenceCode: map['referenceCode'],
      imagePath: map['imagePath'],
      cancelledReason: map['cancelledReason'],
      cancelledBy: map['cancelledBy'],
      cancelledAt: map['cancelledAt'] != null
          ? (map['cancelledAt'] is String
                ? DateTime.parse(map['cancelledAt'])
                : map['cancelledAt'] as DateTime?)
          : null,
      transactionType: TransactionType.values.firstWhere(
        (e) =>
            e.toString().split('.').last == (map['transactionType'] ?? 'pos'),
        orElse: () => TransactionType.pos,
      ),
      reservationFee: (map['reservationFee'] as num?)?.toDouble(),
      courier: map['courier'],
      deliveryStatus: map['deliveryStatus'] != null
          ? DeliveryStatus.values.firstWhere(
              (e) => e.toString().split('.').last == map['deliveryStatus'],
              orElse: () => DeliveryStatus.pending,
            )
          : null,
      customerId: (map['customerId'] as num?)?.toInt(),
      customerName: map['customerName'] as String?,
      loyaltyPointsEarned: (map['loyaltyPointsEarned'] as num?)?.toInt() ?? 0,
      loyaltyPointsRedeemed:
          (map['loyaltyPointsRedeemed'] as num?)?.toInt() ?? 0,
    );
  }

  Sale copyWith({
    int? id,
    String? saleNumber,
    List<SaleItem>? items,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? totalAmount,
    String? paymentMethod,
    SaleStatus? status,
    String? notes,
    String? cashierName,
    DateTime? saleDate,
    String? referenceCode,
    String? imagePath,
    String? cancelledReason,
    String? cancelledBy,
    DateTime? cancelledAt,
    TransactionType? transactionType,
    double? reservationFee,
    String? courier,
    DeliveryStatus? deliveryStatus,
    int? customerId,
    String? customerName,
    int? loyaltyPointsEarned,
    int? loyaltyPointsRedeemed,
  }) {
    return Sale(
      id: id ?? this.id,
      saleNumber: saleNumber ?? this.saleNumber,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      cashierName: cashierName ?? this.cashierName,
      saleDate: saleDate ?? this.saleDate,
      referenceCode: referenceCode ?? this.referenceCode,
      imagePath: imagePath ?? this.imagePath,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      transactionType: transactionType ?? this.transactionType,
      reservationFee: reservationFee ?? this.reservationFee,
      courier: courier ?? this.courier,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      loyaltyPointsEarned: loyaltyPointsEarned ?? this.loyaltyPointsEarned,
      loyaltyPointsRedeemed:
          loyaltyPointsRedeemed ?? this.loyaltyPointsRedeemed,
    );
  }

  String get formattedDate =>
      DateFormat('MMM dd, yyyy - HH:mm').format(saleDate);
  String get formattedTotal => '₱${totalAmount.toStringAsFixed(2)}';
}
