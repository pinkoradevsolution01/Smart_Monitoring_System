import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ewallet_receipt_preview_screen.dart';
import 'package:get_it/get_it.dart';
import '../../utils/app_localizations.dart';
import '../../services/database_service.dart';
import '../../services/pos_service.dart';
import '../../services/business_info_service.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';

class EWalletTransferScreen extends StatefulWidget {
  final String cashierName;

  const EWalletTransferScreen({super.key, required this.cashierName});

  @override
  State<EWalletTransferScreen> createState() => _EWalletTransferScreenState();
}

class _EWalletTransferScreenState extends State<EWalletTransferScreen> {
  String _transactionType = 'cash_in'; // 'cash_in' or 'cash_out'
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _tenderedController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();

  String? _capturedImagePath;
  double _change = 0.0;
  double _transferFee = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    _tenderedController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double _calculateTransferFee(double amount) {
    if (amount <= 0) return 0.0;
    if (amount < 500) return 10.0;
    if (amount <= 1000) return 15.0;
    if (amount < 1500) return 25.0;
    if (amount <= 2000) return 30.0;
    if (amount < 2500) return 40.0;
    //
    if (amount <= 3000) return 45.0;
    if (amount < 3500) return 55.0;
    if (amount <= 4000) return 60.0;
    if (amount < 4500) return 70.0;
    if (amount <= 5000) return 75.0;

    if (amount < 5500) return 85.0;
    if (amount <= 6000) return 90.0;
    if (amount < 6500) return 100.0;
    if (amount <= 7000) return 105.0;
    if (amount < 7500) return 115.0;

    if (amount <= 8000) return 120.0;
    if (amount < 8500) return 130.0;
    if (amount <= 9000) return 135.0;
    if (amount < 9500) return 145.0;
    if (amount <= 10000) return 150.0;
    return amount * 0.02; // 2% fee for amounts above 10000
  }

  void _calculateChange() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final tendered = double.tryParse(_tenderedController.text) ?? 0.0;
    final fee = _calculateTransferFee(amount);
    final totalWithFee = amount + fee;

    setState(() {
      _transferFee = fee;
      if (_transactionType == 'cash_in') {
        _change = tendered - totalWithFee;
      } else {
        // For cash-out: cash to give = transfer amount - transfer fee
        final cashToGive = amount - fee;
        _tenderedController.text = cashToGive > 0
            ? cashToGive.toStringAsFixed(2)
            : '0.00';
        _change = 0.0;
      }
    });
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

  Future<void> _processTransaction() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final tendered = double.tryParse(_tenderedController.text) ?? 0.0;
    final fee = _calculateTransferFee(amount);
    final totalWithFee = amount + fee;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Require either reference code or captured receipt
    if (_referenceController.text.trim().isEmpty &&
        _capturedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('reference_or_receipt_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_transactionType == 'cash_in' && tendered < totalWithFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tendered amount must be at least ₱${totalWithFee.toStringAsFixed(2)} (including ₱${fee.toStringAsFixed(2)} fee)',
          ),
        ),
      );
      return;
    }

    if (_transactionType == 'cash_out') {
      if (fee >= amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transfer amount must be greater than fee (₱${fee.toStringAsFixed(2)})',
            ),
          ),
        );
        return;
      }
      if (tendered <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash to give must be greater than zero'),
          ),
        );
        return;
      }
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Confirm ${_transactionType == 'cash_in' ? 'E-Wallet Cash-In' : 'E-Wallet Cash-Out'}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: ₱${amount.toStringAsFixed(2)}'),
              Text('Transfer Fee: ₱${fee.toStringAsFixed(2)}'),
              if (_transactionType == 'cash_in') ...[
                Text(
                  'Total: ₱${totalWithFee.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Tendered: ₱${tendered.toStringAsFixed(2)}'),
                if (_change >= 0)
                  Text('Change: ₱${_change.toStringAsFixed(2)}'),
              ] else ...[
                Text(
                  'Cash to Give: ₱${tendered.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
              if (_referenceController.text.isNotEmpty)
                Text('Reference: ${_referenceController.text}'),
              if (_capturedImagePath != null)
                Text(AppLocalizations.t('receipt_captured')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Record sale to database
    await _recordSale(amount, fee, totalWithFee);

    // Generate receipt
    await _generateReceipt(amount, tendered, fee, totalWithFee);
  }

  Future<void> _recordSale(
    double amount,
    double fee,
    double totalWithFee,
  ) async {
    try {
      final dbService = DatabaseService();
      final now = DateTime.now();
      final saleNumber = 'EWT${now.millisecondsSinceEpoch}';

      // Create a sale item for the transfer fee only
      final feeItem = SaleItem(
        saleId: 0, // Will be set by database
        productId: 0, // Virtual product for transfer fee
        productName:
            'Transfer Fee (${_transactionType == 'cash_in' ? 'Cash-In' : 'Cash-Out'})',
        quantity: 1,
        unitPrice: fee,
        discount: 0.0,
        subtotal: fee,
      );

      // Create the sale record - only record the transfer fee as revenue
      final sale = Sale(
        saleNumber: saleNumber,
        items: [feeItem],
        subtotal: fee,
        discountAmount: 0.0,
        taxAmount: fee, // Store fee in taxAmount field for reporting
        totalAmount:
            fee, // Only the transfer fee, not the full transaction amount
        paymentMethod: _transactionType == 'cash_in' ? 'Cash-In' : 'Cash-Out',
        status: SaleStatus.completed,
        notes: _transactionType == 'cash_in'
            ? 'Transfer: ₱${amount.toStringAsFixed(2)} | Fee: ₱${fee.toStringAsFixed(2)}${_referenceController.text.isNotEmpty ? " | Ref: ${_referenceController.text}" : ""}'
            : 'Transfer: ₱${amount.toStringAsFixed(2)} | Fee: ₱${fee.toStringAsFixed(2)}${_referenceController.text.isNotEmpty ? " | Ref: ${_referenceController.text}" : ""}',
        cashierName: widget.cashierName,
        saleDate: now,
        referenceCode: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
        imagePath: _capturedImagePath, // Store captured receipt image path
      );

      final saleId = await dbService.insertSale(sale);
      debugPrint(
        '✅ E-wallet sale recorded successfully! Sale ID: $saleId, Sale Number: $saleNumber, Type: ${sale.paymentMethod}, Amount: ₱${sale.totalAmount.toStringAsFixed(2)}',
      );

      // Refresh POSService to update reports
      try {
        final posService = GetIt.I.get<POSService>();
        await posService.loadRecentSales(days: 30);
        debugPrint('✅ POSService refreshed with latest sales');
      } catch (e) {
        debugPrint('⚠️ Could not refresh POSService: $e');
      }
    } catch (e) {
      debugPrint('❌ Error recording e-wallet sale: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Sale recording failed - $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      // Continue with receipt generation even if sale recording fails
    }
  }

  Future<void> _generateReceipt(
    double amount,
    double tendered,
    double fee,
    double totalWithFee,
  ) async {
    try {
      // Get business information
      final businessInfo = BusinessInfoService().businessInfo;
      final businessName = businessInfo?.storeName ?? 'Smart Store';
      final businessAddress = businessInfo?.storeAddress;

      pw.Font? font;
      pw.Font? fontBold;

      try {
        font = await PdfGoogleFonts.notoSansRegular();
        fontBold = await PdfGoogleFonts.notoSansBold();
      } catch (e) {
        debugPrint('Failed to load Google Fonts: $e');
      }

      final pdf = pw.Document();
      final now = DateTime.now();
      final df = DateFormat('yyyy-MM-dd HH:mm:ss');
      final refNumber = 'EWT${now.millisecondsSinceEpoch}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            80 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 6 * PdfPageFormat.mm,
          ),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (businessAddress != null && businessAddress.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      businessAddress,
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 9)
                          : const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'E-WALLET TRANSFER',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    _transactionType == 'cash_in' ? 'CASH-IN' : 'CASH-OUT',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(),
                pw.Text(
                  'Reference: $refNumber',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 10)
                      : const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Date: ${df.format(now)}',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 10)
                      : const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Cashier: ${widget.cashierName}',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 10)
                      : const pw.TextStyle(fontSize: 10),
                ),
                if (_referenceController.text.isNotEmpty)
                  pw.Text(
                    'Customer Ref: ${_referenceController.text}',
                    style: font != null
                        ? pw.TextStyle(font: font, fontSize: 10)
                        : const pw.TextStyle(fontSize: 10),
                  ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Transfer Amount:',
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 11)
                          : const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'PHP ${amount.toStringAsFixed(2)}',
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 11)
                          : const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Transfer Fee:',
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 11)
                          : const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'PHP ${fee.toStringAsFixed(2)}',
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 11)
                          : const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Amount:',
                      style: fontBold != null
                          ? pw.TextStyle(
                              font: fontBold,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            )
                          : pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                    ),
                    pw.Text(
                      'PHP ${totalWithFee.toStringAsFixed(2)}',
                      style: fontBold != null
                          ? pw.TextStyle(
                              font: fontBold,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            )
                          : pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                    ),
                  ],
                ),
                if (_transactionType == 'cash_in') ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Cash Tendered:',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 11)
                            : const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        'PHP ${tendered.toStringAsFixed(2)}',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 11)
                            : const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  if (_change > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Change:',
                          style: font != null
                              ? pw.TextStyle(font: font, fontSize: 11)
                              : const pw.TextStyle(fontSize: 11),
                        ),
                        pw.Text(
                          'PHP ${_change.toStringAsFixed(2)}',
                          style: font != null
                              ? pw.TextStyle(font: font, fontSize: 11)
                              : const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                ] else ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Cash Given:',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 11)
                            : const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        'PHP ${tendered.toStringAsFixed(2)}',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 11)
                            : const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
                pw.Divider(),
                if (_capturedImagePath != null)
                  pw.Text(
                    '✓ Receipt Captured',
                    style: font != null
                        ? pw.TextStyle(font: font, fontSize: 9)
                        : const pw.TextStyle(fontSize: 9),
                  ),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text(
                    'Thank you!',
                    style: font != null
                        ? pw.TextStyle(font: font, fontSize: 10)
                        : const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Open preview screen (lets user print/share) instead of directly printing
      final printed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EWalletReceiptPreviewScreen(
            cashierName: widget.cashierName,
            transactionType: _transactionType,
            amount: amount,
            tendered: tendered,
            fee: fee,
            totalWithFee: totalWithFee,
            reference: _referenceController.text.isNotEmpty
                ? _referenceController.text
                : null,
            capturedImagePath: _capturedImagePath,
            showPrintDialogOnOpen: true,
          ),
        ),
      );

      if (!mounted) return;
      if (printed == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt printed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Show success dialog and reset form
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text(
            'Transaction Successfully Completed',
            textAlign: TextAlign.center,
          ),
          content: Text(
            _transactionType == 'cash_in'
                ? 'Cash-In transaction has been processed successfully.'
                : 'Cash-Out transaction has been processed successfully.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                // Reset form
                setState(() {
                  _amountController.clear();
                  _tenderedController.clear();
                  _referenceController.clear();
                  _capturedImagePath = null;
                  _change = 0.0;
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating receipt: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('ewallet_transfer'))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1000,
                maxHeight: constraints.maxHeight,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transaction Type Selection
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.t('transaction_type'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _transactionType,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.swap_horiz),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'cash_in',
                                  child: Text(
                                    AppLocalizations.t('cash_in'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'cash_out',
                                  child: Text(
                                    AppLocalizations.t('cash_out'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _transactionType = value!;
                                  _amountController.clear();
                                  _tenderedController.clear();
                                  _referenceController.clear();
                                  _change = 0.0;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Transaction Form
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _transactionType == 'cash_in'
                                  ? 'Cash-In Details'
                                  : 'Cash-Out Details',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Amount Transfer
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Transfer Amount (₱) *',
                                hintText: '0.00',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(
                                  Icons.account_balance_wallet,
                                ),
                                helperText: _transactionType == 'cash_in'
                                    ? 'Credit to e-wallet'
                                    : 'Debit from e-wallet',
                              ),
                              onChanged: (_) => _calculateChange(),
                            ),
                            const SizedBox(height: 16),

                            // Amount Tendered
                            TextField(
                              controller: _tenderedController,
                              keyboardType: TextInputType.number,
                              readOnly: _transactionType == 'cash_out',
                              decoration: InputDecoration(
                                labelText: _transactionType == 'cash_in'
                                    ? 'Cash Received (₱) *'
                                    : 'Cash to Give (₱) *',
                                hintText: '0.00',
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  _transactionType == 'cash_in'
                                      ? Icons.payments
                                      : Icons.money,
                                ),
                                helperText: _transactionType == 'cash_in'
                                    ? 'From customer'
                                    : 'Auto-calculated',
                                filled: _transactionType == 'cash_out',
                                fillColor: _transactionType == 'cash_out'
                                    ? Colors.grey.withValues(alpha: 0.1)
                                    : null,
                              ),
                              onChanged: (_) => _calculateChange(),
                            ),
                            const SizedBox(height: 16),

                            // Transfer Fee Display
                            if (_transferFee > 0) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppLocalizations.t('transfer_fee'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    Text(
                                      '₱${_transferFee.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _transactionType == 'cash_in'
                                          ? 'Total Amount'
                                          : 'Cash to Give',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      _transactionType == 'cash_in'
                                          ? '₱${((double.tryParse(_amountController.text) ?? 0.0) + _transferFee).toStringAsFixed(2)}'
                                          : '₱${((double.tryParse(_amountController.text) ?? 0.0) - _transferFee).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Change Display (Cash-In only)
                            if (_transactionType == 'cash_in' &&
                                _change != 0) ...[
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
                                      'Change',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _change >= 0
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        '₱${_change.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: _change >= 0
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Reference Code (Optional)
                            TextField(
                              controller: _referenceController,
                              decoration: const InputDecoration(
                                labelText: 'Reference Code (Optional)',
                                hintText: 'Enter reference number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.tag),
                                helperText: 'Optional reference',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Camera Capture
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.t('receipt_verification'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_capturedImagePath == null) ...[
                              OutlinedButton.icon(
                                onPressed: _openCamera,
                                icon: const Icon(Icons.camera_alt),
                                label: Text(
                                  AppLocalizations.t(
                                    'capture_receipt_optional',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Optionally capture receipt for verification',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ] else ...[
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_capturedImagePath!),
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _capturedImagePath = null;
                                        });
                                      },
                                      icon: const Icon(Icons.close),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Receipt captured'),
                                  ),
                                  TextButton(
                                    onPressed: _openCamera,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: const Size(0, 36),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(AppLocalizations.t('retake')),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Process Button
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _processTransaction,
                        icon: const Icon(Icons.check_circle, size: 24),
                        label: Text(
                          'Process ${_transactionType == 'cash_in' ? 'Cash-In' : 'Cash-Out'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Camera Screen
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
      final path =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(image.path).copy(path);

      if (!mounted) return;
      Navigator.pop(context, path);
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
      appBar: AppBar(
        title: Text(AppLocalizations.t('capture_receipt')),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller)),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      onPressed: _takePicture,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.camera,
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
