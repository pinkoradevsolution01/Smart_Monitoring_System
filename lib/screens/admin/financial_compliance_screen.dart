import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/expense_record.dart';
import '../../services/financial_reporting_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_design_system.dart';

/// Standard/Premium financial workspace. All values are loaded from the
/// authenticated backend; no business ID is accepted from this screen.
class FinancialComplianceScreen extends StatefulWidget {
  const FinancialComplianceScreen({super.key});

  @override
  State<FinancialComplianceScreen> createState() =>
      _FinancialComplianceScreenState();
}

class _FinancialComplianceScreenState extends State<FinancialComplianceScreen> {
  final FinancialReportingService _service = FinancialReportingService();
  late DateTime _from;
  late DateTime _to;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  List<ExpenseRecord> _expenses = const [];
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _service.getExpenses(from: _from, to: _to),
        _service.getReport(from: _from, to: _to),
      ]);
      if (!mounted) return;
      setState(() {
        _expenses = values[0] as List<ExpenseRecord>;
        _report = values[1] as Map<String, dynamic>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('Standard, Premium, or Enterprise')) return message;
    return 'Could not load financial data. Check your secure backend connection and try again.';
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (selected == null) return;
    setState(() {
      _from = selected.start;
      _to = selected.end;
    });
    await _load();
  }

  Future<void> _addExpense() async {
    final result = await showDialog<ExpenseRecord>(
      context: context,
      builder: (_) => _AddExpenseDialog(initialDate: _to),
    );
    if (result == null) return;
    try {
      await _service.addExpense(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved to the secure business record.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error)), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _deleteExpense(ExpenseRecord expense) async {
    final confirmed = await showAppDestructiveConfirmation(
      context,
      title: 'Delete expense?',
      message: '${expense.description} will be removed from this business only.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await _service.deleteExpense(expense.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error)), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _copyCsv() async {
    setState(() => _exporting = true);
    try {
      final csv = await _service.exportCsv(from: _from, to: _to);
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BIR-ready CSV copied. Paste it into Excel or your filing workbook.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error)), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial & BIR-ready reports'),
        actions: [
          IconButton(
            tooltip: 'Choose date range',
            onPressed: _loading ? null : _pickRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Copy CSV export',
            onPressed: _loading || _exporting ? null : _copyCsv,
            icon: _exporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            AppPageHeader(
              title: 'Profit and reporting',
              subtitle: '${_date(_from)} – ${_date(_to)} · Standard/Premium workspace',
              breadcrumbs: const ['Reports', 'Financial'],
              action: OutlinedButton.icon(
                onPressed: _loading ? null : _pickRange,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Date range'),
              ),
            ),
            const SizedBox(height: 16),
            _NoticeCard(),
            const SizedBox(height: 16),
            if (_loading)
              const _LoadingState()
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _load)
            else if (report != null) ...[
              _ProfitCards(report: report),
              const SizedBox(height: 20),
              _ZReadingCard(reading: _map(report['zReading'])),
              const SizedBox(height: 16),
              _VatCard(summary: _map(report['vatSummary'])),
              const SizedBox(height: 24),
              _ExpenseSection(expenses: _expenses, onDelete: _deleteExpense),
              const SizedBox(height: 24),
              _ESalesSection(sales: _maps(report['eSales'])),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList()
    : const <Map<String, dynamic>>[];

double _amount(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class _NoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'These are review-ready operational summaries. Confirm tax treatment, invoices, and BIR filing requirements with your registered POS/invoicing records and tax adviser before filing.',
                ),
              ),
            ],
          ),
        ),
      );
}

class _ProfitCards extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ProfitCards({required this.report});

  @override
  Widget build(BuildContext context) {
    final profit = _map(report['profitAnalysis']);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 4 : constraints.maxWidth >= 500 ? 2 : 1;
        final cards = [
          ('Net sales', _amount(profit['netSales']), Icons.payments_outlined, Theme.of(context).colorScheme.primary),
          ('Cost of goods', _amount(profit['estimatedCostOfGoods']), Icons.inventory_2_outlined, Colors.orange),
          ('Expenses', _amount(profit['operatingExpenses']), Icons.receipt_long_outlined, Colors.redAccent),
          ('Estimated profit', _amount(profit['estimatedProfit']), Icons.trending_up_outlined, Colors.green),
        ];
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.2 : 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards
              .map((card) => AppMetricCard(
                    label: card.$1,
                    value: AppCurrency.peso(card.$2),
                    icon: card.$3,
                    color: card.$4,
                    detail: card.$1 == 'Estimated profit' ? 'Sales less recorded costs' : 'Selected date range',
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ZReadingCard extends StatelessWidget {
  final Map<String, dynamic> reading;
  const _ZReadingCard({required this.reading});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Z-reading summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _AmountLine(label: 'Completed transactions', value: '${reading['completedTransactions'] ?? 0}'),
            _AmountLine(label: 'Cancelled transactions', value: '${reading['cancelledTransactions'] ?? 0}'),
            _AmountLine(label: 'Gross sales', value: AppCurrency.peso(_amount(reading['grossSales']))),
            _AmountLine(label: 'Discounts', value: AppCurrency.peso(_amount(reading['discounts']))),
            _AmountLine(label: 'Net sales', value: AppCurrency.peso(_amount(reading['netSales'])), emphasized: true),
          ]),
        ),
      );
}

class _VatCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _VatCard({required this.summary});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VAT summary (estimated)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _AmountLine(label: 'VAT rate', value: '${_amount(summary['ratePercent']).toStringAsFixed(0)}%'),
            _AmountLine(label: 'Estimated taxable sales', value: AppCurrency.peso(_amount(summary['estimatedTaxableSales']))),
            _AmountLine(label: 'Estimated output VAT', value: AppCurrency.peso(_amount(summary['estimatedOutputVat']))),
            _AmountLine(label: 'Recorded input VAT', value: AppCurrency.peso(_amount(summary['recordedInputVat']))),
            _AmountLine(label: 'Estimated VAT payable', value: AppCurrency.peso(_amount(summary['estimatedVatPayable'])), emphasized: true),
          ]),
        ),
      );
}

class _AmountLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  const _AmountLine({required this.label, required this.value, this.emphasized = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

class _ExpenseSection extends StatelessWidget {
  final List<ExpenseRecord> expenses;
  final ValueChanged<ExpenseRecord> onDelete;
  const _ExpenseSection({required this.expenses, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Expense tracking', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Supplies, utilities, rent, and other recorded operating costs.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No expenses recorded for this date range.')),
              )
            else
              ...expenses.map((expense) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Icon(_expenseIcon(expense.category))),
                    title: Text(expense.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${expense.category} · ${expense.expenseDate.month}/${expense.expenseDate.day}/${expense.expenseDate.year}${expense.vendor?.isNotEmpty == true ? ' · ${expense.vendor}' : ''}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(AppCurrency.peso(expense.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(tooltip: 'Delete expense', onPressed: () => onDelete(expense), icon: const Icon(Icons.delete_outline)),
                    ]),
                  )),
          ]),
        ),
      );
}

IconData _expenseIcon(String category) => switch (category.toLowerCase()) {
      'supplies' => Icons.inventory_2_outlined,
      'utilities' => Icons.bolt_outlined,
      'rent' => Icons.storefront_outlined,
      'payroll' => Icons.groups_outlined,
      _ => Icons.receipt_long_outlined,
    };

class _ESalesSection extends StatelessWidget {
  final List<Map<String, dynamic>> sales;
  const _ESalesSection({required this.sales});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('eSales detail', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${sales.length} completed transaction${sales.length == 1 ? '' : 's'} in the selected range.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (sales.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No completed sales for this range.')))
            else
              ...sales.map((sale) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${sale['reference_code'] ?? sale['id'] ?? 'Sale'}'),
                    subtitle: Text('${sale['datetime'] ?? ''} · ${sale['payment_method'] ?? 'Payment not recorded'}'),
                    trailing: Text(AppCurrency.peso(_amount(sale['total_amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                  )),
          ]),
        ),
      );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.lock_outline, size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
}

class _AddExpenseDialog extends StatefulWidget {
  final DateTime initialDate;
  const _AddExpenseDialog({required this.initialDate});
  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _tax = TextEditingController(text: '0');
  final _vendor = TextEditingController();
  final _reference = TextEditingController();
  String _category = 'Supplies';
  late DateTime _date;

  @override
  void initState() { super.initState(); _date = widget.initialDate; }
  @override
  void dispose() { _description.dispose(); _amount.dispose(); _tax.dispose(); _vendor.dispose(); _reference.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add expense'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const ['Supplies', 'Utilities', 'Rent', 'Payroll', 'Delivery', 'Other']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), validator: (value) => value == null || value.trim().isEmpty ? 'Description is required.' : null),
                TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (value) => (double.tryParse(value ?? '') ?? 0) > 0 ? null : 'Enter an amount greater than zero.'),
                TextFormField(controller: _tax, decoration: const InputDecoration(labelText: 'Input VAT / tax amount (optional)', prefixText: '₱ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (value) => (double.tryParse(value ?? '0') ?? -1) >= 0 ? null : 'Enter zero or a positive amount.'),
                TextFormField(controller: _vendor, decoration: const InputDecoration(labelText: 'Vendor (optional)')),
                TextFormField(controller: _reference, decoration: const InputDecoration(labelText: 'Receipt/reference no. (optional)')),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _date);
                      if (selected != null) setState(() => _date = selected);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Date: ${_date.month}/${_date.day}/${_date.year}'),
                  ),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, ExpenseRecord(
                id: '', category: _category, description: _description.text.trim(), amount: double.parse(_amount.text),
                taxAmount: double.tryParse(_tax.text) ?? 0, expenseDate: _date,
                vendor: _vendor.text.trim(), referenceNo: _reference.text.trim(),
              ));
            },
            child: const Text('Save expense'),
          ),
        ],
      );
}
