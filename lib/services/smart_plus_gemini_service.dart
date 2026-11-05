import 'backend_api_service.dart';

/// A backend-only Gemini reply. Flutter never receives or stores the Gemini
/// API key; the backend verifies the owner, tenant, and subscription first.
class SmartPlusGeminiReply {
  const SmartPlusGeminiReply({
    required this.answer,
    required this.dateRange,
    required this.dataQuality,
  });

  final String answer;
  final String dateRange;
  final String dataQuality;

  String get displayText =>
      'AI insight · Gemini\n'
      'Data source: tenant-scoped aggregate sales, inventory, and expense records\n'
      'Date range: $dateRange\n'
      'Data quality: $dataQuality\n'
      'Safety: review any recommendation before taking action. SmartPlus cannot change records automatically.\n\n'
      '$answer';
}

class SmartPlusGeminiService {
  SmartPlusGeminiService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Returns null when the secure backend cannot use Gemini, allowing the
  /// established local SmartPlus rules to continue working offline.
  Future<SmartPlusGeminiReply?> ask({
    required String question,
    required bool useFilipino,
  }) async {
    try {
      final response = await _api.post(
        'smartplus/chat',
        body: {'question': question, 'locale': useFilipino ? 'fil' : 'en'},
      );
      if (response['success'] != true || response['provider'] != 'gemini') {
        return null;
      }
      final answer = response['answer']?.toString().trim() ?? '';
      final meta = response['meta'];
      if (answer.isEmpty || meta is! Map) return null;
      return SmartPlusGeminiReply(
        answer: answer,
        dateRange: meta['dateRange']?.toString() ?? 'Current available records',
        dataQuality: meta['dataQuality']?.toString() ?? 'Limited',
      );
    } catch (_) {
      return null;
    }
  }
}
