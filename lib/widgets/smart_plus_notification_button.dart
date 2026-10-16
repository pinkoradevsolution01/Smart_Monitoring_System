import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/smart_plus_notification_service.dart';
import '../screens/owner/customer_management_screen.dart';
import '../screens/owner/sales_report_screen.dart';
import '../screens/owner/supplier_management_screen.dart';
import '../screens/shared/inventory_screen.dart';

/// Owner-facing entry point for SmartPlus suggestions.
class SmartPlusNotificationButton extends StatelessWidget {
  const SmartPlusNotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = GetIt.I<SmartPlusNotificationService>();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final count = service.unreadCount;
        return IconButton(
          tooltip: count == 0
              ? 'SmartPlus suggestions'
              : '$count SmartPlus suggestion${count == 1 ? '' : 's'}',
          onPressed: () => _openSuggestions(context, service),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (count > 0)
                Positioned(
                  top: -5,
                  right: -7,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openSuggestions(
    BuildContext context,
    SmartPlusNotificationService service,
  ) {
    service.refresh();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return const _SmartPlusNotificationsSheet();
      },
    );
  }
}

class _SmartPlusNotificationsSheet extends StatelessWidget {
  const _SmartPlusNotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final service = GetIt.I<SmartPlusNotificationService>();
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.68,
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final notifications = service.notifications;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: colors.tertiary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SmartPlus suggestions',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Suggestions based on your business activity',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh suggestions',
                        onPressed: () =>
                            service.refresh(forceSupplierCheck: true),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Notification preferences',
                        onPressed: () => _openPreferences(context, service),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: colors.primary,
                                  size: 42,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No action needed right now',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'SmartPlus will add suggestions when there is something worth reviewing.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            final color = _levelColor(
                              notification.level,
                              colors,
                            );
                            final reviewed = service.isReviewed(
                              notification.id,
                            );
                            return Card(
                              color: color.withValues(alpha: 0.08),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: color.withValues(
                                            alpha: 0.16,
                                          ),
                                          foregroundColor: color,
                                          child: Icon(
                                            _levelIcon(notification.level),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            notification.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Chip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text(
                                            notification.insightKind ==
                                                    SmartPlusInsightKind
                                                        .forecast
                                                ? 'Forecast'
                                                : 'Rule',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(notification.message),
                                    const SizedBox(height: 10),
                                    _evidenceRow(
                                      context,
                                      Icons.storage_outlined,
                                      'Source: ${notification.sourceData}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.date_range_outlined,
                                      'Range: ${notification.dataRange}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.verified_outlined,
                                      'Data quality: ${notification.dataQuality.name} — ${notification.confidence}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.psychology_alt_outlined,
                                      'Why: ${notification.why}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.task_alt_outlined,
                                      'Suggested next step: ${notification.proposedAction}',
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      notification.insightKind ==
                                              SmartPlusInsightKind.forecast
                                          ? 'This is an estimate from the stated data range, not a guarantee.'
                                          : 'This is a review rule, not an automatic decision.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (notification.recordTarget != null)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () => _openRecords(
                                            context,
                                            notification.recordTarget!,
                                          ),
                                          icon: const Icon(
                                            Icons.open_in_new_rounded,
                                            size: 17,
                                          ),
                                          label: const Text(
                                            'Open supporting records',
                                          ),
                                        ),
                                      ),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _recordFeedback(
                                            context,
                                            service,
                                            notification.id,
                                            'useful',
                                          ),
                                          icon: const Icon(
                                            Icons.thumb_up_alt_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('Useful'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => _recordFeedback(
                                            context,
                                            service,
                                            notification.id,
                                            'ignored',
                                          ),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 16,
                                          ),
                                          label: const Text('Ignore'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => _recordFeedback(
                                            context,
                                            service,
                                            notification.id,
                                            'inaccurate',
                                          ),
                                          icon: const Icon(
                                            Icons.flag_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('Inaccurate'),
                                        ),
                                      ],
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: reviewed
                                          ? const Chip(
                                              avatar: Icon(
                                                Icons.verified_outlined,
                                                size: 18,
                                              ),
                                              label: Text('Reviewed by owner'),
                                            )
                                          : OutlinedButton.icon(
                                              onPressed: () => _confirmReview(
                                                context,
                                                service,
                                                notification,
                                              ),
                                              icon: const Icon(
                                                Icons.verified_user_outlined,
                                              ),
                                              label: const Text(
                                                'Confirm review',
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _levelColor(SmartPlusNotificationLevel level, ColorScheme colors) {
    return switch (level) {
      SmartPlusNotificationLevel.info => colors.tertiary,
      SmartPlusNotificationLevel.warning => Colors.orange.shade800,
      SmartPlusNotificationLevel.critical => colors.error,
    };
  }

  IconData _levelIcon(SmartPlusNotificationLevel level) => switch (level) {
    SmartPlusNotificationLevel.info => Icons.lightbulb_outline_rounded,
    SmartPlusNotificationLevel.warning => Icons.warning_amber_rounded,
    SmartPlusNotificationLevel.critical => Icons.error_outline_rounded,
  };

  Widget _evidenceRow(BuildContext context, IconData icon, String text) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );

  void _openRecords(BuildContext context, SmartPlusRecordTarget target) {
    final screen = switch (target) {
      SmartPlusRecordTarget.inventory => const InventoryScreen(),
      SmartPlusRecordTarget.sales => const SalesReportScreen(),
      SmartPlusRecordTarget.customers => const CustomerManagementScreen(),
      SmartPlusRecordTarget.suppliers => const SupplierManagementScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmReview(
    BuildContext context,
    SmartPlusNotificationService service,
    SmartPlusNotification notification,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm owner review'),
            content: Text(
              'Confirm that you reviewed “${notification.title}”. SmartPlus will not change stock, orders, prices, discounts, or sales automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm review'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await service.confirmOwnerReview(notification.id);
  }

  Future<void> _recordFeedback(
    BuildContext context,
    SmartPlusNotificationService service,
    String notificationId,
    String verdict,
  ) async {
    final problem = await service.recordFeedback(notificationId, verdict);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          problem ??
              'Feedback recorded for the next SmartPlus accuracy review.',
        ),
      ),
    );
  }

  Future<void> _openPreferences(
    BuildContext context,
    SmartPlusNotificationService service,
  ) async {
    await service.refreshPreferencesFromServer();
    if (!context.mounted) return;
    var draft = service.preferences;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('SmartPlus notification preferences'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile.adaptive(
                  value: draft.inAppEnabled,
                  onChanged: (value) => setDialogState(
                    () => draft = draft.copyWith(inAppEnabled: value),
                  ),
                  title: const Text('In-app suggestions'),
                  subtitle: const Text(
                    'Show SmartPlus suggestions in this app.',
                  ),
                ),
                SwitchListTile.adaptive(
                  value: draft.emailEnabled,
                  onChanged: (value) => setDialogState(
                    () => draft = draft.copyWith(emailEnabled: value),
                  ),
                  title: const Text('Owner email digest'),
                  subtitle: const Text(
                    'Allow at most one operational email digest per day.',
                  ),
                ),
                const Divider(),
                _preferenceSwitch(
                  value: draft.lowStockEnabled,
                  title: 'Stock alerts',
                  onChanged: (value) => setDialogState(
                    () => draft = draft.copyWith(lowStockEnabled: value),
                  ),
                ),
                _preferenceSwitch(
                  value: draft.salesEnabled,
                  title: 'Sales comparisons',
                  onChanged: (value) => setDialogState(
                    () => draft = draft.copyWith(salesEnabled: value),
                  ),
                ),
                _preferenceSwitch(
                  value: draft.discountEnabled,
                  title: 'Discount review reminders',
                  onChanged: (value) => setDialogState(
                    () => draft = draft.copyWith(discountEnabled: value),
                  ),
                ),
                _preferenceSwitch(
                  value: draft.forecastEnabled,
                  title: 'Forecast-readiness reminders',
                  onChanged: (value) => setDialogState(
                    () => draft = draft.copyWith(forecastEnabled: value),
                  ),
                ),
                _preferenceSwitch(
                  value: draft.supplierDeliveryEnabled,
                  title: 'Supplier and delivery alerts',
                  subtitle:
                      'In-app and owner email digest: on due date, one day overdue, then every three days overdue.',
                  onChanged: (value) => setDialogState(
                    () =>
                        draft = draft.copyWith(supplierDeliveryEnabled: value),
                  ),
                ),
                _preferenceSwitch(
                  value: draft.customerLoyaltyEnabled,
                  title: 'Customer and loyalty reminders',
                  subtitle:
                      'Points-expiry and consented follow-up reviews only. SmartPlus never contacts customers automatically.',
                  onChanged: (value) => setDialogState(
                    () => draft = draft.copyWith(customerLoyaltyEnabled: value),
                  ),
                ),
                const Divider(),
                DropdownButtonFormField<SmartPlusNotificationLevel>(
                  key: ValueKey(draft.minimumSeverity),
                  initialValue: draft.minimumSeverity,
                  decoration: const InputDecoration(
                    labelText: 'Minimum in-app severity',
                    border: OutlineInputBorder(),
                  ),
                  items: SmartPlusNotificationLevel.values
                      .map(
                        (level) => DropdownMenuItem(
                          value: level,
                          child: Text(
                            level.name[0].toUpperCase() +
                                level.name.substring(1),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(
                        () => draft = draft.copyWith(minimumSeverity: value),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SmartPlusDigestFrequency>(
                  key: ValueKey(draft.digestFrequency),
                  initialValue: draft.digestFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Owner email digest',
                    border: OutlineInputBorder(),
                  ),
                  items: SmartPlusDigestFrequency.values
                      .map(
                        (frequency) => DropdownMenuItem(
                          value: frequency,
                          child: Text(
                            frequency == SmartPlusDigestFrequency.off
                                ? 'Off'
                                : '${frequency.name[0].toUpperCase()}${frequency.name.substring(1)} digest',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(
                        () => draft = draft.copyWith(digestFrequency: value),
                      );
                    }
                  },
                ),
                SwitchListTile.adaptive(
                  value:
                      draft.quietHoursStart != null &&
                      draft.quietHoursEnd != null,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Quiet hours'),
                  subtitle: const Text(
                    'Defer non-critical in-app suggestions during the selected hours.',
                  ),
                  onChanged: (enabled) => setDialogState(
                    () => draft = enabled
                        ? draft.copyWith(quietHoursStart: 22, quietHoursEnd: 7)
                        : draft.copyWith(clearQuietHours: true),
                  ),
                ),
                if (draft.quietHoursStart != null &&
                    draft.quietHoursEnd != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _hourSelector(
                          label: 'Starts',
                          value: draft.quietHoursStart!,
                          onChanged: (hour) => setDialogState(
                            () => draft = draft.copyWith(quietHoursStart: hour),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _hourSelector(
                          label: 'Ends',
                          value: draft.quietHoursEnd!,
                          onChanged: (hour) => setDialogState(
                            () => draft = draft.copyWith(quietHoursEnd: hour),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final problem = await service.updatePreferences(draft);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (problem != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Preferences saved on this device. $problem',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preferenceSwitch({
    required bool value,
    required String title,
    String? subtitle,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
    value: value,
    onChanged: onChanged,
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
  );

  Widget _hourSelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) => DropdownButtonFormField<int>(
    key: ValueKey(value),
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: List<DropdownMenuItem<int>>.generate(
      24,
      (hour) => DropdownMenuItem(
        value: hour,
        child: Text('${hour.toString().padLeft(2, '0')}:00'),
      ),
    ),
    onChanged: (hour) {
      if (hour != null) onChanged(hour);
    },
  );
}
