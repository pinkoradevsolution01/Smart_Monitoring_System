// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/pos_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/currency_formatter.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../models/damage_report.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final POSService _posService = GetIt.I<POSService>();
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<Sale> _sales = [];
  List<Product> _products = [];
  List<DamageReport> _damageReports = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint(
        '📊 Loading admin reports: ${_startDate.toIso8601String()} to ${_endDate.toIso8601String()}',
      );
      final sales = await _dbService.getSalesByDateRange(_startDate, _endDate);
      debugPrint('📊 Found ${sales.length} sales in date range');
      for (var sale in sales) {
        debugPrint(
          '   - ${sale.saleNumber} | ${sale.paymentMethod} | ₱${sale.totalAmount} | ${sale.saleDate}',
        );
      }
      final damageReports = await _dbService.getDamageReportsByDateRange(
        _startDate,
        _endDate,
      );
      await _posService.loadProducts();
      setState(() {
        _sales = sales;
        _products = _posService.products;
        _damageReports = damageReports;
      });
    } catch (e) {
      debugPrint('❌ Error loading admin reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _resetSalesData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sales Data'),
        content: const Text(
          'This will delete ALL sales records permanently. This action cannot be undone.\n\nProducts and inventory will not be affected.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Sales'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbService.resetSalesData();
        await _posService.loadRecentSales(days: 7);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sales data has been reset successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Reload to show empty data
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting sales: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(AppLocalizations.t('reports')),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: AppLocalizations.t('select_date_range'),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.t('refresh'),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Reset Sales Data',
            onPressed: _resetSalesData,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: AppLocalizations.t('export_csv'),
            onPressed: _exportSalesCsv,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: AppLocalizations.t('export_pdf'),
            onPressed: _exportSalesPdf,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.monetization_on),
              text: AppLocalizations.t('sales_report'),
            ),
            Tab(
              icon: const Icon(Icons.inventory_2),
              text: AppLocalizations.t('inventory_report'),
            ),
            Tab(
              icon: const Icon(Icons.list_alt),
              text: AppLocalizations.t('activity_logs'),
            ),
            Tab(
              icon: const Icon(Icons.report_problem),
              text: AppLocalizations.t('damage_reports'),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateRangeHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSalesReportTab(),
                      _buildInventoryReportTab(),
                      _buildActivityLogsTab(),
                      _buildDamageReportsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _exportSalesCsv() async {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Calculate totals
    double completedTotal = 0.0;
    double cancelledTotal = 0.0;
    int completedCount = 0;
    int cancelledCount = 0;
    for (final sale in _sales) {
      if (sale.status == SaleStatus.completed) {
        completedTotal += sale.totalAmount;
        completedCount++;
      } else if (sale.status == SaleStatus.cancelled) {
        cancelledTotal += sale.totalAmount;
        cancelledCount++;
      }
    }

    final buffer = StringBuffer();
    buffer.write(String.fromCharCode(0xFEFF)); // UTF-8 BOM
    buffer.writeln(
      'Sales Report - ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}',
    );
    buffer.writeln('');
    buffer.writeln(
      'SaleNumber,Date,Cashier,Items,Total,Status,PaymentMethod,Reference',
    );
    for (final s in _sales) {
      buffer.writeln(
        '${s.saleNumber},${dateFmt.format(s.saleDate)},${s.cashierName},${s.itemCount},${s.totalAmount.toStringAsFixed(2)},${s.status == SaleStatus.completed ? "Completed" : "Cancelled"},${s.paymentMethod},${s.referenceCode ?? ""}',
      );
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
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.t('export_csv')),
        content: SingleChildScrollView(child: SelectableText(csv)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSalesPdf() async {
    final dateTitle =
        '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}';

    // Calculate totals
    double completedTotal = 0.0;
    double cancelledTotal = 0.0;
    int completedCount = 0;
    int cancelledCount = 0;
    for (final sale in _sales) {
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
            AppLocalizations.t('sales_report'),
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(dateTitle),
          pw.SizedBox(height: 16),
          // Summary Section
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
            headers: ['#', 'Date', 'Cashier', 'Items', 'Total (PHP)', 'Status'],
            data: [
              for (final s in _sales)
                [
                  s.saleNumber,
                  DateFormat('yyyy-MM-dd HH:mm').format(s.saleDate),
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
            'Total: $completedCount completed${cancelledCount > 0 ? ", $cancelledCount cancelled" : ""}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  Widget _buildDateRangeHeader() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark =
        primaryColor.toARGB32() == 0xFF6F4E37 ||
        primaryColor.toARGB32() == 0xFF212121;
    final dateFormat = DateFormat('MMM dd, yyyy');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[850]
            : Theme.of(context).colorScheme.primaryContainer,
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
            Text(
              '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesReportTab() {
    final activeSales = _sales
        .where((s) => s.status != SaleStatus.cancelled)
        .toList();
    final totalSales = activeSales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final totalTransactions = activeSales.length;
    final avgTransaction = totalTransactions > 0
        ? totalSales / totalTransactions
        : 0;

    // Calculate transfer fees from e-wallet transactions
    double transferFees = 0.0;
    debugPrint(
      '📊 Admin: Calculating transfer fees from ${activeSales.length} sales',
    );
    int ewalletCount = 0;
    for (final sale in activeSales) {
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
      '📊 Admin: Found $ewalletCount e-wallet sales with total transfer fees: ${AppCurrency.peso(transferFees)}',
    );

    // Group sales by date
    final salesByDate = <String, double>{};
    for (var sale in activeSales) {
      final dateKey = DateFormat('MMM dd').format(sale.saleDate);
      salesByDate[dateKey] = (salesByDate[dateKey] ?? 0) + sale.totalAmount;
    }

    // Top selling products
    final productSales = <String, Map<String, dynamic>>{};
    for (var sale in activeSales) {
      for (var item in sale.items) {
        if (!productSales.containsKey(item.productName)) {
          productSales[item.productName] = {'quantity': 0, 'revenue': 0.0};
        }
        productSales[item.productName]!['quantity'] += item.quantity;
        productSales[item.productName]!['revenue'] += item.subtotal;
      }
    }

    final topProducts = productSales.entries.toList()
      ..sort(
        (a, b) => (b.value['revenue'] as double).compareTo(
          a.value['revenue'] as double,
        ),
      );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                AppLocalizations.t('total_sales'),
                AppCurrency.peso(totalSales),
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                AppLocalizations.t('transactions'),
                '$totalTransactions',
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
                AppLocalizations.t('transfer_fee'),
                AppCurrency.peso(transferFees),
                Icons.payment,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                AppLocalizations.t('avg_transaction'),
                AppCurrency.peso(avgTransaction),
                Icons.trending_up,
                Colors.purple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Sales Chart
        if (salesByDate.isNotEmpty) ...[
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t('sales_trend'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(height: 200, child: _buildSalesChart(salesByDate)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Top Products
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('top_selling_products'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Divider(height: 24),
                if (topProducts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        AppLocalizations.t('no_sales_data'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ...topProducts.take(10).map((entry) {
                    final name = entry.key;
                    final quantity = entry.value['quantity'];
                    final revenue = entry.value['revenue'] as double;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${topProducts.indexOf(entry) + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '${AppLocalizations.t('quantity')}: $quantity',
                      ),
                      trailing: Text(
                        AppCurrency.peso(revenue),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Recent Transactions
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('recent_transactions'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Divider(height: 24),
                if (_sales.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        AppLocalizations.t('no_transactions'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ..._sales.take(10).map((sale) {
                    final isCancelled = sale.status == SaleStatus.cancelled;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isCancelled
                                  ? '${sale.saleNumber} - Cancelled'
                                  : sale.saleNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isCancelled ? Colors.red : Colors.black,
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
                      subtitle: Text(
                        '${DateFormat('MMM dd, yyyy HH:mm').format(sale.saleDate)} • ${sale.cashierName}${sale.referenceCode != null ? "\nRef: ${sale.referenceCode}" : ""}${isCancelled && sale.cancelledReason != null ? "\nReason: ${sale.cancelledReason}" : ""}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppCurrency.peso(sale.totalAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCancelled ? Colors.grey : null,
                            ),
                          ),
                          Text(
                            '${sale.itemCount} ${AppLocalizations.t('items')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryReportTab() {
    final totalProducts = _products.length;
    final lowStockProducts = _products.where((p) => p.lowStock).toList();
    final outOfStockProducts = _products.where((p) => p.quantity == 0).toList();
    final totalValue = _products.fold<double>(
      0,
      (sum, p) => sum + (p.buyingPrice * p.quantity),
    );

    // Category breakdown
    final categoryStats = <String, Map<String, dynamic>>{};
    for (var product in _products) {
      if (!categoryStats.containsKey(product.category)) {
        categoryStats[product.category] = {
          'count': 0,
          'value': 0.0,
          'quantity': 0,
        };
      }
      categoryStats[product.category]!['count'] += 1;
      categoryStats[product.category]!['value'] +=
          product.buyingPrice * product.quantity;
      categoryStats[product.category]!['quantity'] += product.quantity;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                AppLocalizations.t('total_products'),
                '$totalProducts',
                Icons.inventory_2,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                AppLocalizations.t('inventory_value'),
                AppCurrency.peso(totalValue),
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                AppLocalizations.t('low_stock_alert'),
                '${lowStockProducts.length}',
                Icons.warning_amber,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                AppLocalizations.t('out_of_stock'),
                '${outOfStockProducts.length}',
                Icons.remove_circle,
                Colors.red,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Category Breakdown
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('inventory_by_category'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Divider(height: 24),
                if (categoryStats.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        AppLocalizations.t('no_products'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ...categoryStats.entries.map((entry) {
                    final category = entry.key;
                    final count = entry.value['count'];
                    final value = entry.value['value'] as double;
                    final quantity = entry.value['quantity'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          child: const Icon(
                            Icons.category,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '$count ${AppLocalizations.t('products')} • ${AppLocalizations.t('quantity')}: $quantity',
                        ),
                        trailing: Text(
                          AppCurrency.peso(value),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Low Stock Alert
        if (lowStockProducts.isNotEmpty) ...[
          Card(
            elevation: 2,
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.t('low_stock_alert'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...lowStockProducts.map((product) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.inventory,
                        color: Colors.orange,
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '${AppLocalizations.t('category')}: ${product.category}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${AppLocalizations.t('stock')}: ${product.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            '${AppLocalizations.t('reorder_level')}: ${product.reorderLevel}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Out of Stock
        if (outOfStockProducts.isNotEmpty) ...[
          Card(
            elevation: 2,
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_circle, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.t('out_of_stock'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...outOfStockProducts.map((product) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '${AppLocalizations.t('category')}: ${product.category}',
                      ),
                      trailing: const Text(
                        '0',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityLogsTab() {
    // Combine sales with product changes for activity log
    final activities = <Map<String, dynamic>>[];

    // Add sales activities
    for (var sale in _sales) {
      activities.add({
        'type': 'sale',
        'icon': Icons.point_of_sale,
        'color': Colors.green,
        'title': '${AppLocalizations.t('sale')} ${sale.saleNumber}',
        'subtitle':
            '${sale.cashierName} • ${sale.itemCount} ${AppLocalizations.t('items')}',
        'amount': AppCurrency.peso(sale.totalAmount),
        'date': sale.saleDate,
      });
    }

    // Sort by date (most recent first)
    activities.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.t('system_activity'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (activities.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        AppLocalizations.t('no_activity'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ...activities.take(50).map((activity) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: activity['color'],
                          child: Icon(
                            activity['icon'],
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          activity['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activity['subtitle']),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'MMM dd, yyyy HH:mm:ss',
                              ).format(activity['date']),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          activity['amount'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: activity['color'],
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Activity Summary
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('activity_summary'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  AppLocalizations.t('total_activities'),
                  '${activities.length}',
                  Icons.list_alt,
                ),
                _buildSummaryRow(
                  AppLocalizations.t('sales_transactions'),
                  '${_sales.length}',
                  Icons.point_of_sale,
                ),
                _buildSummaryRow(
                  AppLocalizations.t('date_range'),
                  '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}',
                  Icons.date_range,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(Map<String, double> salesByDate) {
    if (salesByDate.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.t('no_data_available'),
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final entries = salesByDate.entries.toList();
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  AppCurrency.peso(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      entries[index].key,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: entries
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        minY: 0,
        maxY: maxY * 1.2,
      ),
    );
  }

  Widget _buildDamageReportsTab() {
    // Calculate total value lost (only pending damages)
    final totalDamageValue = _damageReports
        .where((r) => r.paymentStatus == null && r.returnStatus == null)
        .fold<double>(0, (sum, report) => sum + report.totalValue);
    // Calculate total damaged items (only pending damages)
    final totalQuantity = _damageReports
        .where((r) => r.paymentStatus == null && r.returnStatus == null)
        .fold<int>(0, (sum, report) => sum + report.quantity);

    // Calculate paid and returned statistics
    final paidReports = _damageReports
        .where((r) => r.paymentStatus == 'paid')
        .toList();
    final returnedReports = _damageReports
        .where((r) => r.returnStatus == 'returned')
        .toList();
    final pendingReports = _damageReports
        .where((r) => r.paymentStatus == null && r.returnStatus == null)
        .toList();

    final paidValue = paidReports.fold<double>(
      0,
      (sum, r) => sum + r.totalValue,
    );
    final returnedValue = returnedReports.fold<double>(
      0,
      (sum, r) => sum + r.totalValue,
    );
    final pendingValue = pendingReports.fold<double>(
      0,
      (sum, r) => sum + r.totalValue,
    );

    return _damageReports.isEmpty
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
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.t('total_damaged_items'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalQuantity',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.t('total_value_lost'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppCurrency.php(totalDamageValue),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Payment Status Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.payment,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.t('store_damage_paid'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${paidReports.length}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                AppCurrency.php(paidValue),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.t('returned'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${returnedReports.length}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                AppCurrency.php(returnedValue),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.pending,
                                    color: Colors.red.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Pending',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${pendingReports.length}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              Text(
                                AppCurrency.php(pendingValue),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Export Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportDamageCsv,
                        icon: const Icon(Icons.table_chart),
                        label: Text(AppLocalizations.t('export_csv')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportDamagePdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(AppLocalizations.t('export_pdf')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Damage Reports List
                Text(
                  '${AppLocalizations.t('damage_reports')} (${_damageReports.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _damageReports.length,
                  itemBuilder: (context, index) {
                    final report = _damageReports[index];
                    final bool isReturned = report.returnStatus == 'returned';
                    final bool isPaid = report.paymentStatus == 'paid';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
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
                              '${AppLocalizations.t('quantity')}: ${report.quantity} | ${AppLocalizations.t('value')}: ${AppCurrency.php(report.totalValue)}',
                            ),
                            if (report.reason.isNotEmpty &&
                                report.reason != 'No reason provided')
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
                                '${AppLocalizations.t('return_date')}: ${DateFormat('MMM dd, yyyy').format(report.returnDate!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (isPaid && report.paymentDate != null)
                              Text(
                                '${AppLocalizations.t('payment_date')}: ${DateFormat('MMM dd, yyyy').format(report.paymentDate!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (isPaid && report.responsiblePerson != null)
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
                              DateFormat('MMM dd').format(report.reportDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(report.reportDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
  }

  Future<void> _exportDamageCsv() async {
    final buffer = StringBuffer();
    // Add UTF-8 BOM
    buffer.write('\uFEFF');
    buffer.writeln(
      '"Date","Product","Quantity","Unit Price","Total Value","Status","Payment Date","Responsible Person","Reason","Reported By"',
    );

    for (final report in _damageReports) {
      final date = DateFormat('yyyy-MM-dd HH:mm').format(report.reportDate);
      final product = report.productName.replaceAll('"', '""');
      final reason = report.reason.replaceAll('"', '""');
      final reportedBy = report.reportedBy.replaceAll('"', '""');

      final status = report.paymentStatus == 'paid'
          ? 'Store Damage Paid'
          : report.returnStatus == 'returned'
          ? 'Returned'
          : 'Pending';

      final paymentDate = report.paymentDate != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(report.paymentDate!)
          : report.returnDate != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(report.returnDate!)
          : '-';

      final responsiblePerson =
          report.responsiblePerson?.replaceAll('"', '""') ?? '-';

      buffer.writeln(
        '"$date","$product","${report.quantity}","${report.unitPrice.toStringAsFixed(2)}","${report.totalValue.toStringAsFixed(2)}","$status","$paymentDate","$responsiblePerson","$reason","$reportedBy"',
      );
    }

    final csv = buffer.toString();

    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppLocalizations.t('export_csv')),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(csv)),
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
  }

  Future<void> _exportDamagePdf() async {
    final dateTitle =
        '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}';
    final doc = pw.Document();

    final totalValue = _damageReports.fold<double>(
      0,
      (sum, r) => sum + r.totalValue,
    );
    final totalQty = _damageReports.fold<int>(0, (sum, r) => sum + r.quantity);

    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            AppLocalizations.t('damage_reports'),
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(dateTitle),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text(
                    AppLocalizations.t('total_damaged_items'),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '$totalQty',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text(
                    AppLocalizations.t('total_value_lost'),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    AppCurrency.php(totalValue),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Product',
              'Qty',
              'Value',
              'Reason',
              'Reported By',
            ],
            data: [
              for (final report in _damageReports)
                [
                  DateFormat('yyyy-MM-dd HH:mm').format(report.reportDate),
                  report.productName,
                  report.quantity.toString(),
                  AppCurrency.php(report.totalValue),
                  report.reason.isEmpty || report.reason == 'No reason provided'
                      ? '-'
                      : report.reason,
                  report.reportedBy,
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name:
          'damage_reports_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
