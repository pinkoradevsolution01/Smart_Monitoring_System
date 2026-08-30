import 'dart:io';
import '../../utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../models/shoe_size.dart';
import '../../services/pos_service.dart';
import '../../services/package_service.dart';
import '../../services/business_info_service.dart';
import '../../utils/app_localizations.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final POSService _posService = GetIt.I.get<POSService>();
  final PackageService _packageService = GetIt.I.get<PackageService>();
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _showLowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _posService.addListener(_onPosChanged);
    _loadProducts();
  }

  void _onPosChanged() {
    if (mounted) {
      _filterProducts();
    }
  }

  @override
  void dispose() {
    _posService.removeListener(_onPosChanged);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    await _posService.loadProducts();
    _filterProducts();
  }

  void _filterProducts() {
    setState(() {
      var products = _posService.products;

      if (_showLowStockOnly) {
        products = products.where((p) => p.lowStock).toList();
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        products = products.where((p) {
          return p.name.toLowerCase().contains(query) ||
              p.barcode.toLowerCase().contains(query) ||
              p.category.toLowerCase().contains(query);
        }).toList();
      }

      _filteredProducts = products;
    });
  }

  void _showProductDialog({Product? product}) {
    // Only check product limit when adding new product (not editing)
    if (product == null) {
      final currentProductCount = _posService.products.length;
      final maxProducts = _packageService.maxProducts;

      if (_packageService.isProductLimitReached(currentProductCount)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product limit reached! Your ${_packageService.selectedPackage?.name ?? "current"} package allows only $maxProducts products.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      builder: (context) => ProductFormDialog(
        product: product,
        onSave: () {
          _loadProducts();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('confirm_delete')),
        content: Text(
          AppLocalizations.t(
            'delete_product_msg',
          ).replaceAll('{name}', product.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.t('delete')),
          ),
        ],
      ),
    );

    if (confirm == true && product.id != null) {
      await _posService.deleteProduct(product.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('product_deleted'))),
        );
      }
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _posService.products.where((p) => p.lowStock).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('manage_products_title')),
        actions: [
          if (lowStockCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$lowStockCount'),
                child: const Icon(Icons.warning_amber),
              ),
              onPressed: () {
                setState(() {
                  _showLowStockOnly = !_showLowStockOnly;
                  _filterProducts();
                });
              },
              tooltip: _showLowStockOnly
                  ? AppLocalizations.t('all_products')
                  : AppLocalizations.t(
                      'low_stock_items',
                    ).replaceAll('{count}', '$lowStockCount'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.t('search_products'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _filterProducts();
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterProducts();
                      });
                    },
                  ),
                ),

                // Low stock filter chip
                if (_showLowStockOnly)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Chip(
                      label: Text(
                        AppLocalizations.t(
                          'low_stock_items',
                        ).replaceAll('{count}', '$lowStockCount'),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _showLowStockOnly = false;
                          _filterProducts();
                        });
                      },
                      backgroundColor: Colors.orange.shade100,
                    ),
                  ),

                // Product list
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? Center(child: Text(AppLocalizations.t('no_products')))
                      : ListView.builder(
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return ProductListTile(
                              product: product,
                              onEdit: () =>
                                  _showProductDialog(product: product),
                              onDelete: () => _deleteProduct(product),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.t('add_product')),
      ),
    );
  }
}

class ProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductListTile({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).colorScheme.primary == const Color(0xFF6F4E37);
    final isLowStock = product.lowStock;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isLowStock ? Colors.orange.shade50 : null,
      child: ListTile(
        leading: product.imagePath != null
            ? Image.file(
                File(product.imagePath!),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.inventory_2, size: 40),
              )
            : const Icon(Icons.inventory_2, size: 40),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
            ),
            if (isLowStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppLocalizations.t('low_stock_alert'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.t('barcode')}: ${product.barcode} | ${AppLocalizations.t('category')}: ${product.category}',
            ),
            Text(
              '${AppLocalizations.t('stock')}: ${product.quantity} | ${AppLocalizations.t('selling_price')}: ${AppCurrency.peso(product.sellingPrice)}',
              style: TextStyle(
                color: isLowStock ? Colors.red : null,
                fontWeight: isLowStock ? FontWeight.bold : null,
              ),
            ),
            Text(
              '${AppLocalizations.t('reorder_level')}: ${product.reorderLevel} | ${AppLocalizations.t('profit')}: ${AppCurrency.peso(product.profit)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.t('edit_product')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.t('delete_product'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
        ),
      ),
    );
  }
}

class ProductFormDialog extends StatefulWidget {
  final Product? product;
  final VoidCallback onSave;

  const ProductFormDialog({super.key, this.product, required this.onSave});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final POSService _posService = GetIt.I.get<POSService>();
  final BusinessInfoService _businessInfoService = BusinessInfoService();

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _quantityController;
  late TextEditingController _reorderLevelController;
  String? _imagePath;
  bool _isSubmitting = false;

  // Shoe size related fields
  String? _selectedSizeType;
  List<ShoeSize> _shoeSizes = [];
  final Map<String, TextEditingController> _sizeQuantityControllers = {};

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _buyingPriceController = TextEditingController(
      text: p?.buyingPrice.toString() ?? '',
    );
    _sellingPriceController = TextEditingController(
      text: p?.sellingPrice.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: p?.quantity.toString() ?? '',
    );
    _reorderLevelController = TextEditingController(
      text: p?.reorderLevel.toString() ?? '5',
    );
    _imagePath = p?.imagePath;

    // Initialize shoe size data if editing existing product
    if (p?.shoeSizes != null && p!.shoeSizes!.isNotEmpty) {
      _selectedSizeType = p.sizeType;
      _shoeSizes = List<ShoeSize>.from(p.shoeSizes!);
      for (var size in _shoeSizes) {
        _sizeQuantityControllers[size.usSize] = TextEditingController(
          text: size.quantity.toString(),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _reorderLevelController.dispose();
    for (var controller in _sizeQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);

    if (file?.path != null) {
      setState(() {
        _imagePath = file!.path;
      });
    }
  }

  Future<void> _captureImage() async {
    if (kIsWeb) {
      // Web doesn't support camera capture via image_picker
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('camera_not_supported_web'))),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        _imagePath = photo.path;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (kIsWeb) {
      // On web, just use file picker
      await _pickImage();
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('select_image_source')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppLocalizations.t('camera')),
              onTap: () {
                Navigator.pop(context);
                _captureImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppLocalizations.t('gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _initializeShoeSizes() {
    // Clear existing data
    _shoeSizes.clear();
    for (var controller in _sizeQuantityControllers.values) {
      controller.dispose();
    }
    _sizeQuantityControllers.clear();

    if (_selectedSizeType == null) return;

    // Get appropriate size chart based on selected type
    List<Map<String, String>> sizeChart = [];
    switch (_selectedSizeType) {
      case 'men':
        sizeChart = ShoeSizeConversions.menSizes;
        break;
      case 'women':
        sizeChart = ShoeSizeConversions.womenSizes;
        break;
      case 'unisex':
        sizeChart = ShoeSizeConversions.unisexSizes;
        break;
    }

    // Initialize shoe sizes and controllers
    for (var sizeData in sizeChart) {
      final shoeSize = ShoeSize(
        usSize: sizeData['us']!,
        ukSize: sizeData['uk']!,
        euSize: sizeData['eu']!,
        cmSize: sizeData['cm']!,
        quantity: 0,
      );
      _shoeSizes.add(shoeSize);

      // Check if we have existing data for this size
      final existingSize = widget.product?.shoeSizes?.firstWhere(
        (s) => s.usSize == shoeSize.usSize,
        orElse: () => ShoeSize(
          usSize: '',
          ukSize: '',
          euSize: '',
          cmSize: '',
          quantity: 0,
        ),
      );

      _sizeQuantityControllers[shoeSize.usSize] = TextEditingController(
        text: existingSize != null && existingSize.usSize.isNotEmpty
            ? existingSize.quantity.toString()
            : '0',
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Calculate total quantity from shoe sizes if applicable
      int totalQuantity = 0;
      List<ShoeSize>? finalShoeSizes;

      // Check if business is Shoe Store and sizes are selected
      if (_businessInfoService.businessInfo?.businessType == 'Shoe Store') {
        if (_selectedSizeType == null || _shoeSizes.isEmpty) {
          throw Exception(
            'Please select a size type and enter quantities for shoe products',
          );
        }

        // Build shoe sizes list with quantities
        finalShoeSizes = _shoeSizes.map((size) {
          final qty =
              int.tryParse(
                _sizeQuantityControllers[size.usSize]?.text.trim() ?? '0',
              ) ??
              0;
          return ShoeSize(
            usSize: size.usSize,
            ukSize: size.ukSize,
            euSize: size.euSize,
            cmSize: size.cmSize,
            quantity: qty,
          );
        }).toList();

        // Calculate total from all sizes
        totalQuantity = finalShoeSizes.fold(
          0,
          (sum, size) => sum + size.quantity,
        );

        // Validate that at least one size has quantity
        if (totalQuantity == 0) {
          throw Exception('Please enter quantity for at least one shoe size');
        }
      } else {
        // For non-shoe stores, parse quantity from the quantity field
        totalQuantity = int.parse(_quantityController.text.trim());
      }

      // Parse numeric fields with proper error handling
      final buyingPriceText = _buyingPriceController.text.trim();
      final sellingPriceText = _sellingPriceController.text.trim();
      final reorderLevelText = _reorderLevelController.text.trim();

      final buyingPrice = double.tryParse(buyingPriceText);
      final sellingPrice = double.tryParse(sellingPriceText);
      final reorderLevel = int.tryParse(reorderLevelText);

      if (buyingPrice == null) {
        throw Exception('Invalid buying price: "$buyingPriceText"');
      }
      if (sellingPrice == null) {
        throw Exception('Invalid selling price: "$sellingPriceText"');
      }
      if (reorderLevel == null) {
        throw Exception('Invalid reorder level: "$reorderLevelText"');
      }

      final product = Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        buyingPrice: buyingPrice,
        sellingPrice: sellingPrice,
        quantity: totalQuantity,
        reorderLevel: reorderLevel,
        imagePath: _imagePath,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        shoeSizes: finalShoeSizes,
        sizeType: _selectedSizeType,
      );

      if (widget.product == null) {
        await _posService.addProduct(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.t('product_added'))),
          );
        }
      } else {
        await _posService.updateProduct(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.t('product_updated'))),
          );
        }
      }

      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(
        isEditing
            ? AppLocalizations.t('edit_product')
            : AppLocalizations.t('add_product'),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('name'),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('barcode'),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('category'),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText:
                        '${AppLocalizations.t('description')} (${AppLocalizations.t('optional')})',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyingPriceController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.t('buying_price'),
                          prefixText: '₱',
                          hintText: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (double.tryParse(v!) == null) {
                            return 'Invalid number (use digits only, e.g., 100.50)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.t('selling_price'),
                          prefixText: '₱',
                          hintText: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (double.tryParse(v!) == null) {
                            return 'Invalid number (use digits only, e.g., 150.75)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.t('quantity'),
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        enabled:
                            _businessInfoService.businessInfo?.businessType !=
                            'Shoe Store',
                        validator: (v) {
                          if (_businessInfoService.businessInfo?.businessType ==
                              'Shoe Store') {
                            return null; // Skip validation for shoe stores
                          }
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (int.tryParse(v!) == null) {
                            return 'Invalid number (whole numbers only, e.g., 50)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reorderLevelController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.t('reorder_level'),
                          hintText: '5',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (int.tryParse(v!) == null) {
                            return 'Invalid number (whole numbers only, e.g., 5)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                // Shoe Size Selection (Only for Shoe Store business type)
                if (_businessInfoService.businessInfo?.businessType ==
                    'Shoe Store') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.t('shoe_size_section'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSizeType,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('size_type'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please select a size type for shoe products';
                      }
                      return null;
                    },
                    items: [
                      DropdownMenuItem(
                        value: 'men',
                        child: Text(AppLocalizations.t('men_sizes')),
                      ),
                      DropdownMenuItem(
                        value: 'women',
                        child: Text(AppLocalizations.t('women_sizes')),
                      ),
                      DropdownMenuItem(
                        value: 'unisex',
                        child: Text(AppLocalizations.t('unisex_sizes')),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSizeType = value;
                        _initializeShoeSizes();
                      });
                    },
                  ),
                  if (_selectedSizeType != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.t('enter_quantity_per_size'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: _shoeSizes.length,
                              itemBuilder: (context, index) {
                                final size = _shoeSizes[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'US: ${size.usSize} | UK: ${size.ukSize} | EU: ${size.euSize} | CM: ${size.cmSize}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          controller:
                                              _sizeQuantityControllers[size
                                                  .usSize],
                                          decoration: const InputDecoration(
                                            labelText: 'Qty',
                                            isDense: true,
                                            contentPadding: EdgeInsets.all(8),
                                            hintText: '0',
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          validator: (v) {
                                            if (v?.trim().isEmpty ?? true) {
                                              return null;
                                            }
                                            if (int.tryParse(v!.trim()) ==
                                                null) {
                                              return 'Numbers only';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.image),
                  label: Text(
                    _imagePath == null
                        ? AppLocalizations.t('select_image')
                        : '${AppLocalizations.t('image')}: ${_imagePath!.split('/').last}',
                  ),
                ),
                if (_imagePath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_imagePath!),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 48),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(AppLocalizations.t('cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.t('save')),
        ),
      ],
    );
  }
}
