// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'dart:io';
import '../../services/pos_service.dart';
import '../../services/database_service.dart';
import '../../services/user_service.dart';
import '../../services/package_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/receipt_generator.dart';
import '../../models/product.dart';
import '../../models/shoe_size.dart';
import '../../models/damage_report.dart';
import '../../models/inventory_movement.dart';
import '../../models/user.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../owner/supplier_management_screen.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';
import 'package:smart_monitoring_system/widgets/app_design_system.dart';

enum InventoryFilter { all, lowStock, outOfStock, inStock }

class InventoryScreen extends StatefulWidget {
  final User? user;
  const InventoryScreen({super.key, this.user});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final POSService pos = GetIt.I<POSService>();
  final DatabaseService db = DatabaseService();
  final PackageService _packageService = GetIt.I<PackageService>();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _query = '';
  String _selectedCategory = 'All';
  InventoryFilter _filter = InventoryFilter.all;
  List<DamageReport> _damageReports = [];
  bool _loadingDamageReports = false;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    pos.addListener(_onPosChanged);
    _loadProducts();
    _loadDamageReports();
  }

  Future<void> _loadProducts() async {
    if (mounted) setState(() => _loadingProducts = true);
    await pos.loadProducts();
    if (mounted) setState(() => _loadingProducts = false);
  }

  void _onPosChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDamageReports() async {
    setState(() => _loadingDamageReports = true);
    try {
      final reports = await db.getAllDamageReports();
      if (mounted) {
        setState(() {
          _damageReports = reports;
          _loadingDamageReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDamageReports = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    pos.removeListener(_onPosChanged);
    super.dispose();
  }

  List<Product> _getFilteredProducts() {
    var products = pos.products;

    // Apply search filter
    if (_query.isNotEmpty) {
      products = products
          .where(
            (p) =>
                p.name.toLowerCase().contains(_query.toLowerCase()) ||
                p.barcode.toLowerCase().contains(_query.toLowerCase()),
          )
          .toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      products = products
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    // Apply stock filter
    switch (_filter) {
      case InventoryFilter.lowStock:
        products = products.where((p) => p.lowStock && p.quantity > 0).toList();
        break;
      case InventoryFilter.outOfStock:
        products = products.where((p) => p.quantity == 0).toList();
        break;
      case InventoryFilter.inStock:
        products = products.where((p) => p.quantity > p.reorderLevel).toList();
        break;
      case InventoryFilter.all:
        break;
    }

    return products;
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      ...pos.products.map((p) => p.category).toSet().toList()..sort(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('inventory_status')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: const HeaderClock(),
          ),
          IconButton(
            tooltip: 'Reset shoe sizes',
            icon: const Icon(Icons.restore),
            onPressed: () async {
              final confirm = await showAppDestructiveConfirmation(
                context,
                title: 'Reset shoe sizes?',
                message:
                    'This will set every shoe-size quantity to 0. You cannot undo this from this screen.',
                confirmLabel: 'Reset sizes',
              );

              if (confirm == true) {
                // perform reset
                final products = List<Product>.from(pos.products);
                for (final p in products) {
                  if (p.hasShoeVariants) {
                    final zeroed = p.copyWith(
                      shoeSizes: p.shoeSizes!
                          .map((s) => s.copyWith(quantity: 0))
                          .toList(),
                    );
                    await pos.updateProduct(zeroed);
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shoe sizes reset to 0')),
                );
              }
            },
          ),
        ],
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2),
              text: AppLocalizations.t('inventory_levels'),
            ),
            Tab(
              icon: const Icon(Icons.local_shipping),
              text: AppLocalizations.t('restock_delivery'),
            ),
            Tab(
              icon: const Icon(Icons.attach_money),
              text: AppLocalizations.t('adjust_pricing'),
            ),
            Tab(
              icon: const Icon(Icons.report_problem),
              text: AppLocalizations.t('damage_reports'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInventoryLevelsTab(categories),
          _buildRestockTab(),
          _buildPricingTab(),
          _buildDamageReportsTab(),
        ],
      ),
    );
  }

  Widget _buildInventoryLevelsTab(List<String> categories) {
    final filtered = _getFilteredProducts();
    final totalValue = filtered.fold<double>(
      0,
      (sum, p) => sum + (p.sellingPrice * p.quantity),
    );

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.t('search_products'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            children: [
              // Category filter
              Row(
                children: [
                  const Icon(Icons.category, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${AppLocalizations.t('category')}: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      items: categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value ?? 'All');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Stock filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(AppLocalizations.t('all_items')),
                      selected: _filter == InventoryFilter.all,
                      onSelected: (selected) {
                        setState(() => _filter = InventoryFilter.all);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.warning_amber, size: 18),
                      label: Text(AppLocalizations.t('low_stock_only')),
                      selected: _filter == InventoryFilter.lowStock,
                      onSelected: (selected) {
                        setState(() => _filter = InventoryFilter.lowStock);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.remove_circle, size: 18),
                      label: Text(AppLocalizations.t('out_of_stock')),
                      selected: _filter == InventoryFilter.outOfStock,
                      onSelected: (selected) {
                        setState(() => _filter = InventoryFilter.outOfStock);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.check_circle, size: 18),
                      label: Text(AppLocalizations.t('in_stock')),
                      selected: _filter == InventoryFilter.inStock,
                      onSelected: (selected) {
                        setState(() => _filter = InventoryFilter.inStock);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Summary bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.t(
                  'items_found',
                ).replaceAll('{count}', '${filtered.length}'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                '${AppLocalizations.t('total_value')}: ${AppCurrency.peso(totalValue)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),

        // Product list
        Expanded(
          child: _loadingProducts
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppLoadingSkeleton(lines: 5),
                )
              : filtered.isEmpty
              ? AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products found',
                  message: _query.isEmpty
                      ? 'Add products to begin monitoring stock levels.'
                      : 'Try a different product name, barcode, or filter.',
                  onRetry: _loadProducts,
                )
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return _buildProductCard(p);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final isLow = product.lowStock;
    final isOut = product.quantity == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isOut
          ? Colors.red.shade50
          : isLow
          ? Colors.orange.shade50
          : null,
      child: ListTile(
        leading: product.imagePath != null && product.imagePath!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(product.imagePath!),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    isOut
                        ? Icons.remove_circle
                        : isLow
                        ? Icons.warning_amber
                        : Icons.check_circle,
                    color: isOut
                        ? Colors.red
                        : isLow
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              )
            : Icon(
                isOut
                    ? Icons.remove_circle
                    : isLow
                    ? Icons.warning_amber
                    : Icons.check_circle,
                color: isOut
                    ? Colors.red
                    : isLow
                    ? Colors.orange
                    : Colors.green,
                size: 40,
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            if (isOut)
              AppStatusBadge(
                label: AppLocalizations.t('out_of_stock').toUpperCase(),
                status: AppStatus.danger,
              )
            else if (isLow)
              AppStatusBadge(
                label: AppLocalizations.t('low_stock_alert'),
                status: AppStatus.warning,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.t('barcode')}: ${product.barcode}',
              style: const TextStyle(color: Colors.black),
            ),
            Text(
              '${AppLocalizations.t('category')}: ${product.category}',
              style: const TextStyle(color: Colors.black),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.t('stock')}: ${product.hasShoeVariants ? product.totalQuantity : product.quantity}',
                  style: TextStyle(
                    color: isOut
                        ? Colors.red
                        : isLow
                        ? Colors.orange
                        : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(AppCurrency.peso(product.sellingPrice)),
              ],
            ),
            if (product.hasShoeVariants)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  AppLocalizations.t('tap_to_view_sizes'),
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showProductDetails(product),
      ),
    );
  }

  Widget _buildRestockTab() {
    final filtered = _getFilteredProducts();
    final needRestock = filtered
        .where((p) => p.lowStock || p.quantity == 0)
        .toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.t('search_products'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        if (needRestock.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${needRestock.length} ${AppLocalizations.t('low_stock_items').replaceAll('({count})', '')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(AppLocalizations.t('no_products')))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          p.quantity == 0
                              ? Icons.remove_circle
                              : p.lowStock
                              ? Icons.warning_amber
                              : Icons.inventory_2,
                          color: p.quantity == 0
                              ? Colors.red
                              : p.lowStock
                              ? Colors.orange
                              : Colors.blue,
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(color: Colors.black),
                        ),
                        subtitle: Text(
                          '${AppLocalizations.t('stock')}: ${p.quantity} | ${AppLocalizations.t('reorder_level')}: ${p.reorderLevel}',
                          style: const TextStyle(color: Colors.black),
                        ),
                        trailing: _packageService.hasSupplierManagementAccess
                            ? IconButton(
                                icon: const Icon(Icons.shopping_cart, size: 24),
                                onPressed: () => _navigateToCreateOrder(p),
                                tooltip: AppLocalizations.t(
                                  'order_from_supplier',
                                ),
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : IconButton(
                                icon: const Icon(Icons.add_box, size: 24),
                                onPressed: () => _showSimpleRestockDialog(p),
                                tooltip: 'Restock',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPricingTab() {
    final filtered = _getFilteredProducts();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.t('search_products'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(AppLocalizations.t('no_products')))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    final profit = p.sellingPrice - p.buyingPrice;
                    final margin = p.buyingPrice > 0
                        ? ((profit / p.buyingPrice) * 100)
                        : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.attach_money, size: 40),
                        title: Text(p.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppLocalizations.t('buying_price')}: ${AppCurrency.peso(p.buyingPrice)}',
                            ),
                            Text(
                              '${AppLocalizations.t('selling_price')}: ${AppCurrency.peso(p.sellingPrice)}',
                            ),
                            Text(
                              '${AppLocalizations.t('profit_margin')}: ${AppCurrency.peso(profit)} (${margin.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                color: profit > 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showPriceAdjustDialog(p),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Divider(),
                  _detailRow(AppLocalizations.t('barcode'), product.barcode),
                  _detailRow(AppLocalizations.t('category'), product.category),
                  _detailRow(
                    AppLocalizations.t('stock'),
                    '${product.hasShoeVariants ? product.totalQuantity : product.quantity}',
                  ),
                  _detailRow(
                    AppLocalizations.t('reorder_level'),
                    '${product.reorderLevel}',
                  ),
                  _detailRow(
                    AppLocalizations.t('buying_price'),
                    AppCurrency.peso(product.buyingPrice),
                  ),
                  _detailRow(
                    AppLocalizations.t('selling_price'),
                    AppCurrency.peso(product.sellingPrice),
                  ),
                  _detailRow(
                    AppLocalizations.t('profit'),
                    AppCurrency.peso(product.profit),
                  ),

                  // Show shoe sizes if applicable
                  if (product.hasShoeVariants) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    Text(
                      AppLocalizations.t('shoe_sizes_available'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: product.shoeSizes!.map((size) {
                          final childRow = Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'US: ${size.usSize} | UK: ${size.ukSize} | EU: ${size.euSize} | CM: ${size.cmSize}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: size.quantity > 0
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${size.quantity}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          // For Basic package (no supplier management), make size rows clickable
                          if (!_packageService.hasSupplierManagementAccess) {
                            return InkWell(
                              onTap: () =>
                                  _showRestockSizeDialog(product, size),
                              child: childRow,
                            );
                          }

                          return childRow;
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _packageService.hasSupplierManagementAccess
                            ? ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _navigateToCreateOrder(product);
                                },
                                icon: const Icon(Icons.shopping_cart),
                                label: Text(
                                  AppLocalizations.t('order_from_supplier'),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showSimpleRestockDialog(product);
                                },
                                icon: const Icon(Icons.add_box),
                                label: const Text('Restock'),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showPriceAdjustDialog(product);
                          },
                          icon: const Icon(Icons.edit),
                          label: Text(AppLocalizations.t('adjust_price')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDamageDialog(product);
                      },
                      icon: const Icon(Icons.broken_image, color: Colors.red),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppLocalizations.t('damage_item'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _showPriceAdjustDialog(Product product) {
    final buyingPriceController = TextEditingController(
      text: product.buyingPrice.toString(),
    );
    final sellingPriceController = TextEditingController(
      text: product.sellingPrice.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final buying = double.tryParse(buyingPriceController.text) ?? 0;
          final selling = double.tryParse(sellingPriceController.text) ?? 0;
          final profit = selling - buying;
          final margin = buying > 0 ? ((profit / buying) * 100) : 0.0;

          return AlertDialog(
            title: Text(AppLocalizations.t('adjust_price')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: buyingPriceController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('new_buying_price'),
                      prefixText: '₱',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sellingPriceController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('new_selling_price'),
                      prefixText: '₱',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: profit > 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.t('profit_margin'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppCurrency.peso(profit)} (${margin.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: profit > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (buying > 0 && selling > 0) {
                    final updated = product.copyWith(
                      buyingPrice: buying,
                      sellingPrice: selling,
                    );
                    await pos.updateProduct(updated);

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.t('price_updated')),
                        ),
                      );
                    }
                  }
                },
                child: Text(AppLocalizations.t('update_prices')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSimpleRestockDialog(Product product) {
    // If product has shoe variants, show a size-select restock dialog (hardcoded for shoe sizes)
    if (product.hasShoeVariants) {
      final qtyController = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            ShoeSize? selected = product.shoeSizes!.first;
            final Map<String, int> pendingAdds = {};

            void addPending() {
              final qty = int.tryParse(qtyController.text);
              if (qty == null || qty <= 0 || selected == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final key = selected!.usSize;
              pendingAdds[key] = (pendingAdds[key] ?? 0) + qty;
              qtyController.clear();
              setState(() {});
            }

            Future<void> applyAll() async {
              if (pendingAdds.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('No pending restocks to apply')),
                );
                return;
              }

              final previousTotal = product.totalQuantity;
              final updatedSizes = product.shoeSizes!.map((s) {
                final add = pendingAdds[s.usSize] ?? 0;
                return s.copyWith(quantity: s.quantity + add);
              }).toList();

              final updatedProduct = product.copyWith(shoeSizes: updatedSizes);
              await pos.updateProduct(updatedProduct);

              // Record individual inventory movements per size
              for (final entry in pendingAdds.entries) {
                final us = entry.key;
                final add = entry.value;
                await db.recordInventoryMovement(
                  InventoryMovement(
                    productId: product.id!,
                    quantityBefore: previousTotal,
                    quantityAfter: updatedProduct.totalQuantity,
                    quantityChanged: add,
                    movementType: 'restock',
                    reference:
                        'Manual-batch-${DateTime.now().millisecondsSinceEpoch}',
                    reason: 'Manual restock - size US $us',
                    movementDate: DateTime.now(),
                  ),
                );
              }

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Applied restock for ${pendingAdds.length} size(s)',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.add_box, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text('Restock Shoe Sizes'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<ShoeSize>(
                    value: selected,
                    items: product.shoeSizes!
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              'US ${s.usSize} | ${s.quantity + (pendingAdds[s.usSize] ?? 0)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      selected = v;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity to Add',
                      hintText: 'Enter quantity received',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  if (pendingAdds.isNotEmpty) ...[
                    const Divider(),
                    const Text('Pending additions:'),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        children: pendingAdds.entries
                            .map((e) => Text('US ${e.key}: +${e.value}'))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.t('cancel')),
                ),
                TextButton(
                  onPressed: () => addPending(),
                  child: const Text('Add'),
                ), // keeps dialog open
                ElevatedButton(
                  onPressed: () => applyAll(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        ),
      );
      return;
    }

    // Fallback: non-shoe simple restock (existing behavior)
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_box, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Restock Product'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Current Stock: ${product.quantity}',
              style: TextStyle(
                color: product.lowStock ? Colors.red : Colors.grey,
                fontWeight: product.lowStock
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                hintText: 'Enter quantity received',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Simple stock addition for delivery received',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final qty = int.tryParse(quantityController.text);
              if (qty != null && qty > 0) {
                final updated = product.copyWith(
                  quantity: product.quantity + qty,
                );
                await pos.updateProduct(updated);

                // Record inventory movement
                await db.recordInventoryMovement(
                  InventoryMovement(
                    productId: product.id!,
                    quantityBefore: product.quantity,
                    quantityAfter: product.quantity + qty,
                    quantityChanged: qty,
                    movementType: 'restock',
                    reference:
                        'Manual-${DateTime.now().millisecondsSinceEpoch}',
                    reason: 'Manual restock - delivery received',
                    movementDate: DateTime.now(),
                  ),
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Added $qty units. New stock: ${product.quantity + qty}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  void _showRestockSizeDialog(Product product, ShoeSize size) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_box, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Restock Size'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${product.name} - US ${size.usSize}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Current Size Stock: ${size.quantity}',
              style: TextStyle(
                color: size.quantity <= product.reorderLevel
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                hintText: 'Enter quantity received',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final qty = int.tryParse(quantityController.text);
              if (qty != null && qty > 0) {
                // Prepare updated shoe sizes list
                final previousTotal = product.totalQuantity;
                final updatedSizes = product.shoeSizes!.map((s) {
                  if (s.usSize == size.usSize &&
                      s.ukSize == size.ukSize &&
                      s.euSize == size.euSize) {
                    return s.copyWith(quantity: s.quantity + qty);
                  }
                  return s;
                }).toList();

                final updatedProduct = product.copyWith(
                  shoeSizes: updatedSizes,
                );
                await pos.updateProduct(updatedProduct);

                // Record inventory movement at product-level (include size info in reason)
                await db.recordInventoryMovement(
                  InventoryMovement(
                    productId: product.id!,
                    quantityBefore: previousTotal,
                    quantityAfter: updatedProduct.totalQuantity,
                    quantityChanged: qty,
                    movementType: 'restock',
                    reference:
                        'Manual-size-${DateTime.now().millisecondsSinceEpoch}',
                    reason: 'Manual restock - size US ${size.usSize}',
                    movementDate: DateTime.now(),
                  ),
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Added $qty units to size US ${size.usSize}. New size stock: ${size.quantity + qty}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  void _showDamageDialog(Product product) {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.broken_image, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.t('damage_item')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.t('stock')}: ${product.quantity}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('quantity_damaged'),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.warning, color: Colors.orange),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('damage_reason'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will reduce stock and total inventory value',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final qty = int.tryParse(quantityController.text);
              final reason = reasonController.text.trim();

              if (qty != null && qty > 0) {
                if (qty > product.quantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Quantity exceeds available stock (${product.quantity})',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Create damage report
                final damageReport = DamageReport(
                  productId: product.id!,
                  productName: product.name,
                  quantity: qty,
                  unitPrice: product.sellingPrice,
                  totalValue: qty * product.sellingPrice,
                  reason: reason.isEmpty ? 'No reason provided' : reason,
                  reportedBy: widget.user?.name ?? 'Unknown',
                  reportDate: DateTime.now(),
                );

                // Save damage report to database
                await db.insertDamageReport(damageReport);

                final updated = product.copyWith(
                  quantity: product.quantity - qty,
                );
                await pos.updateProduct(updated);

                // Reload damage reports
                await _loadDamageReports();

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${AppLocalizations.t('damage_recorded')}: $qty ${product.name}${reason.isNotEmpty ? ' - $reason' : ''}',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(AppLocalizations.t('record_damage')),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageReportsTab() {
    // Calculate total value lost (only pending damages)
    final totalDamageValue = _damageReports
        .where((r) => r.paymentStatus == null && r.returnStatus == null)
        .fold<double>(0, (sum, report) => sum + report.totalValue);

    // Calculate total damaged items (only pending damages)
    final totalDamagedItems = _damageReports
        .where((r) => r.paymentStatus == null && r.returnStatus == null)
        .fold<int>(0, (sum, report) => sum + report.quantity);

    return Column(
      children: [
        // Summary Card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.t('total_damaged_items'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalDamagedItems',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppLocalizations.t('total_value_lost'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppCurrency.php(totalDamageValue),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Damage Reports List
        Expanded(
          child: _loadingDamageReports
              ? const Center(child: CircularProgressIndicator())
              : _damageReports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.t('no_damage_reports'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDamageReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _damageReports.length,
                    itemBuilder: (context, index) {
                      final report = _damageReports[index];
                      final bool isReturned = report.returnStatus == 'returned';
                      final bool isPaid = report.paymentStatus == 'paid';
                      final bool isStoreDamage =
                          report.returnStatus == null &&
                          report.paymentStatus == null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPaid
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : isReturned
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.shade100,
                                child: Icon(
                                  isPaid
                                      ? Icons.payment
                                      : isReturned
                                      ? Icons.check_circle
                                      : Icons.broken_image,
                                  color: isPaid
                                      ? Colors.blue
                                      : isReturned
                                      ? Colors.green
                                      : Colors.red.shade700,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      report.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isPaid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        AppLocalizations.t('store_damage_paid'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (isReturned)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        AppLocalizations.t('returned'),
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
                                  const SizedBox(height: 4),
                                  Text(
                                    '${AppLocalizations.t('quantity')}: ${report.quantity}',
                                  ),
                                  Text(
                                    '${AppLocalizations.t('value')}: ${AppCurrency.php(report.totalValue)}',
                                  ),
                                  if (report.reason.isNotEmpty)
                                    Text(
                                      '${AppLocalizations.t('reason')}: ${report.reason}',
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  Text(
                                    '${AppLocalizations.t('reported_by')}: ${report.reportedBy}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isReturned && report.returnDate != null)
                                    Text(
                                      '${AppLocalizations.t('return_date')}: ${_formatDate(report.returnDate!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (isPaid && report.paymentDate != null)
                                    Text(
                                      '${AppLocalizations.t('payment_date')}: ${_formatDate(report.paymentDate!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (isPaid &&
                                      report.responsiblePerson != null)
                                    Text(
                                      '${AppLocalizations.t('responsible_person')}: ${report.responsiblePerson}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatDate(report.reportDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Add "Proceed to Payment" button for store damage (owner or manager on premium)
                            if (isStoreDamage &&
                                widget.user != null &&
                                UserService().hasOwnerPrivileges(widget.user!))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _showPaymentResponsibilityDialog(
                                          report,
                                        ),
                                    icon: const Icon(Icons.payment),
                                    label: Text(
                                      AppLocalizations.t('proceed_to_payment'),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _navigateToCreateOrder(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierManagementScreen(
          initialTab: 2, // Purchase Orders tab
          autoCreateOrder: true,
          preselectedProduct: product,
        ),
      ),
    );

    // Reload products if order was created
    if (result == true && mounted) {
      pos.loadProducts();
    }
  }

  /// Show dialog to select responsible person for payment
  void _showPaymentResponsibilityDialog(DamageReport report) async {
    final userService = UserService();
    final users = userService.activeUsers;

    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('no_users_found')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? selectedUserId;
    String? selectedUserName;
    bool isAllStaff = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payment, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.t('payment_responsibility'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppLocalizations.t('quantity')}: ${report.quantity}',
                      ),
                      Text(
                        '${AppLocalizations.t('total_value')}: ${AppCurrency.php(report.totalValue)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.t('assign_payment_to'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // List of users
                ...users.map((user) {
                  final bool isSelected =
                      selectedUserId == user.id && !isAllStaff;
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedUserId = user.id;
                        selectedUserName = user.name;
                        isAllStaff = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  user.role == UserRole.owner
                                      ? AppLocalizations.t('owner')
                                      : user.role == UserRole.manager
                                      ? AppLocalizations.t('manager')
                                      : AppLocalizations.t('cashier'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(),
                // All Staff option
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      isAllStaff = true;
                      selectedUserId = null;
                      selectedUserName = AppLocalizations.t('all_staff');
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isAllStaff
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAllStaff
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isAllStaff
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t('all_staff'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                AppLocalizations.t('shared_responsibility'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: (selectedUserId != null || isAllStaff)
                  ? () async {
                      Navigator.pop(ctx);
                      await _processPayment(
                        report,
                        selectedUserName!,
                        isAllStaff ? null : selectedUserId,
                      );
                    }
                  : null,
              icon: const Icon(Icons.payment),
              label: Text(AppLocalizations.t('proceed_to_payment')),
            ),
          ],
        ),
      ),
    );
  }

  /// Process payment for damage report
  Future<void> _processPayment(
    DamageReport report,
    String responsiblePerson,
    String? responsibleUserId,
  ) async {
    try {
      // Update damage report with payment info
      await db.updateDamageReportPayment(
        reportId: report.id!,
        responsiblePerson: responsiblePerson,
        responsibleUserId: responsibleUserId,
      );

      // Generate sale number
      final saleNumber = 'SD-${DateTime.now().millisecondsSinceEpoch}';

      // Create a sale record for the damage payment
      final sale = Sale(
        saleNumber: saleNumber,
        items: [
          SaleItem(
            saleId: 0, // Will be set by database
            productId: report.productId,
            productName: report.productName,
            quantity: report.quantity,
            unitPrice: report.unitPrice,
            discount: 0,
            subtotal: report.totalValue,
          ),
        ],
        subtotal: report.totalValue,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: report.totalValue,
        paymentMethod: 'Store Damage Payment',
        status: SaleStatus.completed,
        notes:
            'Store Damage Payment - Responsible: $responsiblePerson${report.reason.isNotEmpty ? ' | Reason: ${report.reason}' : ''}',
        cashierName: widget.user?.name ?? 'Owner',
        saleDate: DateTime.now(),
      );

      // Save sale to database
      final saleId = await db.insertSale(sale);
      debugPrint('✅ Store damage payment recorded as sale #$saleId');

      // Show receipt dialog
      await _showDamagePaymentReceipt(sale, responsiblePerson);

      // Reload damage reports
      await _loadDamageReports();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('payment_processed')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error processing payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.t('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show receipt for damage payment
  Future<void> _showDamagePaymentReceipt(
    Sale sale,
    String responsiblePerson,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.receipt_long,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Store Damage Payment Receipt',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        AppLocalizations.t('receipt_header'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    _receiptRow(
                      '${AppLocalizations.t('receipt_number')}:',
                      sale.saleNumber,
                    ),
                    _receiptRow(
                      '${AppLocalizations.t('date')}:',
                      _formatDate(sale.saleDate),
                    ),
                    _receiptRow(
                      '${AppLocalizations.t('processed_by')}:',
                      sale.cashierName,
                    ),
                    const Divider(height: 20),
                    const Text(
                      'STORE DAMAGE PAYMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _receiptRow(
                      '${AppLocalizations.t('product')}:',
                      sale.items.first.productName,
                    ),
                    _receiptRow(
                      '${AppLocalizations.t('quantity')}:',
                      '${sale.items.first.quantity}',
                    ),
                    _receiptRow(
                      '${AppLocalizations.t('unit_price')}:',
                      AppCurrency.php(sale.items.first.unitPrice),
                    ),
                    const Divider(height: 20),
                    _receiptRow(
                      '${AppLocalizations.t('responsible_person')}:',
                      responsiblePerson,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL AMOUNT:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          AppCurrency.php(sale.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                      const Divider(height: 20),
                      Text(
                        '${AppLocalizations.t('notes')}:',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This payment has been recorded in sales reports.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('close')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await ReceiptGenerator.generateAndPrint(
                  context: context,
                  pos: pos,
                  cashierName: sale.cashierName,
                );
              } catch (e) {
                debugPrint('Error printing receipt: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Print error: $e'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.print),
            label: Text(AppLocalizations.t('print_receipt')),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
