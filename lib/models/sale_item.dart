class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double subtotal;
  final String? shoeSize; // US size for shoe products

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.subtotal,
    this.shoeSize,
  });

  double get total => subtotal - discount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'subtotal': subtotal,
      'shoeSize': shoeSize,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['saleId'],
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      unitPrice: map['unitPrice'],
      discount: map['discount'],
      subtotal: map['subtotal'],
      shoeSize: map['shoeSize'] as String?,
    );
  }
}
