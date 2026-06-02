import 'product.dart';
import 'shoe_size.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount; // discount percentage (0-100)
  final ShoeSize? selectedShoeSize; // For shoe products, track which size

  CartItem({
    required this.product,
    required this.quantity,
    this.discount = 0.0,
    this.selectedShoeSize,
  });

  double get subtotal => product.sellingPrice * quantity;
  double get discountAmount => subtotal * (discount / 100);
  double get total => subtotal - discountAmount;

  CartItem copyWith({
    Product? product,
    int? quantity,
    double? discount,
    ShoeSize? selectedShoeSize,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      selectedShoeSize: selectedShoeSize ?? this.selectedShoeSize,
    );
  }
}
