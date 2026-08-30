import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:get_it/get_it.dart';
import '../../services/pos_service.dart';
import '../../services/database_service.dart';
import '../../services/package_service.dart';
import '../../models/pricing_package.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
// 'dart:typed_data' not needed; types provided by flutter/services.dart
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/sale.dart';
import '../../utils/app_localizations.dart';
import 'cctv_screen.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen>
    with SingleTickerProviderStateMixin {
  final POSService pos = GetIt.I<POSService>();
  final PackageService packageService = GetIt.I<PackageService>();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  DateTimeRange? _range;
  double _dailyTotal = 0.0;
  double _dailyTransferFees = 0.0;
  int _dailyTransactions = 0;
  double _dailyAverage = 0.0;
  bool _loadingDaily = true;
  DateTime _selectedDay = DateTime.now();
  String _searchQuery = '';
  List<Sale> _allSales = [];
  List<Sale> _rangeSales = [];
  bool _loadingSearch = false;

  // Financial Reports Data
  DateTime _financialDay = DateTime.now();
  bool _loadingFinancial = true;
  double _grossRevenue = 0.0;
  double _netRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _operatingCosts = 0.0;
  double _financialTransferFees = 0.0;
  double _grossProfit = 0.0;
  double _netProfit = 0.0;
  double _profitMargin = 0.0;
  double _growthRate = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    pos.addListener(_onPosChanged);
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          // Set loading state immediately if we need to load data
          if (query.isNotEmpty && _allSales.isEmpty) {
            _loadingSearch = true;
          }
        });
        if (query.isNotEmpty && _allSales.isEmpty) {
          _loadAllSales();
        }
      }
    });
    pos.loadRecentSales(days: 7);
    debugPrint('📊 Owner Sales: Loaded ${pos.recentSales.length} recent sales');
    _range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    // Load sales for the initial range so For Delivery transactions appear
    if (_range != null) {
      _loadRangeSales(_range!);
    }
    _loadDailySummary(_selectedDay);
    _loadFinancialData(_financialDay);
  }

  Future<void> _loadRangeSales(DateTimeRange range) async {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    try {
      final sales = await pos.getSalesReport(startDate: start, endDate: end);
      if (mounted) setState(() => _rangeSales = sales);
    } catch (e) {
      debugPrint('❌ Error loading range sales: $e');
    }
  }

  void _onPosChanged() {
    debugPrint(
      '📊 Owner Sales: POSService changed, now have ${pos.recentSales.length} sales',
    );
    if (mounted) setState(() {});
  }

  // helper removed: not needed after refactor

  Future<void> _loadAllSales() async {
    if (_loadingSearch && _allSales.isNotEmpty) return; // Already loaded
    try {
      final db = DatabaseService();
      // Load all sales (no date filter)
      final allSales = await db.getAllSales();
      debugPrint('🔍 Loaded ${allSales.length} total sales for search');
      if (mounted) {
        setState(() {
          _allSales = allSales;
          _loadingSearch = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading all sales: $e');
      if (mounted) {
        setState(() => _loadingSearch = false);
      }
    }
  }

  Future<void> _loadDailySummary(
    DateTime day, {
    bool showDialog = false,
  }) async {
    setState(() => _loadingDaily = true);
    final db = DatabaseService();
    final total = await db.getDailySales(day);
    final tx = await db.getTotalTransactions(day);

    // Calculate transfer fees separately
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    final allSales = await db.getAllSales(startDate: start, endDate: end);
    double transferFees = 0.0;
    debugPrint(
      '📊 Owner: Calculating transfer fees from ${allSales.length} sales',
    );
    int ewalletCount = 0;
    for (final sale in allSales) {
      debugPrint(
        '   Sale: ${sale.saleNumber} | Method: ${sale.paymentMethod} | Tax: ${sale.taxAmount}',
      );
      if (sale.paymentMethod == 'Cash-In' || sale.paymentMethod == 'Cash-Out') {
        ewalletCount++;
        debugPrint(
          '   ✓ E-wallet: ${sale.saleNumber} | ${sale.paymentMethod} | taxAmount: ${sale.taxAmount}',
        );
        transferFees += sale.taxAmount; // Transfer fees stored in taxAmount
      }
    }
    debugPrint(
      '📊 Owner: Found $ewalletCount e-wallet sales with total transfer fees: ${AppCurrency.peso(transferFees)}',
    );

    if (mounted) {
      setState(() {
        _dailyTotal = total;
        _dailyTransferFees = transferFees;
        _dailyTransactions = tx;
        _dailyAverage = tx > 0 ? total / tx : 0.0;
        _loadingDaily = false;
      });

      // Show dialog with sales list if requested (show even when there are no sales)
      if (showDialog) {
        await _showDailySalesDialog(allSales, day);
      }
    }
  }

  Future<void> _pickDailyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _selectedDay = picked;
      await _loadDailySummary(picked, showDialog: true);
    }
  }

  Future<void> _loadFinancialData(DateTime day) async {
    setState(() => _loadingFinancial = true);

    final db = DatabaseService();
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    final sales = await db.getAllSales(startDate: start, endDate: end);

    // Calculate revenue
    double grossRev = 0.0;
    double transferFees = 0.0;

    for (final sale in sales) {
      if (sale.status == SaleStatus.completed) {
        grossRev += sale.totalAmount;

        // Calculate transfer fees from e-wallet sales
        if (sale.paymentMethod == 'Cash-In' ||
            sale.paymentMethod == 'Cash-Out') {
          transferFees += sale.taxAmount;
        }
      }
    }

    // Calculate growth rate (compare with previous day)
    final prevDayStart = DateTime(day.year, day.month, day.day - 1);
    final prevDayEnd = DateTime(
      day.year,
      day.month,
      day.day - 1,
      23,
      59,
      59,
      999,
    );
    final prevDaySales = await db.getAllSales(
      startDate: prevDayStart,
      endDate: prevDayEnd,
    );
    double prevDayRevenue = 0.0;
    for (final sale in prevDaySales) {
      if (sale.status == SaleStatus.completed) {
        prevDayRevenue += sale.totalAmount;
      }
    }

    double growth = 0.0;
    if (prevDayRevenue > 0) {
      growth = ((grossRev - prevDayRevenue) / prevDayRevenue) * 100;
    }

    // Operating costs (estimated at 20% of gross revenue)
    double opCosts = grossRev * 0.20;

    // Total expenses
    double totalExp = opCosts + transferFees;

    // Net revenue (gross - transfer fees)
    double netRev = grossRev - transferFees;

    // Profit calculations
    double grossProf = grossRev - opCosts;
    double netProf = grossRev - totalExp;
    double profMargin = grossRev > 0 ? (netProf / grossRev) * 100 : 0;

    if (mounted) {
      setState(() {
        _grossRevenue = grossRev;
        _netRevenue = netRev;
        _totalExpenses = totalExp;
        _operatingCosts = opCosts;
        _financialTransferFees = transferFees;
        _grossProfit = grossProf;
        _netProfit = netProf;
        _profitMargin = profMargin;
        _growthRate = growth;
        _loadingFinancial = false;
      });
    }
  }

  Future<void> _pickFinancialDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _financialDay,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _financialDay = picked);
      await _loadFinancialData(picked);
    }
  }

  Future<void> _exportFinancialCsv() async {
    final buffer = StringBuffer();
    buffer.write(String.fromCharCode(0xFEFF));
    buffer.writeln(
      'Financial Report - ${_financialDay.toIso8601String().substring(0, 10)}',
    );
    buffer.writeln('');
    buffer.writeln('Revenue Overview');
    buffer.writeln('Gross Revenue,${_grossRevenue.toStringAsFixed(2)}');
    buffer.writeln('Net Revenue,${_netRevenue.toStringAsFixed(2)}');
    buffer.writeln('Growth Rate,${_growthRate.toStringAsFixed(2)}%');
    buffer.writeln('');
    buffer.writeln('Expenses');
    buffer.writeln('Operating Costs,${_operatingCosts.toStringAsFixed(2)}');
    buffer.writeln(
      'Transfer Fees,${_financialTransferFees.toStringAsFixed(2)}',
    );
    buffer.writeln('Total Expenses,${_totalExpenses.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('Profit Analysis');
    buffer.writeln('Gross Profit,${_grossProfit.toStringAsFixed(2)}');
    buffer.writeln('Net Profit,${_netProfit.toStringAsFixed(2)}');
    buffer.writeln('Profit Margin,${_profitMargin.toStringAsFixed(2)}%');

    final csv = buffer.toString();
    final csvBytes = Uint8List.fromList(utf8.encode(csv));

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export Financial Report'),
        content: SingleChildScrollView(child: SelectableText(csv)),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await Clipboard.setData(ClipboardData(text: csv));
              navigator.pop();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final path = await FilePicker.saveFile(
                dialogTitle: 'Save Financial Report',
                fileName:
                    'financial_${_financialDay.toIso8601String().substring(0, 10)}.csv',
                type: FileType.custom,
                allowedExtensions: ['csv'],
                bytes: csvBytes,
              );
              if (path != null) {
                final file = File(path);
                await file.writeAsString(csv, encoding: utf8);
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Financial report exported successfully'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportFinancialPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            'Financial Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _financialDay.toIso8601String().substring(0, 10),
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 24),

          // Revenue Overview
          pw.Text(
            'Revenue Overview',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Gross Revenue:'),
              pw.Text(
                AppCurrency.peso(_grossRevenue),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Net Revenue:'),
              pw.Text(
                AppCurrency.peso(_netRevenue),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Growth Rate:'),
              pw.Text(
                '${_growthRate.toStringAsFixed(2)}%',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Expenses
          pw.Text(
            'Expenses',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Operating Costs:'),
              pw.Text(
                AppCurrency.peso(_operatingCosts),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Transfer Fees:'),
              pw.Text(
                AppCurrency.peso(_financialTransferFees),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Expenses:'),
              pw.Text(
                AppCurrency.peso(_totalExpenses),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Profit Analysis
          pw.Text(
            'Profit Analysis',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Gross Profit:'),
              pw.Text(
                AppCurrency.peso(_grossProfit),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Net Profit:'),
              pw.Text(
                AppCurrency.peso(_netProfit),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Profit Margin:'),
              pw.Text(
                '${_profitMargin.toStringAsFixed(2)}%',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  Future<void> _exportCsv() async {
    // Query database directly for the selected day
    final start = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final end = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      23,
      59,
      59,
      999,
    );
    final db = DatabaseService();
    final daySales = await db.getAllSales(startDate: start, endDate: end);

    String quoteIfNeeded(String v) {
      final needsQuote = v.contains(',') || v.contains('\n') || v.contains('"');
      if (!needsQuote) return v;
      return '"${v.replaceAll('"', '""')}"';
    }

    final buffer = StringBuffer();
    // UTF-8 BOM for better Excel compatibility
    buffer.write(String.fromCharCode(0xFEFF));
    buffer.writeln('SaleNumber,Date,Cashier,Items,Total');
    for (final s in daySales) {
      final row = [
        quoteIfNeeded(s.saleNumber),
        quoteIfNeeded(s.saleDate.toIso8601String()),
        quoteIfNeeded(s.cashierName),
        quoteIfNeeded(s.itemCount.toString()),
        quoteIfNeeded(s.totalAmount.toStringAsFixed(2)),
      ].join(',');
      buffer.writeln(row);
    }
    final csv = buffer.toString();
    final csvBytes = Uint8List.fromList(utf8.encode(csv));
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('export_csv')),
        content: SingleChildScrollView(child: SelectableText(csv)),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await Clipboard.setData(ClipboardData(text: csv));
              navigator.pop();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () async {
              // Capture contexts before the async gap
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final path = await FilePicker.saveFile(
                dialogTitle: 'Save CSV',
                fileName:
                    'sales_${_selectedDay.toIso8601String().substring(0, 10)}.csv',
                type: FileType.custom,
                allowedExtensions: ['csv'],
                bytes: csvBytes,
              );
              if (path != null) {
                final file = File(path);
                await file.writeAsString(csv, encoding: utf8);

                // Use captured instances after the async gap
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(AppLocalizations.t('export_success'))),
                );
              }
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailySalesDialog(List<Sale> sales, DateTime day) async {
    // Calculate totals
    double completedTotal = 0.0;
    double cancelledTotal = 0.0;
    int completedCount = 0;
    int cancelledCount = 0;
    for (final sale in sales) {
      if (sale.status == SaleStatus.completed) {
        completedTotal += sale.totalAmount;
        completedCount++;
      } else if (sale.status == SaleStatus.cancelled) {
        cancelledTotal += sale.totalAmount;
        cancelledCount++;
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Sales for ${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Completed Sales:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            AppCurrency.peso(completedTotal),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$completedCount transactions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (cancelledCount > 0) ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cancelled Sales:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Text(
                              AppCurrency.peso(cancelledTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.red.shade700,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$cancelledCount transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            AppCurrency.peso(completedTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Sales List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sales.length,
                  itemBuilder: (context, idx) {
                    final s = sales[idx];
                    final isCancelled = s.status == SaleStatus.cancelled;
                    return ListTile(
                      onTap: () => _showSaleDetailDialog(s),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sale #${s.saleNumber}',
                              style: TextStyle(
                                color: isCancelled ? Colors.red : null,
                                fontWeight: isCancelled
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                          if (isCancelled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
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
                                  fontSize: 9,
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
                            '${s.itemCount} items \u2022 ${s.formattedDate}\nCashier: ${s.cashierName}${isCancelled && s.cancelledReason != null ? "\nReason: ${s.cancelledReason}" : ""}',
                          ),
                          // Show shoe sizes if any
                          if (s.items.any((item) => item.shoeSize != null))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: s.items
                                    .where((item) => item.shoeSize != null)
                                    .map(
                                      (item) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '👟 ${item.productName} (${item.shoeSize})',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                      trailing: Text(
                        s.formattedTotal,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCancelled ? Colors.grey : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _exportCsv();
            },
            child: Text(AppLocalizations.t('export_csv')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _exportPdf();
            },
            child: Text(AppLocalizations.t('export_pdf')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    // Query database directly for the selected day
    final start = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final end = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      23,
      59,
      59,
      999,
    );
    final db = DatabaseService();
    final daySales = await db.getAllSales(startDate: start, endDate: end);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            AppLocalizations.t('daily_sales'),
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(_selectedDay.toIso8601String().substring(0, 10)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Date', 'Cashier', 'Items', 'Total'],
            data: [
              for (final s in daySales)
                [
                  s.saleNumber,
                  s.saleDate.toIso8601String(),
                  s.cashierName,
                  s.itemCount.toString(),
                  AppCurrency.php(s.totalAmount),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total: ${AppCurrency.php(_dailyTotal)}'),
          pw.Text('Transactions: $_dailyTransactions'),
          pw.Text('Average: ${AppCurrency.php(_dailyAverage)}'),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  @override
  void dispose() {
    pos.removeListener(_onPosChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      _range = picked;
      // reload sales for selected range
      final start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      final end = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
        999,
      );
      final sales = await pos.getSalesReport(startDate: start, endDate: end);
      // Calculate totals
      double completedTotal = 0.0;
      double cancelledTotal = 0.0;
      int completedCount = 0;
      int cancelledCount = 0;
      for (final sale in sales) {
        if (sale.status == SaleStatus.completed) {
          completedTotal += sale.totalAmount;
          completedCount++;
        } else if (sale.status == SaleStatus.cancelled) {
          cancelledTotal += sale.totalAmount;
          cancelledCount++;
        }
      }

      // update local range sales so UI list updates
      if (mounted) {
        setState(() => _rangeSales = sales);
        // show results in a dialog
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Sales Results (${sales.length} total)'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Summary Card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Completed Sales:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                AppCurrency.peso(completedTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$completedCount transactions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (cancelledCount > 0) ...[
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Cancelled Sales:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                Text(
                                  AppCurrency.peso(cancelledTotal),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.red.shade700,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$cancelledCount transactions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Net Total:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                AppCurrency.peso(completedTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sales List
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sales.length,
                      itemBuilder: (context, idx) {
                        final s = sales[idx];
                        final isCancelled = s.status == SaleStatus.cancelled;
                        return ListTile(
                          onTap: () => _showSaleDetailDialog(s),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Sale #${s.saleNumber}',
                                  style: TextStyle(
                                    color: isCancelled ? Colors.red : null,
                                    fontWeight: isCancelled
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ),
                              if (isCancelled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
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
                                      fontSize: 9,
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
                                '${s.itemCount} items • ${s.formattedDate}\nCashier: ${s.cashierName}${isCancelled && s.cancelledReason != null ? "\nReason: ${s.cancelledReason}" : ""}',
                              ),
                              // Show shoe sizes
                              if (s.items.any((item) => item.shoeSize != null))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: s.items
                                        .where((item) => item.shoeSize != null)
                                        .map(
                                          (item) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '👟 ${item.productName} (${item.shoeSize})',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Text(
                            s.formattedTotal,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCancelled ? Colors.grey : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _exportRangeCsv(sales, picked);
                },
                child: Text(AppLocalizations.t('export_csv')),
              ),
              TextButton(
                onPressed: () async {
                  await _exportRangePdf(sales, picked);
                },
                child: Text(AppLocalizations.t('export_pdf')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.t('close')),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _exportRangeCsv(List<Sale> sales, DateTimeRange range) async {
    String quoteIfNeeded(String v) {
      final needsQuote = v.contains(',') || v.contains('\n') || v.contains('"');
      if (!needsQuote) return v;
      return '"${v.replaceAll('"', '""')}"';
    }

    // Calculate totals
    double completedTotal = 0.0;
    double cancelledTotal = 0.0;
    int completedCount = 0;
    int cancelledCount = 0;
    for (final sale in sales) {
      if (sale.status == SaleStatus.completed) {
        completedTotal += sale.totalAmount;
        completedCount++;
      } else if (sale.status == SaleStatus.cancelled) {
        cancelledTotal += sale.totalAmount;
        cancelledCount++;
      }
    }

    final buffer = StringBuffer();
    buffer.write(String.fromCharCode(0xFEFF));
    buffer.writeln(
      'Sales Report - ${range.start.toIso8601String().substring(0, 10)} to ${range.end.toIso8601String().substring(0, 10)}',
    );
    buffer.writeln('');
    buffer.writeln(
      'SaleNumber,Date,Cashier,Items,Total,Status,Reference,Reason',
    );
    for (final s in sales) {
      final row = [
        quoteIfNeeded(s.saleNumber),
        quoteIfNeeded(s.saleDate.toIso8601String()),
        quoteIfNeeded(s.cashierName),
        quoteIfNeeded(s.itemCount.toString()),
        quoteIfNeeded(s.totalAmount.toStringAsFixed(2)),
        quoteIfNeeded(
          s.status == SaleStatus.completed ? 'Completed' : 'Cancelled',
        ),
        quoteIfNeeded(s.referenceCode ?? ''),
        quoteIfNeeded(s.cancelledReason ?? ''),
      ].join(',');
      buffer.writeln(row);
    }
    buffer.writeln('');
    buffer.writeln('Summary');
    buffer.writeln(
      'Completed Sales,$completedCount,${completedTotal.toStringAsFixed(2)}',
    );
    if (cancelledCount > 0) {
      buffer.writeln(
        'Cancelled Sales,$cancelledCount,${cancelledTotal.toStringAsFixed(2)}',
      );
    }
    buffer.writeln(
      'Net Total,$completedCount,${completedTotal.toStringAsFixed(2)}',
    );
    final csv = buffer.toString();
    final csvBytes = Uint8List.fromList(utf8.encode(csv));

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('export_csv')),
        content: SingleChildScrollView(child: SelectableText(csv)),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await Clipboard.setData(ClipboardData(text: csv));
              navigator.pop();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final fileName =
                  'sales_${range.start.toIso8601String().substring(0, 10)}_${range.end.toIso8601String().substring(0, 10)}.csv';
              final path = await FilePicker.saveFile(
                dialogTitle: 'Save CSV',
                fileName: fileName,
                type: FileType.custom,
                allowedExtensions: ['csv'],
                bytes: csvBytes,
              );
              if (path != null) {
                final file = File(path);
                await file.writeAsString(csv, encoding: utf8);
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(AppLocalizations.t('export_success'))),
                );
              }
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportRangePdf(List<Sale> sales, DateTimeRange range) async {
    // Calculate totals
    double completedTotal = 0.0;
    double cancelledTotal = 0.0;
    int completedCount = 0;
    int cancelledCount = 0;
    for (final sale in sales) {
      if (sale.status == SaleStatus.completed) {
        completedTotal += sale.totalAmount;
        completedCount++;
      } else if (sale.status == SaleStatus.cancelled) {
        cancelledTotal += sale.totalAmount;
        cancelledCount++;
      }
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            AppLocalizations.t('sales_reports'),
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${range.start.toIso8601String().substring(0, 10)} - ${range.end.toIso8601String().substring(0, 10)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Completed Sales',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    AppCurrency.php(completedTotal),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '$completedCount transactions',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (cancelledCount > 0)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Cancelled Sales',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      AppCurrency.php(cancelledTotal),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$cancelledCount transactions',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Date', 'Cashier', 'Items', 'Total', 'Status'],
            data: [
              for (final s in sales)
                [
                  s.saleNumber,
                  s.saleDate.toIso8601String().substring(0, 16),
                  s.cashierName,
                  s.itemCount.toString(),
                  AppCurrency.php(s.totalAmount),
                  s.status == SaleStatus.completed ? 'Completed' : 'CANCELLED',
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Net Total:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                AppCurrency.php(completedTotal),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Text(
            'Total Transactions: $completedCount completed${cancelledCount > 0 ? ", $cancelledCount cancelled" : ""}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    // Use range sales if a date range is selected, otherwise use all sales if searching, otherwise use recent sales
    final allSales = _range != null
        ? _rangeSales
        : (_searchQuery.isEmpty ? pos.recentSales : _allSales);

    // Debug: Log sales with shoe sizes
    if (allSales.isNotEmpty) {
      debugPrint('🔍 Sales Report: Displaying ${allSales.length} sales');
      int salesWithShoes = 0;
      for (final sale in allSales) {
        final hasShoes = sale.items.any((item) => item.shoeSize != null);
        if (hasShoes) {
          salesWithShoes++;
          debugPrint('   👟 Sale ${sale.saleNumber} has shoe items:');
          for (final item in sale.items.where((i) => i.shoeSize != null)) {
            debugPrint('      - ${item.productName} Size ${item.shoeSize}');
          }
        }
      }
      debugPrint(
        '   Total sales with shoes: $salesWithShoes/${allSales.length}',
      );
    }

    final sales = _searchQuery.isEmpty
        ? allSales
        : allSales
              .where(
                (s) =>
                    s.saleNumber.toLowerCase().contains(_searchQuery) ||
                    s.cashierName.toLowerCase().contains(_searchQuery) ||
                    (s.referenceCode != null &&
                        s.referenceCode!.toLowerCase().contains(_searchQuery)),
              )
              .toList();

    double total = 0;
    for (final s in sales) {
      if (s.status == SaleStatus.completed) total += s.totalAmount;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(AppLocalizations.t('sales_reports')),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.t('sales_report_tab')),
            Tab(text: AppLocalizations.t('financial_reports_tab')),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
          ),
          IconButton(
            onPressed: () => pos.loadRecentSales(days: 7),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Sales Report
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Date / Range banner below header (match Admin reports style)
                    Builder(
                      builder: (context) {
                        final primaryColor = Theme.of(
                          context,
                        ).colorScheme.primary;
                        final isDark =
                            primaryColor.toARGB32() == 0xFF6F4E37 ||
                            primaryColor.toARGB32() == 0xFF212121;
                        final dateFormat = DateFormat('MMM dd, yyyy');
                        final title = _range != null
                            ? '${dateFormat.format(_range!.start)} - ${dateFormat.format(_range!.end)}'
                            : dateFormat.format(_selectedDay);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[850]
                                : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DefaultTextStyle(
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                const SizedBox(width: 8),
                                Text(title),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _DailySummary(
                      loading: _loadingDaily,
                      total: _dailyTotal,
                      transferFees: _dailyTransferFees,
                      transactions: _dailyTransactions,
                      average: _dailyAverage,
                      selectedDay: _selectedDay,
                      onPickDay: _pickDailyDate,
                      onRefresh: () => _loadDailySummary(_selectedDay),
                      onExportCsv: _exportCsv,
                      onExportPdf: _exportPdf,
                    ),
                    const SizedBox(height: 8),
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search by sale number, cashier, or reference...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _loadingSearch
                                          ? 'Loading all sales...'
                                          : _searchQuery.isEmpty
                                          ? 'Showing ${sales.length} sales'
                                          : 'Found ${sales.length} of ${allSales.length} sales',
                                      style: TextStyle(color: null),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Card(
                                    elevation: 2,
                                    color: Colors.blue.shade50,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: 8.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Total',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Text(
                                            AppCurrency.peso(total),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ],
            body: _loadingSearch
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading all sales...'),
                      ],
                    ),
                  )
                : sales.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No sales yet'
                          : 'No sales found matching "$_searchQuery"',
                    ),
                  )
                : ListView.builder(
                    itemCount: sales.length,
                    itemBuilder: (context, idx) {
                      final s = sales[idx];
                      final isCancelled = s.status == SaleStatus.cancelled;
                      return ListTile(
                        leading: s.imagePath != null && s.imagePath!.isNotEmpty
                            ? const Icon(Icons.camera_alt, color: Colors.green)
                            : const Icon(Icons.receipt),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isCancelled
                                    ? 'Sale ${s.saleNumber} - Cancelled'
                                    : 'Sale ${s.saleNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isCancelled ? Colors.red : null,
                                ),
                              ),
                            ),
                            if (isCancelled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
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
                                    fontSize: 9,
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
                              '${s.itemCount} items • ${s.formattedDate}\nCashier: ${s.cashierName}${s.referenceCode != null ? "\nRef: ${s.referenceCode}" : ""}${isCancelled && s.cancelledReason != null ? "\nReason: ${s.cancelledReason}" : ""}',
                            ),
                            // Show shoe sizes if any items have them
                            if (s.items.any((item) => item.shoeSize != null))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: s.items
                                      .where((item) => item.shoeSize != null)
                                      .map(
                                        (item) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '👟 ${item.productName} (${item.shoeSize})',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(
                          s.formattedTotal,
                          style: TextStyle(
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCancelled ? Colors.grey : null,
                          ),
                        ),
                        onTap: () => _showSaleDetailDialog(s),
                      );
                    },
                  ),
          ),
          // Tab 2: Financial Reports
          _FinancialReportsTab(
            packageService: packageService,
            selectedDay: _financialDay,
            loading: _loadingFinancial,
            grossRevenue: _grossRevenue,
            netRevenue: _netRevenue,
            growthRate: _growthRate,
            operatingCosts: _operatingCosts,
            transferFees: _financialTransferFees,
            totalExpenses: _totalExpenses,
            grossProfit: _grossProfit,
            netProfit: _netProfit,
            profitMargin: _profitMargin,
            onPickDay: _pickFinancialDate,
            onRefresh: () => _loadFinancialData(_financialDay),
            onExportCsv: _exportFinancialCsv,
            onExportPdf: _exportFinancialPdf,
          ),
        ],
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  final bool loading;
  final double total;
  final double transferFees;
  final int transactions;
  final double average;
  final DateTime selectedDay;
  final VoidCallback onPickDay;
  final VoidCallback onRefresh;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  const _DailySummary({
    required this.loading,
    required this.total,
    required this.transferFees,
    required this.transactions,
    required this.average,
    required this.selectedDay,
    required this.onPickDay,
    required this.onRefresh,
    required this.onExportCsv,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.t('daily_sales'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.t('select_day'),
                  icon: const Icon(Icons.calendar_today),
                  onPressed: onPickDay,
                ),
                IconButton(
                  tooltip: AppLocalizations.t('refresh'),
                  icon: const Icon(Icons.refresh),
                  onPressed: loading ? null : onRefresh,
                ),
                IconButton(
                  tooltip: AppLocalizations.t('export_csv'),
                  icon: const Icon(Icons.table_chart),
                  onPressed: loading ? null : onExportCsv,
                ),
                IconButton(
                  tooltip: AppLocalizations.t('export_pdf'),
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: loading ? null : onExportPdf,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          AppLocalizations.t('today_total_sales'),
                          AppCurrency.peso(total),
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          AppLocalizations.t('today_transactions'),
                          '$transactions',
                          Icons.receipt_long,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          AppLocalizations.t('transfer_fee'),
                          AppCurrency.peso(transferFees),
                          Icons.payment,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          AppLocalizations.t('average_sale_value'),
                          AppCurrency.peso(average),
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension method for _SalesReportScreenState to show sale details
extension _SaleDetailDialog on _SalesReportScreenState {
  void _showSaleDetailDialog(Sale sale) {
    final isCancelled = sale.status == SaleStatus.cancelled;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Sale #${sale.saleNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${sale.formattedDate}'),
              Text('Cashier: ${sale.cashierName}'),
              Text('Payment: ${sale.paymentMethod.toUpperCase()}'),
              if (sale.referenceCode != null && sale.referenceCode!.isNotEmpty)
                Text('Reference: ${sale.referenceCode}'),
              if (isCancelled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CANCELLED',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sale.cancelledReason != null)
                        Text('Reason: ${sale.cancelledReason}'),
                      if (sale.cancelledBy != null)
                        Text('By: ${sale.cancelledBy}'),
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...sale.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (item.shoeSize != null)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Size ${item.shoeSize}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      dialogContext,
                                    ).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Text(
                              '${item.quantity} x ${AppCurrency.peso(item.unitPrice)}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        AppCurrency.peso(item.subtotal),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal:'),
                  Text(AppCurrency.peso(sale.subtotal)),
                ],
              ),
              if (sale.discountAmount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount:'),
                    Text('-${AppCurrency.peso(sale.discountAmount)}'),
                  ],
                ),
              if (sale.taxAmount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tax:'),
                    Text(AppCurrency.peso(sale.taxAmount)),
                  ],
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    AppCurrency.peso(sale.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCancelled ? Colors.red : null,
                    ),
                  ),
                ],
              ),
              // Show uploaded receipt image (if any)
              if (sale.imagePath != null && sale.imagePath!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Receipt Image',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
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
                    child: sale.imagePath != null
                        ? Image.file(File(sale.imagePath!), fit: BoxFit.cover)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CCTVScreen(timestamp: sale.saleDate),
                ),
              );
            },
            icon: Icon(Icons.videocam),
            label: Text('View CCTV'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
          if (!isCancelled)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showCancelSaleDialog(sale);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(AppLocalizations.t('cancel_sale')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCancelSaleDialog(Sale sale) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t('cancel_sale')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel sale #${sale.saleNumber}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total: ${sale.formattedTotal}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('cancellation_reason'),
                hintText: AppLocalizations.t('enter_cancellation_reason'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
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
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please provide a cancellation reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                // Get current user name (you may need to pass this from login)
                final cancelledBy = 'Owner'; // Or get from UserService

                // Update sale status
                final cancelledSale = sale.copyWith(
                  status: SaleStatus.cancelled,
                  cancelledReason: reason,
                  cancelledBy: cancelledBy,
                  cancelledAt: DateTime.now(),
                );

                await pos.databaseService.updateSale(cancelledSale);

                // Restore inventory for cancelled items
                for (final item in sale.items) {
                  final product = await pos.databaseService.getProductById(
                    item.productId,
                  );
                  if (product != null) {
                    final updatedProduct = product.copyWith(
                      quantity: product.quantity + item.quantity,
                    );
                    await pos.databaseService.updateProduct(updatedProduct);
                  }
                }

                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.t('sale_cancelled_successfully'),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );

                // Reload data
                _loadDailySummary(_selectedDay);
                if (_range != null) {
                  pos.loadRecentSales(days: 7);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error cancelling sale: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.t('confirm_cancellation')),
          ),
        ],
      ),
    );
  }
}

// Financial Reports Tab Widget
class _FinancialReportsTab extends StatelessWidget {
  final PackageService packageService;
  final DateTime selectedDay;
  final bool loading;
  final double grossRevenue;
  final double netRevenue;
  final double growthRate;
  final double operatingCosts;
  final double transferFees;
  final double totalExpenses;
  final double grossProfit;
  final double netProfit;
  final double profitMargin;
  final VoidCallback onPickDay;
  final VoidCallback onRefresh;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;

  const _FinancialReportsTab({
    required this.packageService,
    required this.selectedDay,
    required this.loading,
    required this.grossRevenue,
    required this.netRevenue,
    required this.growthRate,
    required this.operatingCosts,
    required this.transferFees,
    required this.totalExpenses,
    required this.grossProfit,
    required this.netProfit,
    required this.profitMargin,
    required this.onPickDay,
    required this.onRefresh,
    required this.onExportCsv,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final currentPackage =
        packageService.selectedPackage ??
        const PricingPackage(
          type: PackageType.basic,
          name: 'Basic',
          price: '₱0',
          period: '/month',
          description: 'Basic package',
          features: [],
          maxUsers: 2,
          maxProducts: 100,
          hasInventory: true,
          hasCCTV: false,
          hasReports: true,
          hasCloudSync: false,
          hasSupplierManagement: false,
          hasEWallet: false,
          hasMultiDevice: false,
          hasAdvancedAnalytics: false,
          hasPrioritySupport: false,
          hasAIHelp: false,
        );
    final hasAccess = currentPackage.name != 'Basic';

    if (!hasAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.t('financial_reports'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.t('available_in_standard'),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.t('upgrade_to_standard')),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: Text(AppLocalizations.t('upgrade_package')),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.t('financial_reports'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.t('select_date'),
                icon: const Icon(Icons.calendar_today),
                onPressed: onPickDay,
              ),
              IconButton(
                tooltip: AppLocalizations.t('refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: loading ? null : onRefresh,
              ),
              IconButton(
                tooltip: AppLocalizations.t('export_csv'),
                icon: const Icon(Icons.table_chart),
                onPressed: loading ? null : onExportCsv,
              ),
              IconButton(
                tooltip: AppLocalizations.t('export_pdf'),
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: loading ? null : onExportPdf,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            _buildFinancialCard(
              context,
              title: AppLocalizations.t('revenue_overview'),
              icon: Icons.trending_up,
              color: Colors.green,
              children: [
                _buildMetricRow(
                  AppLocalizations.t('gross_revenue'),
                  AppCurrency.peso(grossRevenue),
                ),
                _buildMetricRow(
                  AppLocalizations.t('net_revenue'),
                  AppCurrency.peso(netRevenue),
                ),
                _buildMetricRow(
                  AppLocalizations.t('growth_rate'),
                  '${growthRate >= 0 ? '+' : ''}${growthRate.toStringAsFixed(2)}%',
                  valueColor: growthRate >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFinancialCard(
              context,
              title: AppLocalizations.t('expenses'),
              icon: Icons.trending_down,
              color: Colors.red,
              children: [
                _buildMetricRow(
                  AppLocalizations.t('operating_costs'),
                  AppCurrency.peso(operatingCosts),
                ),
                _buildMetricRow(
                  AppLocalizations.t('transfer_fees'),
                  AppCurrency.peso(transferFees),
                ),
                _buildMetricRow(
                  AppLocalizations.t('total_expenses'),
                  AppCurrency.peso(totalExpenses),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFinancialCard(
              context,
              title: AppLocalizations.t('profit_analysis'),
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
              children: [
                _buildMetricRow(
                  AppLocalizations.t('gross_profit'),
                  AppCurrency.peso(grossProfit),
                ),
                _buildMetricRow(
                  AppLocalizations.t('net_profit'),
                  AppCurrency.peso(netProfit),
                ),
                _buildMetricRow(
                  AppLocalizations.t('profit_margin'),
                  '${profitMargin.toStringAsFixed(2)}%',
                  valueColor: profitMargin >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.t('financial_insights'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.t('revenue_explanation'),
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.t('expenses_explanation'),
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.t('profit_explanation'),
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
