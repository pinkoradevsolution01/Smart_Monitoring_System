import 'backend_api_service.dart';
import 'smart_plus_notification_service.dart';

/// Calls the tenant-scoped SmartPlus action workflow. The API derives the
/// business and owner from the verified session; this class never sends a
/// business ID and never changes a POS record locally.
class SmartPlusActionService {
  SmartPlusActionService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<SmartPlusActionDraft>> listDrafts() async {
    final response = await _api.get('smartplus/actions');
    final raw = response['actions'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              SmartPlusActionDraft.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<SmartPlusActionDraft> approve(String id) async {
    final response = await _api.post('smartplus/actions/$id/approve');
    return SmartPlusActionDraft.fromMap(
      Map<String, dynamic>.from(response['action'] as Map),
    );
  }

  Future<SmartPlusActionDraft> execute(String id) async {
    final response = await _api.post('smartplus/actions/$id/execute');
    return SmartPlusActionDraft.fromMap(
      Map<String, dynamic>.from(response['action'] as Map),
    );
  }

  Future<void> draftAction(
    SmartPlusNotification notification, {
    required String actionType,
  }) async {
    final isBoundReorder =
        actionType == 'reorder' && notification.draftProposal != null;
    await _api.post(
      'smartplus/actions',
      body: {
        'actionType': actionType,
        'title': '${_actionLabel(actionType)}: ${notification.title}',
        'proposal': isBoundReorder
            ? notification.draftProposal!
            : {
                'recommendedNextStep': notification.proposedAction,
                'recordTarget': notification.recordTarget?.name,
              },
        'evidence': {
          'label': notification.insightKind.name,
          'sourceData': notification.sourceData,
          'dataRange': notification.dataRange,
          'dataQuality': notification.dataQuality.name,
          'confidence': notification.confidence,
          'why': notification.why,
          'message': notification.message,
        },
      },
    );
  }

  String _actionLabel(String value) => switch (value) {
    'reorder' => 'Reorder proposal',
    'price_change_proposal' => 'Price-change proposal',
    'supplier_message' => 'Supplier message draft',
    'promotion' => 'Promotion proposal',
    _ => 'Staff follow-up',
  };
}

class SmartPlusActionDraft {
  const SmartPlusActionDraft({
    required this.id,
    required this.title,
    required this.actionType,
    required this.status,
    required this.resultMessage,
  });

  final String id;
  final String title;
  final String actionType;
  final String status;
  final String? resultMessage;

  factory SmartPlusActionDraft.fromMap(Map<String, dynamic> map) =>
      SmartPlusActionDraft(
        id: '${map['id'] ?? ''}',
        title: '${map['title'] ?? 'SmartPlus action'}',
        actionType: '${map['actionType'] ?? ''}',
        status: '${map['status'] ?? 'draft'}',
        resultMessage: map['resultMessage']?.toString(),
      );
}
