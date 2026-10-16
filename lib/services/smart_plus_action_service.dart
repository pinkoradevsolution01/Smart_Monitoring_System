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
        'proposal': {
          if (isBoundReorder) ...notification.draftProposal!,
          if (!isBoundReorder) ...{
            'recommendedNextStep': notification.proposedAction,
            'recordTarget': notification.recordTarget?.name,
          },
          // This stable link lets What needs attention today show the actual
          // server-recorded task state rather than offering duplicate drafts.
          'sourceNotificationId': notification.id,
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
    _ => 'Owner follow-up',
  };
}

class SmartPlusActionDraft {
  const SmartPlusActionDraft({
    required this.id,
    required this.title,
    required this.actionType,
    required this.status,
    required this.resultMessage,
    required this.proposal,
    required this.evidence,
    required this.createdAt,
    required this.approvedAt,
    required this.executedAt,
  });

  final String id;
  final String title;
  final String actionType;
  final String status;
  final String? resultMessage;
  final Map<String, dynamic> proposal;
  final Map<String, dynamic> evidence;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? executedAt;

  factory SmartPlusActionDraft.fromMap(Map<String, dynamic> map) =>
      SmartPlusActionDraft(
        id: '${map['id'] ?? ''}',
        title: _ownerFacingTitle('${map['title'] ?? 'SmartPlus action'}'),
        actionType: '${map['actionType'] ?? ''}',
        status: '${map['status'] ?? 'draft'}',
        resultMessage: map['resultMessage']?.toString(),
        proposal: _mapValue(map['proposal']),
        evidence: _mapValue(map['evidence']),
        createdAt: _dateValue(map['createdAt']),
        approvedAt: _dateValue(map['approvedAt']),
        executedAt: _dateValue(map['executedAt']),
      );

  static Map<String, dynamic> _mapValue(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  static DateTime? _dateValue(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String _ownerFacingTitle(String value) =>
      value.replaceFirst('Staff follow-up:', 'Owner follow-up:');
}
