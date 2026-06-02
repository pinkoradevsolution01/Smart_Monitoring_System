import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/product.dart';
import '../../services/pos_service.dart';
import '../../utils/app_localizations.dart';
import 'dart:io';

class PriceCheckerScreen extends StatefulWidget {
  const PriceCheckerScreen({super.key});

  @override
  State<PriceCheckerScreen> createState() => _PriceCheckerScreenState();
}

class _PriceCheckerScreenState extends State<PriceCheckerScreen> {
  final POSService _posService = GetIt.I.get<POSService>();
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  Product? _scannedProduct;
  bool _isScanning = false;
  bool _showScanner = false;
  List<Product> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _searchProduct(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _scannedProduct = null;
      });
      return;
    }

    final allProducts = _posService.products;
    setState(() {
      _searchResults = allProducts.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) ||
            product.barcode.toLowerCase().contains(query.toLowerCase());
      }).toList();
      _scannedProduct = null;
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    setState(() {
      _isScanning = true;
    });

    // Find product
    final product = _posService.products.firstWhere(
      (p) => p.barcode == code,
      orElse: () => Product(
        id: -1,
        name: 'Product Not Found',
        barcode: code,
        category: '',
        buyingPrice: 0,
        sellingPrice: 0,
        quantity: 0,
        reorderLevel: 0,
        createdAt: DateTime.now(),
      ),
    );

    setState(() {
      _scannedProduct = product;
      _showScanner = false;
      _searchController.text = product.name;
      _searchResults = [];
      _isScanning = false;
    });

    // Play feedback
    if (product.id != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.t('product_found')}: ${product.name}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('product_not_found')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _selectProduct(Product product) {
    setState(() {
      _scannedProduct = product;
      _searchController.text = product.name;
      _searchResults = [];
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _scannedProduct = null;
      _searchResults = [];
      _showScanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('price_checker')),
        actions: [
          if (_scannedProduct != null || _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: AppLocalizations.t('clear'),
              onPressed: _clearSearch,
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
                  // Search Bar Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Search Input with Scan Button
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: _searchProduct,
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.t(
                                    'search_product_name_barcode',
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: primaryColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Scan Barcode Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      _showScanner = !_showScanner;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Icon(
                                      _showScanner
                                          ? Icons.close
                                          : Icons.qr_code_scanner,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Quick Action Chips
                        if (!_showScanner) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _QuickFilterChip(
                                  label: AppLocalizations.t('all_products'),
                                  icon: Icons.inventory,
                                  onTap: () {
                                    setState(() {
                                      _searchResults = _posService.products;
                                      _scannedProduct = null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _QuickFilterChip(
                                  label: AppLocalizations.t('low_stock'),
                                  icon: Icons.warning_amber,
                                  color: Colors.orange,
                                  onTap: () {
                                    setState(() {
                                      _searchResults = _posService.products
                                          .where((p) => p.quantity <= 5)
                                          .toList();
                                      _scannedProduct = null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _QuickFilterChip(
                                  label: AppLocalizations.t('out_of_stock'),
                                  icon: Icons.remove_circle_outline,
                                  color: Colors.red,
                                  onTap: () {
                                    setState(() {
                                      _searchResults = _posService.products
                                          .where((p) => p.quantity == 0)
                                          .toList();
                                      _scannedProduct = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Scanner Section
                  if (_showScanner)
                    Container(
                      height: 300,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          children: [
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _onBarcodeDetected,
                            ),
                            // Scanner Overlay
                            Center(
                              child: Container(
                                width: 250,
                                height: 250,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CustomPaint(
                                  painter: _ScannerCornersPainter(primaryColor),
                                ),
                              ),
                            ),
                            // Scanning Indicator
                            if (_isScanning)
                              Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            // Instructions
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AppLocalizations.t(
                                    'align_barcode_within_frame',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Product Display Section
                  Expanded(
                    child: _scannedProduct != null
                        ? _buildProductDetail(_scannedProduct!, theme)
                        : _searchResults.isNotEmpty
                        ? _buildSearchResults(theme)
                        : _buildEmptyState(theme),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductDetail(Product product, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final isOutOfStock = product.quantity == 0;
    final isLowStock = product.quantity > 0 && product.quantity <= 5;
    final isNotFound = product.id == -1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Product Image Card
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withValues(alpha: 0.1),
                  primaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: product.imagePath != null && product.imagePath!.isNotEmpty
                  ? Image.file(
                      File(product.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholderImage(primaryColor),
                    )
                  : _buildPlaceholderImage(primaryColor),
            ),
          ),

          const SizedBox(height: 24),

          // Product Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isNotFound
                        ? Colors.red
                        : theme.textTheme.bodyLarge?.color,
                  ),
                ),

                const SizedBox(height: 8),

                // Category
                if (!isNotFound && product.category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.category,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                const Divider(),

                const SizedBox(height: 20),

                if (!isNotFound) ...[
                  // Price Display
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.attach_money,
                          color: Colors.green,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.t('selling_price'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₱${product.sellingPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Stock Display
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.red.withValues(alpha: 0.1)
                              : isLowStock
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isOutOfStock
                              ? Icons.remove_shopping_cart
                              : isLowStock
                              ? Icons.warning_amber
                              : Icons.inventory_2,
                          color: isOutOfStock
                              ? Colors.red
                              : isLowStock
                              ? Colors.orange
                              : Colors.blue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.t('stock_quantity'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${product.quantity} ${AppLocalizations.t('units')}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock
                                    ? Colors.red
                                    : isLowStock
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Barcode Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_2, color: Colors.grey[700]),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.t('barcode'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product.barcode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Stock Status Badge
                  if (isOutOfStock || isLowStock) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOutOfStock ? Colors.red : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOutOfStock ? Icons.error : Icons.warning_amber,
                            color: isOutOfStock ? Colors.red : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isOutOfStock
                                  ? AppLocalizations.t('out_of_stock')
                                  : AppLocalizations.t('low_stock_warning'),
                              style: TextStyle(
                                color: isOutOfStock
                                    ? Colors.red
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // Product Not Found Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.t('product_not_found'),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${AppLocalizations.t('barcode')}: ${product.barcode}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        final isOutOfStock = product.quantity == 0;
        final isLowStock = product.quantity > 0 && product.quantity <= 5;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _selectProduct(product),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Product Image
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          product.imagePath != null &&
                              product.imagePath!.isNotEmpty
                          ? Image.file(
                              File(product.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.inventory_2,
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                            )
                          : Icon(
                              Icons.inventory_2,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${product.sellingPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stock Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.red.withValues(alpha: 0.1)
                          : isLowStock
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${product.quantity}',
                      style: TextStyle(
                        color: isOutOfStock
                            ? Colors.red
                            : isLowStock
                            ? Colors.orange
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.t('price_checker_empty_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.t('price_checker_empty_subtitle'),
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Feature Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FeatureIcon(
                  icon: Icons.qr_code_scanner,
                  label: AppLocalizations.t('scan'),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 24),
                _FeatureIcon(
                  icon: Icons.search,
                  label: AppLocalizations.t('search'),
                  color: Colors.blue,
                ),
                const SizedBox(width: 24),
                _FeatureIcon(
                  icon: Icons.info_outline,
                  label: AppLocalizations.t('view_details'),
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(Color primaryColor) {
    return Center(
      child: Icon(
        Icons.inventory_2,
        size: 100,
        color: primaryColor.withValues(alpha: 0.3),
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: chipColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: chipColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureIcon({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ScannerCornersPainter extends CustomPainter {
  final Color color;

  _ScannerCornersPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLength = 30.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
