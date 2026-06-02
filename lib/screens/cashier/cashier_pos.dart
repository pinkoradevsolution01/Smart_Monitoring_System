import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/package_service.dart';
import 'dart:io';
import '../../utils/app_localizations.dart';
import '../../widgets/header_clock.dart';
import '../../services/pos_service.dart';
import '../../services/user_service.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import 'package:smart_monitoring_system/screens/owner/cctv_screen.dart';
import 'widgets/cart_sheet.dart';

class CashierPOS extends StatefulWidget {
  final String cashierName;

  const CashierPOS({super.key, required this.cashierName});

  @override
  State<CashierPOS> createState() => _CashierPOSState();
}

class _CashierPOSState extends State<CashierPOS> {
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
      builder: (context) => CartSheet(
        pos: pos,
        cashierName: widget.cashierName,
        initialPaymentMethod: _selectedPaymentMethod,
      ),
    );
  }

  Future<void> _verifyOwnerPassword(DateTime timestamp) async {
    final passwordController = TextEditingController();
    final userService = GetIt.I<UserService>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('owner_verification')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.t('enter_owner_password'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('password'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
              ),
              onSubmitted: (_) async {
                final password = passwordController.text.trim();
                final nav = Navigator.of(context);
                if (password.isEmpty) {
                  nav.pop(false);
                  return;
                }

                final owners = userService.getUsersWithOwnerPrivileges();
                final isValid = owners.any(
                  (owner) => owner.isActive && owner.password == password,
                );

                if (!mounted) return;
                nav.pop(isValid);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              final nav = Navigator.of(context);
              if (password.isEmpty) {
                nav.pop(false);
                return;
              }

              final owners = userService.getUsersWithOwnerPrivileges();
              final isValid = owners.any(
                (owner) => owner.isActive && owner.password == password,
              );

              if (!mounted) return;
              nav.pop(isValid);
            },
            child: Text(AppLocalizations.t('verify')),
          ),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CCTVScreen(timestamp: timestamp)),
      );
    } else if (result == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('invalid_owner_password')),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  void openSalesLog() async {
    await pos.loadRecentSales(days: 30);
    if (!mounted) return;
    final sales = pos.recentSales;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.t('sales_log_title')),
        content: SizedBox(
          width: double.maxFinite,
          child: sales.isEmpty
              ? Text(AppLocalizations.t('no_sales_yet'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: sales.length,
                  itemBuilder: (context, idx) {
                    final s = sales[idx];
                    final isCancelled = s.status == SaleStatus.cancelled;
                    return ExpansionTile(
                      title: Row(
                        children: [
                          Text(
                            isCancelled
                                ? 'Sale ${s.saleNumber} - Cancelled'
                                : 'Sale ${s.saleNumber}',
                            style: TextStyle(
                              color: isCancelled ? Colors.red : null,
                              fontWeight: isCancelled ? FontWeight.bold : null,
                            ),
                          ),
                          if (isCancelled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppLocalizations.t('cancelled'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.formattedDate),
                          Text(
                            'Payment: ${s.paymentMethod.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (s.referenceCode != null &&
                              s.referenceCode!.isNotEmpty)
                            Text(
                              'Ref: ${s.referenceCode}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (isCancelled && s.cancelledReason != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${s.cancelledReason}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${s.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              decoration: isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCancelled ? Colors.grey : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isCancelled)
                            IconButton(
                              tooltip: AppLocalizations.t('cancel_sale'),
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _showCancelSaleDialog(s),
                            ),
                          IconButton(
                            tooltip: AppLocalizations.t('monitor_cctv'),
                            icon: const Icon(Icons.videocam),
                            onPressed: () {
                              final pkg = GetIt.I<PackageService>();
                              if (!pkg.hasCCTVAccess) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Feature Locked'),
                                    content: const Text(
                                      'This feature is only available in the Premium package and above.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(
                                          AppLocalizations.t('close'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              _verifyOwnerPassword(s.saleDate);
                            },
                          ),
                        ],
                      ),
                      children: s.items.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('No item details'),
                              ),
                            ]
                          : s.items.map((item) {
                              return ListTile(
                                title: Row(
                                  children: [
                                    Expanded(child: Text(item.productName)),
                                    if (item.shoeSize != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Size ${item.shoeSize}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${item.quantity} x ₱${item.unitPrice.toStringAsFixed(2)}',
                                ),
                                trailing: Text(
                                  '₱${item.subtotal.toStringAsFixed(2)}',
                                ),
                              );
                            }).toList(),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelSaleDialog(Sale sale) async {
    final passwordController = TextEditingController();
    final reasonController = TextEditingController();
    final userService = GetIt.I<UserService>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('cancel_sale')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppLocalizations.t('sale_label').replaceAll('{id}', '')} ${sale.saleNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.t('total_prefix')}${sale.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.t('owner_verification'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('password'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.t('cancellation_reason'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('reason'),
                  border: const OutlineInputBorder(),
                  hintText: AppLocalizations.t('enter_cancellation_reason'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final password = passwordController.text.trim();
              final reason = reasonController.text.trim();

              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.t('enter_owner_password')),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.t('enter_cancellation_reason'),
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Verify owner password
              final owners = userService.getUsersWithOwnerPrivileges();
              final owner = owners.firstWhere(
                (o) => o.isActive && o.password == password,
                orElse: () => throw Exception('Invalid password'),
              );

              try {
                // Cancel the sale
                final success = await pos.cancelSale(
                  saleId: sale.id!,
                  reason: reason,
                  cancelledBy: owner.name,
                );

                if (!mounted) return;
                Navigator.pop(context, success);
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context, false);
              }
            },
            child: Text(AppLocalizations.t('confirm_cancellation')),
          ),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('sale_cancelled_successfully')),
          backgroundColor: Colors.green,
        ),
      );
      // Reload sales log
      await pos.loadRecentSales(days: 30);
      setState(() {});
    } else if (result == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('invalid_owner_password')),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        title: Text(AppLocalizations.t('cashier_pos')),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: const HeaderClock(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppLocalizations.t('sales_log_tooltip'),
            onPressed: openSalesLog,
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: AppLocalizations.t('open_cart_tooltip'),
            onPressed: openCartSheet,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          return Center(
            child: SizedBox(
              width: double.infinity,
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
                  // Products Grid + optional right-side cart panel on wide screens
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: wide
                          ? Row(
                              children: [
                                // Product grid takes remaining space
                                Expanded(
                                  flex: 3,
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
                                                crossAxisCount: 3,
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
                                const SizedBox(width: 12),
                                // Right-side cart / calculator panel
                                Container(
                                  width: 360,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: _buildCartPanel(),
                                ),
                              ],
                            )
                          : (products.isEmpty
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
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width >
                                                  600
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
                                  )),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          // hide floating button when wide layout shows the cart panel
          if (constraints.maxWidth > 900) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: openCartSheet,
            icon: const Icon(Icons.shopping_cart_checkout),
            label: Text(
              AppLocalizations.t(
                'cart_count',
              ).replaceAll('{count}', cartCount.toString()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartPanel() {
    final cart = pos.cart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.calculate, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Selected Order',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: AppLocalizations.t('open_cart_tooltip'),
              onPressed: openCartSheet,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: cart.isEmpty
              ? Center(child: Text(AppLocalizations.t('cart_empty')))
              : ListView.separated(
                  itemCount: cart.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = cart[idx];
                    return ListTile(
                      title: Text(item.product.name),
                      subtitle: Text(
                        '${item.quantity} x ₱${item.product.sellingPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Text('₱${item.subtotal.toStringAsFixed(2)}'),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.t('subtotal'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '₱${pos.cartSubtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: openCartSheet,
          icon: const Icon(Icons.payment),
          label: Text(AppLocalizations.t('open_cart_tooltip')),
        ),
      ],
    );
  }
}
