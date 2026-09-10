class ExpenseRecord {
  final String id;
  final String category;
  final String description;
  final double amount;
  final double taxAmount;
  final DateTime expenseDate;
  final String? vendor;
  final String? referenceNo;

  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.taxAmount,
    required this.expenseDate,
    this.vendor,
    this.referenceNo,
  });

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return ExpenseRecord(
      id: '${map['id'] ?? ''}',
      category: '${map['category'] ?? 'Other'}',
      description: '${map['description'] ?? ''}',
      amount: asDouble(map['amount']),
      taxAmount: asDouble(map['tax_amount'] ?? map['taxAmount']),
      expenseDate: DateTime.tryParse('${map['expense_date'] ?? map['expenseDate']}') ??
          DateTime.now(),
      vendor: map['vendor']?.toString(),
      referenceNo: map['reference_no']?.toString() ?? map['referenceNo']?.toString(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'category': category,
        'description': description,
        'amount': amount,
        'taxAmount': taxAmount,
        'expenseDate': expenseDate.toIso8601String().substring(0, 10),
        if (vendor != null && vendor!.trim().isNotEmpty) 'vendor': vendor,
        if (referenceNo != null && referenceNo!.trim().isNotEmpty)
          'referenceNo': referenceNo,
      };
}
