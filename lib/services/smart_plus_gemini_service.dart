import 'backend_api_service.dart';

class SmartPlusGeminiException implements Exception {
  const SmartPlusGeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
  String? _modelsError;

  /// A safe, user-facing explanation if the model list cannot be loaded.
  /// This never contains backend secrets or provider response bodies.
  String? get modelsError => _modelsError;

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
        throw SmartPlusGeminiException(
          response['message']?.toString() ??
              'Gemini could not answer right now. Try again shortly or use Rule-based.',
        );
      }
      final answer = response['answer']?.toString().trim() ?? '';
      final meta = response['meta'];
      if (answer.isEmpty || meta is! Map) {
        throw const SmartPlusGeminiException(
          'Gemini returned no usable answer. Please try again or use Rule-based.',
        );
      }
      return SmartPlusGeminiReply(
        answer: answer,
        dateRange: meta['dateRange']?.toString() ?? 'Current available records',
        dataQuality: meta['dataQuality']?.toString() ?? 'Limited',
        model: meta['model']?.toString() ?? model,
      );
    } on SmartPlusGeminiException {
      rethrow;
    } catch (error) {
      throw SmartPlusGeminiException(_geminiErrorMessage(error));
    }
  }

  Future<List<SmartPlusChatModel>> availableModels() async {
    const local = SmartPlusChatModel(
      id: 'rule-based',
      label: 'Rule-based',
      description: 'Local, deterministic SmartPlus rules',
    );
    _modelsError = null;
    try {
      final response = await _api.get('smartplus/chat/models');
      final rawModels = response['models'];
      if (response['success'] != true || rawModels is! List) {
        _modelsError =
            'Gemini models are unavailable. Rule-based answers remain available.';
        return [local];
      }
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
      final result = models.any((model) => model.isRuleBased)
          ? models
          : [local, ...models];
      if (result.length == 1 && response['configured'] != true) {
        _modelsError =
            'Gemini is not configured on the secure server yet. Rule-based answers remain available.';
      }
      return result;
    } catch (error) {
      _modelsError = _geminiErrorMessage(error);
      return [local];
    }
  }

  String _geminiErrorMessage(Object error) {
    if (error is ApiException && error.statusCode == 503) {
      return error.message.isNotEmpty
          ? error.message
          : 'Gemini is temporarily unavailable. Please try again shortly or use Rule-based answers.';
    }
    if (error is ApiException && error.statusCode == 401) {
      return 'Your session expired. Sign in again to use Gemini.';
    }
    if (error is ApiException && error.statusCode == 403) {
      return 'Only the active business owner can use Gemini in SmartPlus.';
    }
    return safeApiError(error);
  }
}
