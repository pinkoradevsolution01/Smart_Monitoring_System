class PurchaseOrder {
  final int? id;
  final String orderNumber;
  final int supplierId;
  final String supplierName;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final String
  status; // 'pending', 'approved', 'completed', 'received', 'cancelled'
  final List<PurchaseOrderItem> items;
  final double totalAmount;
  final String notes;
  final String? approvedBy;
  final String? signatureData; // Base64 encoded signature image
  final DateTime? approvalDate;

  PurchaseOrder({
    this.id,
    required this.orderNumber,
    required this.supplierId,
    required this.supplierName,
    required this.orderDate,
    this.expectedDeliveryDate,
    required this.status,
    required this.items,
    required this.totalAmount,
    this.notes = '',
    this.approvedBy,
    this.signatureData,
    this.approvalDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'orderDate': orderDate.toIso8601String(),
      'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
      'status': status,
      'totalAmount': totalAmount,
      'notes': notes,
      'approvedBy': approvedBy,
      'signatureData': signatureData,
      'approvalDate': approvalDate?.toIso8601String(),
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'],
      orderNumber: map['orderNumber'],
      supplierId: map['supplierId'],
      supplierName: map['supplierName'],
      orderDate: DateTime.parse(map['orderDate']),
      expectedDeliveryDate: map['expectedDeliveryDate'] != null
          ? DateTime.parse(map['expectedDeliveryDate'])
          : null,
      status: map['status'],
      items: [], // Items loaded separately
      totalAmount: map['totalAmount'],
      notes: map['notes'] ?? '',
      approvedBy: map['approvedBy'],
      signatureData: map['signatureData'],
      approvalDate: map['approvalDate'] != null
          ? DateTime.parse(map['approvalDate'])
          : null,
    );
  }

  PurchaseOrder copyWith({
    int? id,
    String? orderNumber,
    int? supplierId,
    String? supplierName,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    String? status,
    List<PurchaseOrderItem>? items,
    double? totalAmount,
    String? notes,
    String? approvedBy,
    String? signatureData,
    DateTime? approvalDate,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      status: status ?? this.status,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      approvedBy: approvedBy ?? this.approvedBy,
      signatureData: signatureData ?? this.signatureData,
      approvalDate: approvalDate ?? this.approvalDate,
    );
  }
}

class PurchaseOrderItem {
  final int? id;
  final int orderId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  PurchaseOrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      id: map['id'],
      orderId: map['orderId'],
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      unitPrice: map['unitPrice'],
      totalPrice: map['totalPrice'],
    );
  }

  PurchaseOrderItem copyWith({
    int? id,
    int? orderId,
    int? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return PurchaseOrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}
