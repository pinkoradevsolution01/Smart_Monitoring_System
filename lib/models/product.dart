import 'shoe_size.dart';
import 'dart:convert';

class Product {
  final int? id;
  final String barcode;
  final String name;
  final String? description;
  final double buyingPrice;
  final double sellingPrice;
  final int quantity;
  final int reorderLevel;
  final String category;
  final String? imagePath;
  final DateTime createdAt;
  final List<ShoeSize>? shoeSizes; // For shoe store products
  final String? sizeType; // 'men', 'women', 'unisex' for shoe products

  Product({
    this.id,
    required this.barcode,
    required this.name,
    this.description,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.reorderLevel,
    required this.category,
    this.imagePath,
    required this.createdAt,
    this.shoeSizes,
    this.sizeType,
  });

  double get profit => sellingPrice - buyingPrice;
  bool get lowStock => quantity <= reorderLevel;
  bool get hasShoeVariants => shoeSizes != null && shoeSizes!.isNotEmpty;

  // Calculate total quantity from shoe sizes if available
  int get totalQuantity {
    if (hasShoeVariants) {
      return shoeSizes!.fold(0, (sum, size) => sum + size.quantity);
    }
    return quantity;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'description': description,
      'buyingPrice': buyingPrice,
      'sellingPrice': sellingPrice,
      // When shoe sizes are present, persist the total computed quantity
      'quantity': hasShoeVariants ? totalQuantity : quantity,
      'reorderLevel': reorderLevel,
      'category': category,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'shoeSizes': shoeSizes != null
          ? jsonEncode(shoeSizes!.map((s) => s.toMap()).toList())
          : null,
      'sizeType': sizeType,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    List<ShoeSize>? shoeSizes;
    if (map['shoeSizes'] != null && map['shoeSizes'] is String) {
      try {
        final List<dynamic> sizeList = jsonDecode(map['shoeSizes'] as String);
        shoeSizes = sizeList.map((s) => ShoeSize.fromMap(s)).toList();
      } catch (e) {
        shoeSizes = null;
      }
    }

    return Product(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      buyingPrice: (map['buyingPrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      quantity: map['quantity'] as int,
      reorderLevel: map['reorderLevel'] as int,
      category: map['category'] as String,
      imagePath: map['imagePath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      shoeSizes: shoeSizes,
      sizeType: map['sizeType'] as String?,
    );
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    String? description,
    double? buyingPrice,
    double? sellingPrice,
    int? quantity,
    int? reorderLevel,
    String? category,
    String? imagePath,
    bool clearImagePath = false,
    DateTime? createdAt,
    List<ShoeSize>? shoeSizes,
    String? sizeType,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      description: description ?? this.description,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      category: category ?? this.category,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      createdAt: createdAt ?? this.createdAt,
      shoeSizes: shoeSizes ?? this.shoeSizes,
      sizeType: sizeType ?? this.sizeType,
    );
  }
}
