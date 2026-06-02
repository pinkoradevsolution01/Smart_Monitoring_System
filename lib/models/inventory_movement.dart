class InventoryMovement {
  final int? id;
  final int productId;
  final int quantityBefore;
  final int quantityAfter;
  final int quantityChanged;
  final String movementType; // 'sale', 'purchase', 'adjustment', 'return'
  final String reference; // sale number, PO number, etc
  final String reason;
  final DateTime movementDate;

  InventoryMovement({
    this.id,
    required this.productId,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.quantityChanged,
    required this.movementType,
    required this.reference,
    required this.reason,
    required this.movementDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'quantityBefore': quantityBefore,
      'quantityAfter': quantityAfter,
      'quantityChanged': quantityChanged,
      'movementType': movementType,
      'reference': reference,
      'reason': reason,
      'movementDate': movementDate.toIso8601String(),
    };
  }

  factory InventoryMovement.fromMap(Map<String, dynamic> map) {
    return InventoryMovement(
      id: map['id'],
      productId: map['productId'],
      quantityBefore: map['quantityBefore'],
      quantityAfter: map['quantityAfter'],
      quantityChanged: map['quantityChanged'],
      movementType: map['movementType'],
      reference: map['reference'],
      reason: map['reason'],
      movementDate: DateTime.parse(map['movementDate']),
    );
  }
}
