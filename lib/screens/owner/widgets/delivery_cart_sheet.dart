import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../services/pos_service.dart';
import '../../../services/customer_service.dart';
import '../../../models/sale.dart';
import '../../../utils/app_localizations.dart';
import '../../shared/receipt_preview_screen.dart';

class DeliveryCartSheet extends StatefulWidget {
  final POSService pos;
  final String operatorName;
  final String initialPaymentMethod;

  const DeliveryCartSheet({
    super.key,
    required this.pos,
    required this.operatorName,
    required this.initialPaymentMethod,
  });

  @override
  State<DeliveryCartSheet> createState() => _DeliveryCartSheetState();
}

class _DeliveryCartSheetState extends State<DeliveryCartSheet> {
  late String _selectedPaymentMethod;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceCodeController =
      TextEditingController();
  double _cashTendered = 0.0;
  double _change = 0.0;
  String? _capturedImagePath;
  bool _isReservation = false;
  late FocusNode _sheetFocusNode;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.initialPaymentMethod;
    _sheetFocusNode = FocusNode();
    // request focus so Enter key works immediately when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sheetFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _referenceCodeController.dispose();
    _sheetFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    // Validate reservation fee for all payment methods when reservation is enabled
    if (_isReservation) {
      final reservationFee = double.tryParse(_amountController.text) ?? 0.0;
      if (reservationFee <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter ${AppLocalizations.t('reservation_fee')} amount',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Validate payment method requirements
    if (_selectedPaymentMethod == 'cash' && !_isReservation && _change < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('insufficient_cash')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if ((_selectedPaymentMethod == 'gcash' ||
            _selectedPaymentMethod == 'online_bank') &&
        _referenceCodeController.text.trim().isEmpty &&
        _capturedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please provide either a reference code or capture a receipt for ${_selectedPaymentMethod == 'gcash' ? 'GCash' : 'Online Bank'} payment',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate required fields
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('customer_name_required')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_contactNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('contact_number_required')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('address_required')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Combine all delivery info into notes
    final deliveryInfo = StringBuffer();
    deliveryInfo.writeln('DELIVERY ORDER');
    deliveryInfo.writeln('Customer: ${_customerNameController.text.trim()}');
    deliveryInfo.writeln('Contact: ${_contactNumberController.text.trim()}');
    deliveryInfo.writeln('Address: ${_addressController.text.trim()}');
    if (_notesController.text.trim().isNotEmpty) {
      deliveryInfo.writeln('Notes: ${_notesController.text.trim()}');
    }

    try {
      final customerService = CustomerService();
      final matchedCustomer = await customerService.getCustomerByName(
        _customerNameController.text.trim(),
      );
      final loyaltyPointsEarned = _isReservation
          ? 0
          : CustomerService.pointsForCart(widget.pos.cart);
      final success = await widget.pos.processSale(
        paymentMethod: _selectedPaymentMethod,
        cashierName: widget.operatorName,
        notes: deliveryInfo.toString(),
        transactionType: TransactionType.delivery,
        referenceCode:
            (_selectedPaymentMethod == 'gcash' ||
                _selectedPaymentMethod == 'online_bank')
            ? _referenceCodeController.text.trim().isNotEmpty
                  ? _referenceCodeController.text.trim()
                  : null
            : null,
        isReservation: _isReservation,
        reservationFee: _isReservation
            ? double.tryParse(_amountController.text)
            : null,
        customerId: matchedCustomer?.id,
        customerName: _customerNameController.text.trim(),
        loyaltyPointsEarned: matchedCustomer == null ? 0 : loyaltyPointsEarned,
      );
      if (success) {
        // Show success snackbar immediately
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('transaction_completed')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Offer receipt printing (reuse cashier flow)
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            Future<void> openPreviewAndPrint() async {
              Navigator.of(ctx).pop(); // close dialog
              Navigator.of(context).pop(); // close bottom sheet
              if (!mounted) return;
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ReceiptPreviewScreen(
                    pos: widget.pos,
                    cashierName: widget.operatorName,
                    showPrintDialogOnOpen: true,
                  ),
                ),
              );
              if (!mounted) return;
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Receipt printed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }

            return Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
                LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<Intent>(
                    onInvoke: (intent) => openPreviewAndPrint(),
                  ),
                  DismissIntent: CallbackAction<Intent>(
                    onInvoke: (intent) => Navigator.of(ctx).pop(false),
                  ),
                },
                child: AlertDialog(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(AppLocalizations.t('delivery_order')),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                  content: Text(
                    AppLocalizations.t('delivery_order_success_message'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(AppLocalizations.t('cancel')),
                    ),
                    ElevatedButton(
                      onPressed: openPreviewAndPrint,
                      child: Text(AppLocalizations.t('print_receipt')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('failed_to_create_delivery')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No cameras found')));
        return;
      }

      final camera = cameras.first;
      if (!mounted) return;

      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => _CameraScreen(camera: camera)),
      );

      if (imagePath != null) {
        setState(() {
          _capturedImagePath = imagePath;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  Future<void> _pickImageFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file?.path != null) {
        setState(() {
          _capturedImagePath = file!.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File picker error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.pos.cart;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final estimatedLoyaltyPoints = _isReservation
        ? 0
        : CustomerService.pointsForCart(cart);
    final cartTotal = cart.fold(0.0, (s, it) => s + it.total);
    final estimatedRedemptionValue =
        cartTotal < CustomerService.minPurchaseAmount
        ? 0.0
        : cartTotal * CustomerService.discountRate;

    return KeyboardListener(
      focusNode: _sheetFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (cart.isNotEmpty) {
            _checkout();
          }
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.t('delivery_order'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Cart Items
            Expanded(
              flex: 2,
              child: cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.t('cart_empty'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: cart.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = cart[idx];
                        final itemTotal =
                            item.product.sellingPrice * item.quantity;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product image or icon
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    item.product.imagePath != null &&
                                        item.product.imagePath!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(item.product.imagePath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Icon(
                                            Icons.shopping_bag,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.shopping_bag,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              // Product details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item.selectedShoeSize != null) ...[
                                      const SizedBox(height: 2),
                                      Container(
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
                                          'Size: US ${item.selectedShoeSize!.usSize}',
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
                                    const SizedBox(height: 4),
                                    Text(
                                      '₱${item.product.sellingPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // Quantity controls
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                onPressed: () {
                                                  if (item.quantity > 1) {
                                                    widget.pos.updateCartItem(
                                                      idx,
                                                      item.quantity - 1,
                                                    );
                                                  } else {
                                                    widget.pos.removeFromCart(
                                                      idx,
                                                    );
                                                  }
                                                },
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Text(
                                                  '${item.quantity}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.add,
                                                  size: 18,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                onPressed: () {
                                                  final maxQuantity =
                                                      item
                                                          .product
                                                          .hasShoeVariants
                                                      ? (item
                                                                .selectedShoeSize
                                                                ?.quantity ??
                                                            0)
                                                      : item.product.quantity;
                                                  if (item.quantity <
                                                      maxQuantity) {
                                                    widget.pos.updateCartItem(
                                                      idx,
                                                      item.quantity + 1,
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₱${itemTotal.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  widget.pos.removeFromCart(
                                                    idx,
                                                  );
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // Summary Section (scrollable)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reservation Checkbox
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          AppLocalizations.t('reservation_order'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          AppLocalizations.t('reservation_order_hint'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        value: _isReservation,
                        onChanged: (value) {
                          setState(() {
                            _isReservation = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 8),
                      // Payment Method Selection
                      Text(
                        AppLocalizations.t('select_payment'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PaymentMethodChip(
                              label: AppLocalizations.t('cash'),
                              icon: Icons.payments_outlined,
                              isSelected: _selectedPaymentMethod == 'cash',
                              onTap: () {
                                setState(() {
                                  _selectedPaymentMethod = 'cash';
                                  _cashTendered = 0.0;
                                  _change = 0.0;
                                  _amountController.clear();
                                  _referenceCodeController.clear();
                                  _capturedImagePath = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PaymentMethodChip(
                              label: AppLocalizations.t('gcash'),
                              icon: Icons.phone_android,
                              isSelected: _selectedPaymentMethod == 'gcash',
                              onTap: () {
                                setState(() {
                                  _selectedPaymentMethod = 'gcash';
                                  _amountController.clear();
                                  _referenceCodeController.clear();
                                  _capturedImagePath = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PaymentMethodChip(
                              label: AppLocalizations.t('online_bank'),
                              icon: Icons.account_balance,
                              isSelected:
                                  _selectedPaymentMethod == 'online_bank',
                              onTap: () {
                                setState(() {
                                  _selectedPaymentMethod = 'online_bank';
                                  _amountController.clear();
                                  _referenceCodeController.clear();
                                  _capturedImagePath = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Cash amount input
                      if (_selectedPaymentMethod == 'cash') ...[
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _isReservation
                                ? AppLocalizations.t('reservation_fee')
                                : AppLocalizations.t('amount_tendered'),
                            prefixText: '₱ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _cashTendered = double.tryParse(value) ?? 0.0;
                              if (!_isReservation) {
                                _change = _cashTendered - widget.pos.cartTotal;
                              }
                            });
                          },
                        ),
                        if (_isReservation && _cashTendered > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLocalizations.t('remaining_balance'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                Text(
                                  '₱${(widget.pos.cartTotal - _cashTendered).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!_isReservation && _cashTendered > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _change >= 0
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _change >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLocalizations.t('change'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _change >= 0
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                                Text(
                                  '₱${_change.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _change >= 0
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                      // Reference code & receipt
                      if (_selectedPaymentMethod == 'gcash' ||
                          _selectedPaymentMethod == 'online_bank') ...[
                        // Reservation Fee input for GCash/Online Bank
                        if (_isReservation) ...[
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  '${AppLocalizations.t('reservation_fee')} *',
                              prefixText: '₱ ',
                              hintText: 'Enter reservation fee amount',
                              helperText:
                                  'Enter the amount paid for reservation',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                // Trigger rebuild for remaining balance display
                              });
                            },
                          ),
                          if ((double.tryParse(_amountController.text) ?? 0.0) >
                              0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppLocalizations.t('remaining_balance'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                  Text(
                                    '₱${(widget.pos.cartTotal - (double.tryParse(_amountController.text) ?? 0.0)).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                        TextField(
                          controller: _referenceCodeController,
                          decoration: InputDecoration(
                            labelText: 'Reference Code (Optional)',
                            hintText: 'Enter transaction reference number',
                            helperText:
                                'Provide reference code OR capture receipt',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(
                              _selectedPaymentMethod == 'gcash'
                                  ? Icons.phone_android
                                  : Icons.account_balance,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openCamera,
                                  icon: const Icon(Icons.camera_alt, size: 20),
                                  label: const Text('Camera'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickImageFile,
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 20,
                                  ),
                                  label: const Text('Gallery'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_capturedImagePath != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_capturedImagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _capturedImagePath = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                      // Customer Information Section
                      Text(
                        AppLocalizations.t('customer_information'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Customer Name
                      TextField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: '${AppLocalizations.t('customer_name')} *',
                          hintText: AppLocalizations.t('enter_customer_name'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Contact Number
                      TextField(
                        controller: _contactNumberController,
                        decoration: InputDecoration(
                          labelText:
                              '${AppLocalizations.t('contact_number')} *',
                          hintText: AppLocalizations.t('enter_contact_number'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      // Complete Address
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText:
                              '${AppLocalizations.t('complete_address')} *',
                          hintText: AppLocalizations.t(
                            'enter_complete_address',
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      // Delivery Notes (Optional)
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText:
                              '${AppLocalizations.t('delivery_notes')} (${AppLocalizations.t('optional')})',
                          hintText: AppLocalizations.t(
                            'enter_delivery_notes_hint',
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.note),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      if (!_isReservation) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.loyalty,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estimated loyalty points',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$estimatedLoyaltyPoints points · ₱${estimatedRedemptionValue.toStringAsFixed(2)} value',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Redemption requires at least ${CustomerService.minRedeemPoints} points.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // Total Amount
                      Row(
                        children: [
                          Text(
                            AppLocalizations.t('total'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₱${widget.pos.cartTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Checkout Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: cart.isEmpty ? null : _checkout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isReservation
                                    ? Icons.bookmark_add
                                    : Icons.local_shipping,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isReservation
                                    ? AppLocalizations.t('reserve_order')
                                    : AppLocalizations.t(
                                        'create_delivery_order',
                                      ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
}

// Payment Method Chip Widget
class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Camera Screen for capturing payment receipt
class _CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const _CameraScreen({required this.camera});

  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      // Save to app directory
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(
        directory.path,
        'payment_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await image.saveTo(imagePath);

      if (!mounted) return;
      Navigator.of(context).pop(imagePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Payment Receipt'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        backgroundColor: Colors.white,
        child: const Icon(Icons.camera_alt, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
