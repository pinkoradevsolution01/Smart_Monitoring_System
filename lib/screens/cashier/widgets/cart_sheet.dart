import 'package:flutter/material.dart';
import '../../../utils/currency_formatter.dart';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../models/customer.dart';
import '../../../services/pos_service.dart';
import '../../../services/customer_service.dart';
import '../../../utils/app_localizations.dart';
import '../../shared/receipt_preview_screen.dart';

class CartSheet extends StatefulWidget {
  final POSService pos;
  final String cashierName;
  final String initialPaymentMethod;

  const CartSheet({
    super.key,
    required this.pos,
    required this.cashierName,
    required this.initialPaymentMethod,
  });

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  late String _selectedPaymentMethod;
  final CustomerService _customerService = CustomerService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceCodeController =
      TextEditingController();
  double _cashTendered = 0.0;
  double _change = 0.0;
  String? _capturedImagePath;
  Customer? _selectedCustomer;
  bool _applyLoyaltyRedemption = false;
  bool _isResolvingLoyalty = false;
  late FocusNode _sheetFocusNode;

  int get _estimatedEarnedPoints {
    if (_selectedCustomer == null) return 0;
    return CustomerService.pointsForCart(widget.pos.cart);
  }

  int get _maxRedeemablePoints {
    final customer = _selectedCustomer;
    if (customer == null) return 0;
    if (customer.pointsBalance < CustomerService.minRedeemPoints) return 0;
    return customer.pointsBalance;
  }

  int get _pointsToRedeem {
    if (!_applyLoyaltyRedemption) return 0;
    final customer = _selectedCustomer;
    if (customer == null) return 0;
    // Redemption uses a fixed points cost equal to the minimum threshold
    return customer.pointsBalance >= CustomerService.minRedeemPoints
        ? CustomerService.minRedeemPoints
        : 0;
  }

  double get _loyaltyDiscountAmount {
    if (_pointsToRedeem <= 0) return 0;
    // Redemption gives a flat percentage discount of the current cart total
    if (widget.pos.cartTotal < CustomerService.minPurchaseAmount) return 0;
    return widget.pos.cartTotal * CustomerService.discountRate;
  }

  double get _payableTotal {
    final payable = widget.pos.cartTotal - _loyaltyDiscountAmount;
    return payable < 0 ? 0 : payable;
  }

  void _recomputeCashChange() {
    if (_selectedPaymentMethod == 'cash') {
      _change = _cashTendered - _payableTotal;
    }
  }

  void _updateCartItemQuantity({
    required int index,
    required String value,
    required int maxStock,
  }) {
    final requestedQuantity = int.tryParse(value);
    if (requestedQuantity == null || requestedQuantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity of at least 1.')),
      );
      return;
    }

    final quantity = requestedQuantity.clamp(1, maxStock).toInt();
    widget.pos.updateCartItem(index, quantity);
    if (requestedQuantity > maxStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $maxStock item(s) are available in stock.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

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
    _amountController.dispose();
    _referenceCodeController.dispose();
    _sheetFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    _recomputeCashChange();

    if (_applyLoyaltyRedemption && _maxRedeemablePoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('loyalty_redemption_not_eligible')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pointsToRedeem > 0 &&
        widget.pos.cartTotal < CustomerService.minPurchaseAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('loyalty_redemption_not_eligible')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate that either reference code or captured image is provided for GCash and Online Bank
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

    try {
      final success = await widget.pos.processSale(
        paymentMethod: _selectedPaymentMethod,
        cashierName: widget.cashierName,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.fullName,
        loyaltyPointsEarned: _estimatedEarnedPoints,
        loyaltyPointsRedeemed: _pointsToRedeem,
        loyaltyDiscountAmount: _loyaltyDiscountAmount,
        referenceCode:
            (_selectedPaymentMethod == 'gcash' ||
                _selectedPaymentMethod == 'online_bank')
            ? _referenceCodeController.text.trim().isNotEmpty
                  ? _referenceCodeController.text.trim()
                  : null
            : null,
        imagePath: _capturedImagePath,
      );
      if (!mounted) return;
      if (success) {
        // Show success snackbar immediately
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('transaction_completed')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Offer receipt printing
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
                    cashierName: widget.cashierName,
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
                  icon: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                  title: Text(
                    AppLocalizations.t('transaction_completed'),
                    textAlign: TextAlign.center,
                  ),
                  content: Text(
                    AppLocalizations.t('payment_successful'),
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Close dialog then close the cart sheet
                        Navigator.of(ctx).pop(false); // close dialog
                        Navigator.of(context).pop(); // close bottom sheet
                      },
                      child: Text(AppLocalizations.t('close')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to record sale')));
      }
    } catch (e) {
      if (!mounted) return;
      // Ensure the sheet closes on error
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No camera available')));
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

  Future<void> _bindCustomerByBarcode(String rawBarcode) async {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) return;

    setState(() {
      _isResolvingLoyalty = true;
    });

    try {
      final customer = await _customerService.getCustomerByBarcode(barcode);
      if (!mounted) return;

      if (customer == null) {
        setState(() {
          _selectedCustomer = null;
          _applyLoyaltyRedemption = false;
          _recomputeCashChange();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('loyalty_customer_not_found')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _selectedCustomer = customer;
        _applyLoyaltyRedemption = false;
        _recomputeCashChange();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t(
              'loyalty_customer_linked',
            ).replaceAll('{name}', customer.fullName),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingLoyalty = false;
        });
      }
    }
  }

  Future<void> _enterLoyaltyBarcodeManually() async {
    final barcodeController = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('enter_loyalty_barcode')),
        content: TextField(
          controller: barcodeController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.t('loyalty_barcode_id'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(barcodeController.text),
            child: Text(AppLocalizations.t('apply')),
          ),
        ],
      ),
    );

    if (entered == null || entered.trim().isEmpty) return;
    await _bindCustomerByBarcode(entered);
  }

  Future<void> _scanLoyaltyBarcode() async {
    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.code128, BarcodeFormat.qrCode],
    );

    String? scannedValue;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('scan_loyalty_barcode')),
        content: SizedBox(
          width: 320,
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final rawValue = barcode.rawValue;
                  if (rawValue == null || rawValue.trim().isEmpty) continue;
                  scannedValue = rawValue.trim();
                  Navigator.of(dialogContext).pop();
                  break;
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.t('cancel')),
          ),
        ],
      ),
    );

    await scannerController.dispose();

    if (!mounted || scannedValue == null || scannedValue!.isEmpty) return;
    await _bindCustomerByBarcode(scannedValue!);
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.pos.cart;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    _recomputeCashChange();

    return KeyboardListener(
      focusNode: _sheetFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (cart.isNotEmpty &&
              !(_selectedPaymentMethod == 'cash' && _change < 0)) {
            _checkout();
          }
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
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
                    Icons.shopping_cart,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.t('cart'),
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
            Flexible(
              flex: 3,
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
                        final maxStock =
                            item.selectedShoeSize?.quantity ??
                            item.product.quantity;
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
                                      AppCurrency.peso(
                                        item.product.sellingPrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Quantity controls
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                widget.pos.updateCartItem(
                                                  idx,
                                                  item.quantity - 1,
                                                );
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.remove,
                                                size: 18,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 48,
                                            child: TextFormField(
                                              initialValue: '${item.quantity}',
                                              keyboardType:
                                                  TextInputType.number,
                                              textAlign: TextAlign.center,
                                              textInputAction:
                                                  TextInputAction.done,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                border: InputBorder.none,
                                              ),
                                              onFieldSubmitted: (value) =>
                                                  _updateCartItemQuantity(
                                                    index: idx,
                                                    value: value,
                                                    maxStock: maxStock,
                                                  ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              if (item.quantity >= maxStock) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Cannot exceed available stock ($maxStock)',
                                                    ),
                                                    backgroundColor:
                                                        Colors.orange,
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              setState(() {
                                                widget.pos.updateCartItem(
                                                  idx,
                                                  item.quantity + 1,
                                                );
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.add,
                                                size: 18,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Item total and delete
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppCurrency.peso(itemTotal),
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
                                        widget.pos.removeFromCart(idx);
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Payment Section
            if (cart.isNotEmpty) ...[
              const Divider(height: 1, thickness: 1),
              Flexible(
                flex: 3,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment method selection
                        Text(
                          AppLocalizations.t('select_payment'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.t('loyalty_rewards'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isResolvingLoyalty
                                    ? null
                                    : _scanLoyaltyBarcode,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: Text(
                                  AppLocalizations.t('scan_loyalty_barcode'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isResolvingLoyalty
                                    ? null
                                    : _enterLoyaltyBarcodeManually,
                                icon: const Icon(Icons.keyboard),
                                label: Text(
                                  AppLocalizations.t('enter_loyalty_barcode'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedCustomer != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedCustomer!.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedCustomer = null;
                                          _applyLoyaltyRedemption = false;
                                          _recomputeCashChange();
                                        });
                                      },
                                      child: Text(AppLocalizations.t('clear')),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${AppLocalizations.t('current_points')}: ${_selectedCustomer!.pointsBalance}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${AppLocalizations.t('estimated_loyalty_points')}: $_estimatedEarnedPoints',
                                ),
                                if (_maxRedeemablePoints > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${AppLocalizations.t('redeemable_points')}: $_maxRedeemablePoints (${AppCurrency.peso(_loyaltyDiscountAmount)})',
                                  ),
                                ] else ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    AppLocalizations.t(
                                      'redemption_minimum_notice',
                                    ).replaceAll(
                                      '{n}',
                                      CustomerService.minRedeemPoints
                                          .toString(),
                                    ),
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                                SwitchListTile(
                                  value:
                                      _applyLoyaltyRedemption &&
                                      _maxRedeemablePoints > 0,
                                  onChanged: _maxRedeemablePoints > 0
                                      ? (value) {
                                          setState(() {
                                            _applyLoyaltyRedemption = value;
                                            _recomputeCashChange();
                                          });
                                        }
                                      : null,
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    AppLocalizations.t(
                                      'apply_loyalty_redemption',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: PaymentMethodChip(
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
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: PaymentMethodChip(
                                label: AppLocalizations.t('gcash'),
                                icon: Icons.phone_android,
                                isSelected: _selectedPaymentMethod == 'gcash',
                                onTap: () {
                                  setState(() {
                                    _selectedPaymentMethod = 'gcash';
                                    _referenceCodeController.clear();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: PaymentMethodChip(
                                label: AppLocalizations.t('online_bank'),
                                icon: Icons.account_balance,
                                isSelected:
                                    _selectedPaymentMethod == 'online_bank',
                                onTap: () {
                                  setState(() {
                                    _selectedPaymentMethod = 'online_bank';
                                    _referenceCodeController.clear();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Cash amount input (only for cash payment)
                        if (_selectedPaymentMethod == 'cash') ...[
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.t('amount_tendered'),
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
                                _change = _cashTendered - widget.pos.cartTotal;
                              });
                            },
                          ),
                          if (_cashTendered > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _change >= 0
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _change >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                    AppCurrency.peso(_change),
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
                        // Reference code input (for GCash and Online Bank)
                        if (_selectedPaymentMethod == 'gcash' ||
                            _selectedPaymentMethod == 'online_bank') ...[
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
                          // Camera capture button
                          OutlinedButton.icon(
                            onPressed: _openCamera,
                            icon: Icon(
                              _capturedImagePath != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt,
                              color: _capturedImagePath != null
                                  ? Colors.green
                                  : null,
                            ),
                            label: Text(
                              _capturedImagePath != null
                                  ? 'Receipt Captured ✓'
                                  : 'Capture Receipt (Optional)',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              side: BorderSide(
                                color: _capturedImagePath != null
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.outline,
                              ),
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
                        // Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppLocalizations.t('subtotal'),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    AppCurrency.peso(widget.pos.cartSubtotal),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.pos.cartDiscount > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppLocalizations.t('discount'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                    Text(
                                      '-${AppCurrency.peso(widget.pos.cartDiscount)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_loyaltyDiscountAmount > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppLocalizations.t('loyalty_redemption'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      '-${AppCurrency.peso(_loyaltyDiscountAmount)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppLocalizations.t('grand_total'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    AppCurrency.peso(_payableTotal),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Checkout button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed:
                                (_selectedPaymentMethod == 'cash' &&
                                    _change < 0)
                                ? null
                                : _checkout,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 24,
                            ),
                            label: Text(
                              AppLocalizations.t('confirm_payment'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ], // end children of inner Column
                    ), // end inner Column
                  ), // end payment scroll view
                ), // end payment Container
              ), // end payment area
            ], // end spread (if cart.isNotEmpty)
          ], // end children of outer Column
        ), // end outer Column
      ), // end Container
    ); // end KeyboardListener
  }
}

// Payment Method Chip Widget
class PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentMethodChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Camera Screen Widget
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
    _controller = CameraController(widget.camera, ResolutionPreset.high);
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
        'receipts',
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Create receipts directory if it doesn't exist
      final receiptsDir = Directory(path.join(directory.path, 'receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      // Copy the image to the new location
      await File(image.path).copy(imagePath);

      if (!mounted) return;
      Navigator.pop(context, imagePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error taking picture: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Receipt'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Center(child: CameraPreview(_controller)),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      onPressed: _takePicture,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
