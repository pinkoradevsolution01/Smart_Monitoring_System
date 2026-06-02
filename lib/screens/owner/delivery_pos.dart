import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'dart:io';
import '../../utils/app_localizations.dart';
import '../../services/pos_service.dart';
import '../../models/product.dart';
import 'widgets/delivery_cart_sheet.dart';

class DeliveryPOS extends StatefulWidget {
  final String operatorName;

  const DeliveryPOS({super.key, required this.operatorName});

  @override
  State<DeliveryPOS> createState() => _DeliveryPOSState();
}

class _DeliveryPOSState extends State<DeliveryPOS> {
  final POSService pos = GetIt.I<POSService>();
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  final String _selectedPaymentMethod = 'cash';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    pos.addListener(_onPosChanged);
    pos.loadProducts();
    _updateCategories();
  }

  void _updateCategories() {
    final categories = pos.products.map((p) => p.category).toSet().toList();
    categories.sort();
    setState(() {
      _categories = ['All', ...categories];
    });
  }

  void _onPosChanged() {
    if (mounted) {
      _updateCategories();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    pos.removeListener(_onPosChanged);
    super.dispose();
  }

  void openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeliveryCartSheet(
        pos: pos,
        operatorName: widget.operatorName,
        initialPaymentMethod: _selectedPaymentMethod,
      ),
    );
  }

  Widget buildProductTile(Product p) {
    final isOutOfStock = p.hasShoeVariants
        ? p.totalQuantity <= 0
        : p.quantity <= 0;
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isOutOfStock
            ? null
            : () {
                // For shoe products, show size selection dialog
                if (p.hasShoeVariants) {
                  _showShoeSizeSelectionDialog(p);
                  return;
                }

                // Check if adding would exceed stock
                final existingItems = pos.cart.where(
                  (item) => item.product.id == p.id,
                );
                final existingInCart = existingItems.isEmpty
                    ? 0
                    : existingItems.first.quantity;

                if (existingInCart >= p.quantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cannot add more. Only ${p.quantity} in stock',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                pos.addToCart(p, quantity: 1);
              },
        onLongPress: () async {
          if (p.imagePath != null && p.imagePath!.isNotEmpty) {
            await showDialog(
              context: context,
              builder: (_) => Dialog(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Center(
                            child: Image.file(
                              File(p.imagePath!),
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const SizedBox(
                                width: 200,
                                height: 200,
                                child: Center(
                                  child: Icon(Icons.broken_image, size: 48),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(AppLocalizations.t('close')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Display product image if available
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: p.imagePath != null && p.imagePath!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(p.imagePath!),
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.shopping_bag,
                                    size: 80,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.shopping_bag,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      p.category,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${p.sellingPrice.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.hasShoeVariants
                        ? 'Stock: ${p.totalQuantity} (${AppLocalizations.t('multiple_sizes')})'
                        : 'Stock: ${p.quantity}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          (p.hasShoeVariants ? p.totalQuantity : p.quantity) <=
                              0
                          ? Colors.red
                          : ((p.hasShoeVariants
                                        ? p.totalQuantity
                                        : p.quantity) <=
                                    p.reorderLevel
                                ? Colors.orange
                                : Colors.grey),
                      fontSize: 11,
                      fontWeight:
                          (p.hasShoeVariants ? p.totalQuantity : p.quantity) <=
                              0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isOutOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block, color: Colors.white, size: 32),
                        SizedBox(height: 4),
                        Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showShoeSizeSelectionDialog(Product product) {
    if (!product.hasShoeVariants || product.shoeSizes == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppLocalizations.t('select_size')} - ${product.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: product.shoeSizes!.length,
            itemBuilder: (context, index) {
              final size = product.shoeSizes![index];
              final isAvailable = size.quantity > 0;

              return ListTile(
                enabled: isAvailable,
                title: Text(
                  'US: ${size.usSize} | UK: ${size.ukSize} | EU: ${size.euSize}',
                  style: TextStyle(
                    color: isAvailable ? null : Colors.grey,
                    fontWeight: isAvailable
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${size.cmSize} cm',
                  style: TextStyle(color: isAvailable ? null : Colors.grey),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${size.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: isAvailable
                    ? () {
                        Navigator.pop(context);
                        // Add product to cart with specific size
                        pos.addToCart(
                          product,
                          quantity: 1,
                          selectedShoeSize: size,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${product.name} (Size: ${size.usSize}) ${AppLocalizations.t('added_to_cart')}',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('cancel')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = pos.products;
    var products = _selectedCategory == 'All'
        ? allProducts
        : allProducts.where((p) => p.category == _selectedCategory).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      products = products.where((p) {
        final query = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(query) ||
            p.barcode.toLowerCase().contains(query);
      }).toList();
    }

    final cartCount = pos.cart.fold<int>(0, (s, c) => s + c.quantity);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_shipping, size: 24),
            const SizedBox(width: 8),
            Text(AppLocalizations.t('for_delivery')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: AppLocalizations.t('open_cart_tooltip'),
            onPressed: openCartSheet,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1000,
                maxHeight: constraints.maxHeight,
              ),
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.t('search_products'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  // Category Filter Tabs
                  Container(
                    height: 50,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = category == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Products Grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: products.isEmpty
                          ? Center(
                              child: Text(
                                _selectedCategory == 'All'
                                    ? 'No products'
                                    : 'No products in $_selectedCategory',
                              ),
                            )
                          : GridView.builder(
                              itemCount: products.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        MediaQuery.of(context).size.width > 600
                                        ? 3
                                        : 2,
                                    childAspectRatio: 0.75,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemBuilder: (context, index) {
                                final p = products[index];
                                return buildProductTile(p);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openCartSheet,
        icon: const Icon(Icons.shopping_cart_checkout),
        label: Text(
          AppLocalizations.t(
            'cart_count',
          ).replaceAll('{count}', cartCount.toString()),
        ),
      ),
    );
  }
}
