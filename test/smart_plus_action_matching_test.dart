import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/services/smart_plus_action_service.dart';
import 'package:smart_monitoring_system/services/smart_plus_notification_service.dart';

void main() {
  const notification = SmartPlusNotification(
    id: 'low-stock',
    title: 'Low stock',
    message: 'Two products need attention.',
    level: SmartPlusNotificationLevel.warning,
  );

  SmartPlusActionDraft action({
    String? sourceId = 'low-stock',
    String message = 'Two products need attention.',
    String status = 'executed',
  }) => SmartPlusActionDraft(
    id: 'action-1',
    title: 'Owner follow-up: Low stock',
    actionType: 'follow_up',
    status: status,
    resultMessage: null,
    proposal: {'sourceNotificationId': sourceId},
    evidence: {'message': message},
    createdAt: null,
    approvedAt: null,
    executedAt: null,
  );

  test('matches a completed review to its exact recommendation', () {
    expect(
      actionForSmartPlusNotification(notification, [action()])?.status,
      'executed',
    );
  });

  test('changed evidence is not hidden by an older completed review', () {
    expect(
      actionForSmartPlusNotification(notification, [
        action(message: 'One product needs attention.'),
      ]),
      isNull,
    );
  });

  test('completed supplier workflow remains linked when evidence wording changes', () {
    expect(
      hasCompletedActionForSmartPlusNotification(notification, [
        action(message: 'Delivery wording was refreshed.'),
      ]),
      isTrue,
    );
  });

  test('a completed workflow for another alert is never linked', () {
    expect(
      hasCompletedActionForSmartPlusNotification(notification, [
        action(sourceId: 'another-alert'),
      ]),
      isFalse,
    );
  });

  test('same title on a different alert does not match', () {
    expect(
      actionForSmartPlusNotification(notification, [
        action(sourceId: 'another-alert'),
      ]),
      isNull,
    );
  });

  test('legacy review matches only when its recorded evidence matches', () {
    expect(
      actionForSmartPlusNotification(notification, [action(sourceId: null)]),
      isNotNull,
    );
    expect(
      actionForSmartPlusNotification(notification, [
        action(sourceId: null, message: 'Different evidence.'),
      ]),
      isNull,
    );
  });

  test('newest active review takes precedence over older completion', () {
    expect(
      actionForSmartPlusNotification(notification, [
        action(status: 'draft'),
        action(),
      ])?.status,
      'draft',
    );
  });
}
