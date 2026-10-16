import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/customer.dart';
import '../../models/loyalty_ledger_entry.dart';
import '../../services/customer_service.dart';
import '../../utils/app_localizations.dart';

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {});
  }

  /// A dialog route completes its future at the start of its reverse
  /// transition. Its TextFields can still rebuild briefly, so their external
  /// controllers must outlive that transition.
  Future<void> _disposeDialogControllers(
    Iterable<TextEditingController> controllers,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  Future<void> _openCustomerDialog({Customer? customer}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerFormDialog(
        customer: customer,
        customerService: _customerService,
      ),
    );

    if (saved == true && mounted) {
      await _reload();
    }
  }

  Future<void> _openStatusDialog(Customer customer) async {
    final ledger = await _customerService.getLedger(customer.id!);
    final insights = await _customerService.getInsights(customer);
    final expiry = await _customerService.getLoyaltyExpirySummary(customer.id!);
    final totalPointsEarned = ledger
        .where((e) => e.entryType == LoyaltyEntryType.earn)
        .fold(0, (sum, e) => sum + e.points);
    final totalPointsRedeemed = ledger
        .where((e) => e.entryType == LoyaltyEntryType.redeem)
        .fold(0, (sum, e) => sum + (e.points.abs()));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_outline, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Customer Status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(customer),
                const SizedBox(height: 16),
                _buildPointsStatsCard(
                  customer,
                  totalPointsEarned,
                  totalPointsRedeemed,
                ),
                const SizedBox(height: 16),
                _buildInsightsCard(customer, insights, expiry),
                const SizedBox(height: 16),
                Text(
                  'Recent Activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildActivityList(ledger),
                const SizedBox(height: 20),
                _buildPrivacyNotice(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async => await _exportPdf(customer, ledger),
            icon: const Icon(Icons.download),
            label: const Text('Export PDF'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openPurchaseHistory(customer, insights);
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Purchase history'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(
    Customer customer,
    CustomerInsights insights,
    LoyaltyExpirySummary expiry,
  ) {
    final color = switch (insights.segment) {
      CustomerSegment.vip => Colors.purple,
      CustomerSegment.atRisk => Colors.orange,
      CustomerSegment.regular => Colors.blue,
      CustomerSegment.newCustomer => Colors.teal,
    };
    final nextExpiry = expiry.nextExpiryDate;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: color),
                const SizedBox(width: 8),
                Text(
                  'Customer insights',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text(insights.segmentLabel),
                  side: BorderSide(color: color.withValues(alpha: .4)),
                  backgroundColor: color.withValues(alpha: .10),
                  labelStyle: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${insights.purchaseHistory.length} completed purchase(s) • '
              '₱ ${insights.completedSalesTotal.toStringAsFixed(2)} total spend',
            ),
            Text(
              insights.lastPurchaseAt == null
                  ? 'No completed purchase yet'
                  : 'Last purchase: ${insights.lastPurchaseAt!.toLocal().toString().split(' ').first}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              expiry.pointsExpiringSoon > 0
                  ? '${expiry.pointsExpiringSoon} loyalty point(s) may expire within 30 days.'
                  : nextExpiry == null
                  ? 'No earned loyalty points are awaiting expiry.'
                  : 'Next loyalty-point expiry: ${nextExpiry.toLocal().toString().split(' ').first}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Segments are based on completed purchases. Loyalty expiry is a 365-day forecast and never deducts points automatically.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPurchaseHistory(
    Customer customer,
    CustomerInsights insights,
  ) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .65,
          minChildSize: .40,
          maxChildSize: .95,
          builder: (context, controller) => Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('${customer.fullName} purchase history'),
                subtitle: Text(
                  '${insights.purchaseHistory.length} completed purchase(s)',
                ),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: insights.purchaseHistory.isEmpty
                    ? const Center(child: Text('No completed purchases yet.'))
                    : ListView.separated(
                        controller: controller,
                        itemCount: insights.purchaseHistory.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final sale = insights.purchaseHistory[index];
                          return ListTile(
                            title: Text(sale.saleNumber),
                            subtitle: Text(
                              '${sale.saleDate.toLocal().toString().split('.').first} • ${sale.itemCount} item(s)',
                            ),
                            trailing: Text(
                              '₱ ${sale.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanCustomerCode() async {
    const manualEntry = '__manual_customer_code__';
    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.code128, BarcodeFormat.qrCode],
    );
    final scannedCode = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scan customer barcode or QR'),
        content: SizedBox(
          width: 320,
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue?.trim();
                  if (value == null || value.isEmpty) continue;
                  Navigator.of(dialogContext).pop(value);
                  break;
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(manualEntry),
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('Enter manually'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    // Keep the native camera view alive until its route has completed the
    // close animation before releasing the controller.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await scannerController.dispose();
    if (!mounted) return;
    if (scannedCode == manualEntry) {
      await _enterCustomerCodeManually();
      return;
    }
    if (scannedCode == null || scannedCode.trim().isEmpty) return;
    await _findCustomerByCode(scannedCode);
  }

  Future<void> _enterCustomerCodeManually() async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter customer code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Customer barcode / QR value',
            hintText: 'Type or use a connected barcode scanner',
            prefixIcon: Icon(Icons.keyboard_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Find customer'),
          ),
        ],
      ),
    );
    final code = controller.text.trim();
    await _disposeDialogControllers([controller]);
    if (submitted != true || code.isEmpty || !mounted) return;
    await _findCustomerByCode(code);
  }

  Future<void> _findCustomerByCode(String code) async {
    final matched = await _customerService.getCustomerByBarcode(code.trim());
    if (!mounted) return;
    if (matched == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No customer matches that barcode or QR value.'),
        ),
      );
      return;
    }
    await _openStatusDialog(matched);
  }

  Widget _buildSummaryCard(Customer customer) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.fullName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if ((customer.phoneNumber ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 16),
                    const SizedBox(width: 8),
                    Text(customer.phoneNumber ?? ''),
                  ],
                ),
              ),
            if ((customer.email ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.email, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(customer.email ?? '')),
                  ],
                ),
              ),
            if ((customer.address ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(customer.address ?? '')),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer.barcodeValue,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsStatsCard(Customer customer, int earned, int redeemed) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn(
              'Current',
              customer.pointsBalance.toString(),
              Colors.blue,
            ),
            _buildStatColumn('Earned', earned.toString(), Colors.green),
            _buildStatColumn('Redeemed', redeemed.toString(), Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildActivityList(List<LoyaltyLedgerEntry> ledger) {
    if (ledger.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No activity yet',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        itemCount: ledger.take(10).length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = ledger[index];
          final isRedeem = entry.entryType == LoyaltyEntryType.redeem;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: isRedeem ? Colors.red[100] : Colors.green[100],
              child: Icon(
                isRedeem ? Icons.remove : Icons.add,
                color: isRedeem ? Colors.red : Colors.green,
                size: 16,
              ),
            ),
            title: Text(
              '${isRedeem ? '-' : '+'}${entry.points.abs()} points',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isRedeem ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              entry.notes ?? (isRedeem ? 'Redeemed' : 'Earned'),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              entry.createdAt.toLocal().toString().split(' ')[0],
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy Notice – Loyalty Rewards Program',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This loyalty rewards system collects and processes only the necessary customer information (purchase history, points balance, and email address) for the purpose of computing and communicating loyalty rewards. All data is stored securely and protected in compliance with the Data Privacy Act of 2012 (RA 10173). Customers\' personal information will not be shared with third parties without consent and will only be retained for as long as necessary to operate the rewards program. By participating, customers acknowledge and agree to the use of their data for this purpose.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(
    Customer customer,
    List<LoyaltyLedgerEntry> ledger,
  ) async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Select folder
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select folder to save PDF',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (selectedDirectory == null) {
        // User cancelled
        return;
      }

      // Generate PDF
      final pdf = pw.Document();
      final totalPointsEarned = ledger
          .where((e) => e.entryType == LoyaltyEntryType.earn)
          .fold(0, (sum, e) => sum + e.points);
      final totalPointsRedeemed = ledger
          .where((e) => e.entryType == LoyaltyEntryType.redeem)
          .fold(0, (sum, e) => sum + (e.points.abs()));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header
            pw.Center(
              child: pw.Text(
                'Customer Loyalty Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Customer Info Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Customer Information',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('Name: ${customer.fullName}'),
                  if ((customer.email ?? '').isNotEmpty)
                    pw.Text('Email: ${customer.email}'),
                  pw.Text('Barcode: ${customer.barcodeValue}'),
                  pw.Text(
                    'Member Since: ${customer.createdAt.toLocal().toString().split(' ')[0]}',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Points Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Loyalty Points Summary',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text(
                            customer.pointsBalance.toString(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('Current Points'),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            totalPointsEarned.toString(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('Total Earned'),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            totalPointsRedeemed.toString(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('Total Redeemed'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Recent Activity Section
            if (ledger.isNotEmpty) ...[
              pw.Text(
                'Recent Activity (Last 10 Transactions)',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Type',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Points',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Balance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...ledger.take(10).map((entry) {
                    final isRedeem = entry.entryType == LoyaltyEntryType.redeem;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            entry.createdAt.toLocal().toString().split(' ')[0],
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            isRedeem ? 'Redeemed' : 'Earned',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${isRedeem ? '-' : '+'}${entry.points.abs()}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            entry.balanceAfter.toString(),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // Privacy Notice
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Privacy Notice – Loyalty Rewards Program',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'This loyalty rewards system collects and processes only the necessary customer information (purchase history, points balance, and email address) for the purpose of computing and communicating loyalty rewards. All data is stored securely and protected in compliance with the Data Privacy Act of 2012 (RA 10173). Customers\' personal information will not be shared with third parties without consent and will only be retained for as long as necessary to operate the rewards program. By participating, customers acknowledge and agree to the use of their data for this purpose.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // Footer
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Generated on ${DateTime.now().toLocal()}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      );

      // Save PDF
      final fileName =
          'Customer_Report_${customer.customerCode}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = path.join(selectedDirectory, fileName);
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to $filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openPointsDialog(Customer customer) async {
    final pointsController = TextEditingController();
    final notesController = TextEditingController();
    final redeemed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${AppLocalizations.t('loyalty_rewards')} - ${customer.fullName}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${AppLocalizations.t('current_points')}: ${customer.pointsBalance}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsController,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('points'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('notes'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          OutlinedButton(
            onPressed: () async {
              final points = int.tryParse(pointsController.text.trim()) ?? 0;
              if (points <= 0) return;
              final ok = await _customerService.redeemPoints(
                customerId: customer.id!,
                points: points,
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
              );
              if (mounted && ok) Navigator.pop(context, true);
            },
            child: Text(AppLocalizations.t('redeem')),
          ),
          ElevatedButton(
            onPressed: () async {
              final points = int.tryParse(pointsController.text.trim()) ?? 0;
              if (points <= 0) return;
              await _customerService.awardPoints(
                customerId: customer.id!,
                saleId: null,
                points: points,
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
              );
              if (mounted) Navigator.pop(context, true);
            },
            child: Text(AppLocalizations.t('award')),
          ),
        ],
      ),
    );

    if (redeemed == true && mounted) {
      await _reload();
    }

    await _disposeDialogControllers([pointsController, notesController]);
  }

  Future<void> _openLedger(Customer customer) async {
    final ledger = await _customerService.getLedger(customer.id!);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${customer.fullName} - ${AppLocalizations.t('points_history')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: ledger.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = ledger[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          entry.entryType == LoyaltyEntryType.redeem
                          ? Colors.red
                          : Colors.green,
                      child: Icon(
                        entry.entryType == LoyaltyEntryType.redeem
                            ? Icons.remove
                            : Icons.add,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      '${entry.points > 0 ? '+' : ''}${entry.points} ${AppLocalizations.t('points')}',
                    ),
                    subtitle: Text(
                      entry.notes ?? entry.entryType.toString().split('.').last,
                    ),
                    trailing: Text(
                      entry.createdAt.toLocal().toString().split('.').first,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('customer_management')),
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _scanCustomerCode,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan customer barcode or QR',
          ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => _openCustomerDialog(),
            icon: const Icon(Icons.person_add),
            tooltip: AppLocalizations.t('add_customer'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('search_customers'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _customerService.getCustomers(query: _query),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final customers = snapshot.data ?? <Customer>[];
                if (customers.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.t('no_customers')),
                  );
                }
                return ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          customer.fullName.isNotEmpty
                              ? customer.fullName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(customer.fullName),
                      trailing: Text(
                        '${customer.pointsBalance} ${AppLocalizations.t('points')}',
                      ),
                      onTap: () => _openLedger(customer),
                      isThreeLine: true,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            [
                              if ((customer.phoneNumber ?? '').isNotEmpty)
                                customer.phoneNumber!,
                              if ((customer.email ?? '').isNotEmpty)
                                customer.email!,
                              customer.barcodeValue,
                            ].join(' • '),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              FilledButton.icon(
                                onPressed: () =>
                                    _openCustomerDialog(customer: customer),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _openStatusDialog(customer),
                                icon: const Icon(Icons.dashboard, size: 16),
                                label: const Text('Status'),
                              ),
                              FilledButton.tonal(
                                onPressed: () =>
                                    _confirmDeleteCustomer(customer),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete, size: 16),
                                      SizedBox(width: 4),
                                      Text('Deactivate'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onLongPress: () async {
                        await showModalBottomSheet<void>(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: Text(
                                    AppLocalizations.t('edit_customer'),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _openCustomerDialog(customer: customer);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.loyalty),
                                  title: Text(
                                    AppLocalizations.t('adjust_points'),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _openPointsDialog(customer);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.history),
                                  title: const Text('Purchase history'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _customerService
                                        .getInsights(customer)
                                        .then(
                                          (insights) => _openPurchaseHistory(
                                            customer,
                                            insights,
                                          ),
                                        );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.block),
                                  title: Text(
                                    AppLocalizations.t('deactivate_customer'),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _confirmDeleteCustomer(customer);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer-management-add-customer',
        onPressed: () => _openCustomerDialog(),
        icon: const Icon(Icons.person_add),
        label: Text(AppLocalizations.t('add_customer')),
      ),
    );
  }

  Future<void> _confirmDeleteCustomer(Customer customer) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deactivation'),
            content: Text(
              'Are you sure you want to deactivate ${customer.fullName}? This customer will no longer be able to redeem loyalty points.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Deactivate'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && mounted) {
      try {
        await _customerService.deleteCustomer(customer.id!);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete ${customer.fullName}: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      if (!mounted) return;
      await _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${customer.fullName}\'s membership and loyalty rewards have been deleted.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

/// Owns its controllers for the complete lifetime of the dialog route.
/// A dialog can still animate after [Navigator.pop], so controllers must not
/// be disposed by the caller when its Future completes.
class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({
    required this.customer,
    required this.customerService,
  });

  final Customer? customer;
  final CustomerService customerService;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.customer?.fullName ?? '',
    );
    _emailController = TextEditingController(
      text: widget.customer?.email ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.customer?.phoneNumber ?? '',
    );
    _addressController = TextEditingController(
      text: widget.customer?.address ?? '',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('customer_name_required'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    final customer = widget.customer;
    final updated = customer == null
        ? Customer(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
          )
        : customer.copyWith(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
          );

    try {
      await widget.customerService.saveCustomer(updated);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save customer: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    return AlertDialog(
      title: Text(
        customer == null
            ? AppLocalizations.t('add_customer')
            : AppLocalizations.t('edit_customer'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fullNameController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.t('customer_name')} *',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('email_address'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.t('cancel')),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  customer == null
                      ? AppLocalizations.t('add')
                      : AppLocalizations.t('save'),
                ),
        ),
      ],
    );
  }
}
