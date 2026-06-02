class RestockRecord {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;
  final int? supplierId;
  final String? supplierName;
  final String deliveryReceiptNo;
  final int damageQuantity;
  final String damageReason;
  final String notes;
  final String referencedBy;
  final DateTime restockDate;

  RestockRecord({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.supplierId,
    this.supplierName,
    this.deliveryReceiptNo = '',
    this.damageQuantity = 0,
    this.damageReason = '',
    this.notes = '',
    required this.referencedBy,
    DateTime? restockDate,
  }) : restockDate = restockDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'deliveryReceiptNo': deliveryReceiptNo,
      'damageQuantity': damageQuantity,
      'damageReason': damageReason,
      'notes': notes,
      'referencedBy': referencedBy,
      'restockDate': restockDate.toIso8601String(),
    };
  }

  factory RestockRecord.fromMap(Map<String, dynamic> map) {
    return RestockRecord(
      id: map['id'],
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      supplierId: map['supplierId'],
      supplierName: map['supplierName'],
      deliveryReceiptNo: map['deliveryReceiptNo'] ?? '',
      damageQuantity: map['damageQuantity'] ?? 0,
      damageReason: map['damageReason'] ?? '',
      notes: map['notes'] ?? '',
      referencedBy: map['referencedBy'],
      restockDate: DateTime.parse(map['restockDate']),
    );
  }
}
