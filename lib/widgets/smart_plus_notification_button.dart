import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/smart_plus_notification_service.dart';

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
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
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
    service.markAllRead();
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
                        onPressed: service.refresh,
                        icon: const Icon(Icons.refresh_rounded),
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
                                      ?.copyWith(color: colors.onSurfaceVariant),
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
                            return Card(
                              color: color.withValues(alpha: 0.08),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.16),
                                  foregroundColor: color,
                                  child: Icon(_levelIcon(notification.level)),
                                ),
                                title: Text(
                                  notification.title,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(notification.message),
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
}
