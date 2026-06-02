import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'dart:io';
import 'delivery_pos.dart';
import '../../models/user.dart';
import '../../models/sale.dart';
import '../../services/pos_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/receipt_generator.dart';

class ForDeliveryScreen extends StatefulWidget {
  final User user;

  const ForDeliveryScreen({super.key, required this.user});

  @override
  State<ForDeliveryScreen> createState() => _ForDeliveryScreenState();
}

class _ForDeliveryScreenState extends State<ForDeliveryScreen> {
  final POSService _posService = GetIt.I.get<POSService>();
  String _selectedFilter = 'all'; // 'all', 'pending', 'completed'
  final TextEditingController _searchController = TextEditingController();
  List<Sale> _deliverySales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliverySales();
  }

  Future<void> _loadDeliverySales() async {
    setState(() => _isLoading = true);
    try {
      List<Sale> sales;
      if (_selectedFilter == 'pending') {
        sales = await _posService.databaseService.getDeliverySalesByStatus(
          status: SaleStatus.pending,
        );
      } else if (_selectedFilter == 'completed') {
        sales = await _posService.databaseService.getDeliverySalesByStatus(
          status: SaleStatus.completed,
        );
      } else {
        sales = await _posService.databaseService.getDeliverySalesByStatus();
      }
      setState(() {
        _deliverySales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading deliveries: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_shipping, size: 24),
            const SizedBox(width: 8),
            const Text('For Delivery'),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.bookmark_add,
                        color: Colors.orange,
                        title: AppLocalizations.t('pending_payment'),
                        count: _deliverySales
                            .where((s) => s.status == SaleStatus.pending)
                            .length
                            .toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle,
                        color: Colors.green,
                        title: AppLocalizations.t('payment_completed'),
                        count: _deliverySales
                            .where((s) => s.status == SaleStatus.completed)
                            .length
                            .toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_shipping,
                        color: Colors.blue,
                        title: 'Total',
                        count: _deliverySales.length.toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search and Filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search by order ID, customer, or product...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      initialValue: _selectedFilter,
                      icon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.filter_list,
                          color: Colors.white,
                        ),
                      ),
                      onSelected: (value) {
                        setState(() => _selectedFilter = value);
                        _loadDeliverySales();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'all',
                          child: Text('All Deliveries'),
                        ),
                        PopupMenuItem(
                          value: 'pending',
                          child: Text(AppLocalizations.t('pending_payment')),
                        ),
                        PopupMenuItem(
                          value: 'completed',
                          child: Text(AppLocalizations.t('payment_completed')),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Deliveries List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _deliverySales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No delivery orders found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDeliverySales,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _deliverySales.length,
                      itemBuilder: (context, index) {
                        final sale = _deliverySales[index];
                        return _DeliveryCard(
                          sale: sale,
                          onTap: () => _showDeliveryDetailDialog(sale),
                          onFullPay: () => _showFullPayDialog(sale),
                          onRefresh: _loadDeliverySales,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryPOS(operatorName: widget.user.name),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Delivery'),
      ),
    );
  }

  Future<void> _showDeliveryDetailDialog(Sale sale) async {
    final isCancelled = sale.status == SaleStatus.cancelled;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text('Order #${sale.saleNumber}')),
            if (!isCancelled)
              IconButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await ReceiptGenerator.generateAndPrint(
                    context: context,
                    pos: _posService,
                    cashierName: widget.user.name,
                  );
                },
                icon: const Icon(Icons.print, color: Colors.blue),
                tooltip: 'Print Receipt',
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red
                        : (sale.status == SaleStatus.pending
                              ? Colors.orange
                              : Colors.green),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCancelled
                        ? AppLocalizations.t('cancelled')
                        : (sale.status == SaleStatus.pending
                              ? AppLocalizations.t('pending_payment')
                              : AppLocalizations.t('payment_completed')),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Customer Info
                if (sale.notes != null) ...[
                  const Text(
                    'Delivery Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      sale.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Courier and Delivery Status
                if (sale.courier != null || sale.deliveryStatus != null) ...[
                  Row(
                    children: [
                      if (sale.courier != null) ...[
                        const Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sale.courier!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (sale.deliveryStatus != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getDeliveryStatusColor(
                              sale.deliveryStatus!,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getDeliveryStatusColor(
                                sale.deliveryStatus!,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _getDeliveryStatusLabel(sale.deliveryStatus!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getDeliveryStatusColor(
                                sale.deliveryStatus!,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Items List
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...sale.items.map((item) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.productName),
                    subtitle: Text(
                      '${item.quantity} x ₱${item.unitPrice.toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      '₱${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
                // Show uploaded receipt/receipt image if present
                if (sale.imagePath != null && sale.imagePath!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Receipt Image',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Receipt Image')),
                            body: Center(
                              child: Image.file(File(sale.imagePath!)),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Image.file(
                        File(sale.imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const Divider(),

                // Payment Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:', style: TextStyle(fontSize: 14)),
                    Text(
                      '₱${sale.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (sale.discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount:', style: TextStyle(fontSize: 14)),
                      Text(
                        '-₱${sale.discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    ],
                  ),
                ],
                if (sale.reservationFee != null &&
                    sale.status == SaleStatus.pending) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.t('reservation_fee'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        '₱${sale.reservationFee!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.t('remaining_balance'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱${(sale.totalAmount - sale.reservationFee!).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₱${sale.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Payment: ${sale.paymentMethod}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  'Date: ${sale.formattedDate}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (sale.cancelledReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CANCELLATION REASON',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sale.cancelledReason!,
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (sale.cancelledBy != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'By: ${sale.cancelledBy}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!isCancelled) ...[
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showCourierSelectionDialog(sale);
              },
              icon: const Icon(Icons.local_shipping),
              label: const Text('Set Courier'),
            ),
            if (sale.status == SaleStatus.pending)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showFullPayDialog(sale);
                },
                icon: const Icon(Icons.payment),
                label: Text(AppLocalizations.t('full_pay')),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showCancelOrderDialog(sale);
              },
              icon: const Icon(Icons.cancel),
              label: Text(AppLocalizations.t('cancel')),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Color _getDeliveryStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Colors.orange;
      case DeliveryStatus.inTransit:
        return Colors.blue;
      case DeliveryStatus.delivered:
        return Colors.green;
      case DeliveryStatus.cancelled:
        return Colors.red;
    }
  }

  String _getDeliveryStatusLabel(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return 'Pending Pickup';
      case DeliveryStatus.inTransit:
        return 'In Transit';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _showCourierSelectionDialog(Sale sale) async {
    final couriers = ['JNT Express', 'FLASH Express', 'NINJAVAN', 'LBC'];
    String? selectedCourier = sale.courier;
    DeliveryStatus? selectedStatus =
        sale.deliveryStatus ?? DeliveryStatus.pending;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Courier & Delivery Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Courier:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: couriers.map((courier) {
                  final isSelected = selectedCourier == courier;
                  return ChoiceChip(
                    label: Text(courier),
                    selected: isSelected,
                    onSelected: (selected) {
                      setDialogState(() {
                        selectedCourier = selected ? courier : null;
                      });
                    },
                    selectedColor: Colors.blue.shade100,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delivery Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DeliveryStatus.values.map((status) {
                  if (status == DeliveryStatus.cancelled) {
                    return const SizedBox.shrink();
                  }
                  final isSelected = selectedStatus == status;
                  return ChoiceChip(
                    label: Text(_getDeliveryStatusLabel(status)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setDialogState(() {
                        selectedStatus = selected ? status : null;
                      });
                    },
                    selectedColor: _getDeliveryStatusColor(
                      status,
                    ).withValues(alpha: 0.3),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final updatedSale = sale.copyWith(
                    courier: selectedCourier,
                    deliveryStatus: selectedStatus,
                  );
                  await _posService.databaseService.updateSale(updatedSale);

                  // Refresh POS recent sales so reports and dashboards pick up changes
                  await _posService.loadRecentSales();

                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Courier and status updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadDeliverySales();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCancelOrderDialog(Sale sale) async {
    // First, verify password
    final isAuthorized = await _showPasswordVerificationDialog();
    if (!isAuthorized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authorization failed. Incorrect password.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If authorized, proceed with cancellation
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel Order #${sale.saleNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to cancel this delivery order?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                border: OutlineInputBorder(),
                hintText: 'Enter reason for cancellation',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a cancellation reason'),
                  ),
                );
                return;
              }

              try {
                // Restore inventory for cancelled orders
                for (final item in sale.items) {
                  final product = await _posService.databaseService
                      .getProductById(item.productId);
                  if (product != null) {
                    final updatedProduct = product.copyWith(
                      quantity: product.quantity + item.quantity,
                    );
                    await _posService.databaseService.updateProduct(
                      updatedProduct,
                    );
                  }
                }

                // Update sale status
                final updatedSale = sale.copyWith(
                  status: SaleStatus.cancelled,
                  cancelledReason: reasonController.text.trim(),
                  cancelledBy: widget.user.name,
                  cancelledAt: DateTime.now(),
                  deliveryStatus: DeliveryStatus.cancelled,
                );
                await _posService.databaseService.updateSale(updatedSale);

                // Refresh POS recent sales so reports reflect cancellation
                await _posService.loadRecentSales();

                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order cancelled successfully'),
                    backgroundColor: Colors.orange,
                  ),
                );
                _loadDeliverySales();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showPasswordVerificationDialog() async {
    final passwordController = TextEditingController();
    final userService = GetIt.I.get<UserService>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authorization Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter Manager or Owner password to cancel this order:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
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

    passwordController.dispose();
    return result ?? false;
  }

  Future<void> _showFullPayDialog(Sale sale) async {
    final remainingBalance = sale.totalAmount - (sale.reservationFee ?? 0);
    String selectedPaymentMethod = 'cash';
    final cashController = TextEditingController();
    final referenceCodeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.t('full_pay')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalizations.t('remaining_balance')}: ₱${remainingBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.t('select_payment'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(AppLocalizations.t('cash')),
                      selected: selectedPaymentMethod == 'cash',
                      onSelected: (selected) {
                        setDialogState(() => selectedPaymentMethod = 'cash');
                      },
                    ),
                    ChoiceChip(
                      label: Text(AppLocalizations.t('gcash')),
                      selected: selectedPaymentMethod == 'gcash',
                      onSelected: (selected) {
                        setDialogState(() => selectedPaymentMethod = 'gcash');
                      },
                    ),
                    ChoiceChip(
                      label: Text(AppLocalizations.t('online_bank')),
                      selected: selectedPaymentMethod == 'online_bank',
                      onSelected: (selected) {
                        setDialogState(
                          () => selectedPaymentMethod = 'online_bank',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (selectedPaymentMethod == 'cash') ...[
                  TextField(
                    controller: cashController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('amount_tendered'),
                      prefixText: '₱',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: referenceCodeController,
                    decoration: InputDecoration(
                      labelText: 'Reference Code (Optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Or capture payment receipt:',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Image capture would go here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Image capture feature can be added here',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Receipt'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate payment
                if (selectedPaymentMethod == 'cash') {
                  final amount = double.tryParse(cashController.text) ?? 0;
                  if (amount < remainingBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.t('insufficient_amount'),
                        ),
                      ),
                    );
                    return;
                  }
                }

                try {
                  // Update sale to completed status
                  final updatedSale = sale.copyWith(
                    status: SaleStatus.completed,
                  );
                  await _posService.databaseService.updateSale(updatedSale);

                  // Refresh POS recent sales so reports and dashboards pick up the completed payment
                  await _posService.loadRecentSales();

                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('payment_completed')),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadDeliverySales();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(AppLocalizations.t('confirm')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String count;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;
  final VoidCallback onFullPay;
  final VoidCallback onRefresh;

  const _DeliveryCard({
    required this.sale,
    required this.onTap,
    required this.onFullPay,
    required this.onRefresh,
  });

  String _extractCustomerName() {
    final notes = sale.notes ?? '';
    final lines = notes.split('\n');
    for (final line in lines) {
      if (line.startsWith('Customer:')) {
        return line.substring('Customer:'.length).trim();
      }
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final isPending = sale.status == SaleStatus.pending;
    final isCancelled = sale.status == SaleStatus.cancelled;
    final statusColor = isCancelled
        ? Colors.red
        : (isPending ? Colors.orange : Colors.green);
    final customerName = _extractCustomerName();
    final remainingBalance = sale.totalAmount - (sale.reservationFee ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCancelled
                              ? Icons.cancel
                              : (isPending
                                    ? Icons.bookmark_add
                                    : Icons.check_circle),
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.saleNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            customerName,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCancelled
                              ? AppLocalizations.t('cancelled')
                              : (isPending
                                    ? AppLocalizations.t('pending_payment')
                                    : AppLocalizations.t('payment_completed')),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Courier icon beside status
                      if (!isCancelled && sale.courier != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: sale.courier!,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_shipping,
                              size: 18,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              // Delivery Status below payment status
              if (!isCancelled &&
                  !isPending &&
                  sale.deliveryStatus != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getDeliveryStatusColor(
                          sale.deliveryStatus!,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getDeliveryStatusColor(
                            sale.deliveryStatus!,
                          ).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getDeliveryStatusIcon(sale.deliveryStatus!),
                            size: 14,
                            color: _getDeliveryStatusColor(
                              sale.deliveryStatus!,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getDeliveryStatusLabel(sale.deliveryStatus!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getDeliveryStatusColor(
                                sale.deliveryStatus!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: '${sale.items.length} items',
                  ),
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label:
                        '${sale.saleDate.month}/${sale.saleDate.day}/${sale.saleDate.year}',
                  ),
                  Text(
                    '₱${sale.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.t('reservation_fee'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '₱${(sale.reservationFee ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppLocalizations.t('remaining_balance')}: ₱${remainingBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.tight,
                      child: ElevatedButton.icon(
                        onPressed: onFullPay,
                        icon: const Icon(Icons.payment, size: 18),
                        label: Text(AppLocalizations.t('full_pay')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getDeliveryStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Colors.orange;
      case DeliveryStatus.inTransit:
        return Colors.blue;
      case DeliveryStatus.delivered:
        return Colors.green;
      case DeliveryStatus.cancelled:
        return Colors.red;
    }
  }

  String _getDeliveryStatusLabel(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return 'Pending Pickup';
      case DeliveryStatus.inTransit:
        return 'In Transit';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData _getDeliveryStatusIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Icons.schedule;
      case DeliveryStatus.inTransit:
        return Icons.local_shipping;
      case DeliveryStatus.delivered:
        return Icons.check_circle;
      case DeliveryStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
