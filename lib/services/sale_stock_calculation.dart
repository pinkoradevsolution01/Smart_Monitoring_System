import '../models/product.dart';
import '../models/sale_item.dart';

/// Calculate a sale's stock change against the current stored product.
Product productAfterSale(Product product, SaleItem item) {
  if (item.quantity <= 0) throw StateError('Sale quantity must be positive.');
  if (product.hasShoeVariants) {
    final selected = item.shoeSize;
    if (selected == null) {
      throw StateError('Select a size for ${product.name}.');
    }
    final matching = product.shoeSizes!.where(
      (size) => size.usSize == selected,
    );
    if (matching.length != 1 || matching.single.quantity < item.quantity) {
      throw StateError(
        'Insufficient stock for ${product.name} size $selected.',
      );
    }
    final sizes = product.shoeSizes!
        .map(
          (size) => size.usSize == selected
              ? size.copyWith(quantity: size.quantity - item.quantity)
              : size,
        )
        .toList();
    return product.copyWith(
      shoeSizes: sizes,
      quantity: sizes.fold<int>(0, (sum, size) => sum + size.quantity),
    );
  }
  if (product.quantity < item.quantity) {
    throw StateError('Insufficient stock for ${product.name}.');
  }
  return product.copyWith(quantity: product.quantity - item.quantity);
}
