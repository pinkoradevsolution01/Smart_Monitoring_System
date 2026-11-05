import 'backend_api_service.dart';

/// A backend-only Gemini reply. Flutter never receives or stores the Gemini
/// API key; the backend verifies the owner, tenant, and subscription first.
class SmartPlusGeminiReply {
  const SmartPlusGeminiReply({
    required this.answer,
    required this.dateRange,
    required this.dataQuality,
    required this.model,
  });

  final String answer;
  final String dateRange;
  final String dataQuality;
  final String model;

  String get displayText =>
      'AI insight · Gemini\n'
      'Data source: tenant-scoped aggregate sales, inventory, and expense records\n'
      'Date range: $dateRange\n'
      'Data quality: $dataQuality\n'
      'Safety: review any recommendation before taking action. SmartPlus cannot change records automatically.\n\n'
      '$answer';
}

class SmartPlusChatModel {
  const SmartPlusChatModel({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  bool get isRuleBased => id == 'rule-based';
}

class SmartPlusGeminiService {
  SmartPlusGeminiService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Returns null when the secure backend cannot use Gemini, allowing the
  /// established local SmartPlus rules to continue working offline.
  Future<SmartPlusGeminiReply?> ask({
    required String question,
    required bool useFilipino,
    required String model,
  }) async {
    try {
      final response = await _api.post(
        'smartplus/chat',
        body: {
          'question': question,
          'locale': useFilipino ? 'fil' : 'en',
          'model': model,
        },
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
        model: model,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<SmartPlusChatModel>> availableModels() async {
    const local = SmartPlusChatModel(
      id: 'rule-based',
      label: 'Rule-based',
      description: 'Local, deterministic SmartPlus rules',
    );
    try {
      final response = await _api.get('smartplus/chat/models');
      final rawModels = response['models'];
      if (response['success'] != true || rawModels is! List) return [local];
      final models = rawModels
          .whereType<Map>()
          .map(
            (item) => SmartPlusChatModel(
              id: item['id']?.toString() ?? '',
              label: item['label']?.toString() ?? '',
              description: item['description']?.toString() ?? '',
            ),
          )
          .where((model) => model.id.isNotEmpty && model.label.isNotEmpty)
          .toList(growable: false);
      return models.any((model) => model.isRuleBased)
          ? models
          : [local, ...models];
    } catch (_) {
      return [local];
    }
  }
}
