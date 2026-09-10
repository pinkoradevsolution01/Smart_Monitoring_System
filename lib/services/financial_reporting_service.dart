import '../models/expense_record.dart';
import 'backend_api_service.dart';

/// Uses only the authenticated Smart Monitoring backend. No financial record
/// is written to a device database or sent with a client-controlled business ID.
class FinancialReportingService {
  FinancialReportingService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<ExpenseRecord>> getExpenses({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _api.get('expenses', queryParameters: _range(from, to));
    final raw = response['data'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => ExpenseRecord.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> addExpense(ExpenseRecord expense) async {
    await _api.post('expenses', body: expense.toCreateMap());
  }

  Future<void> deleteExpense(String id) async {
    await _api.deleteJson('expenses/$id');
  }

  Future<Map<String, dynamic>> getReport({
    required DateTime from,
    required DateTime to,
    double vatRate = 12,
  }) async {
    final response = await _api.get(
      'financial-reports/summary',
      queryParameters: {..._range(from, to), 'vatRate': '$vatRate'},
    );
    final data = response['data'];
    if (data is! Map) throw Exception('The financial report response was incomplete.');
    return Map<String, dynamic>.from(data);
  }

  Future<String> exportCsv({
    required DateTime from,
    required DateTime to,
    double vatRate = 12,
  }) => _api.getText(
        'financial-reports/export',
        queryParameters: {..._range(from, to), 'vatRate': '$vatRate'},
      );

  Map<String, String> _range(DateTime from, DateTime to) => {
        'from': _date(from),
        'to': _date(to),
      };

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
