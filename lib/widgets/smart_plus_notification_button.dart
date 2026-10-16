import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/smart_plus_notification_service.dart';
import '../screens/owner/customer_management_screen.dart';
import '../screens/owner/sales_report_screen.dart';
import '../screens/owner/supplier_management_screen.dart';
import '../screens/shared/inventory_screen.dart';
import '../utils/locale_controller.dart';

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

enum _SmartPlusInboxLanguage { english, tagalog }

class _SmartPlusNotificationsSheet extends StatefulWidget {
  const _SmartPlusNotificationsSheet();

  @override
  State<_SmartPlusNotificationsSheet> createState() =>
      _SmartPlusNotificationsSheetState();
}

class _SmartPlusNotificationsSheetState
    extends State<_SmartPlusNotificationsSheet> {
  late _SmartPlusInboxLanguage _language;

  @override
  void initState() {
    super.initState();
    _language = LocaleController.locale.value.languageCode == 'fil'
        ? _SmartPlusInboxLanguage.tagalog
        : _SmartPlusInboxLanguage.english;
  }

  bool get _isTagalog => _language == _SmartPlusInboxLanguage.tagalog;
  String _text(String english) =>
      _SmartPlusInboxText.translate(english, tagalog: _isTagalog);

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
                              _text('SmartPlus suggestions'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              _text(
                                'Suggestions based on your business activity',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _text('Refresh suggestions'),
                        onPressed: () =>
                            service.refresh(forceSupplierCheck: true),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: _text('Notification preferences'),
                        onPressed: () => _openPreferences(context, service),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                      PopupMenuButton<_SmartPlusInboxLanguage>(
                        tooltip: _text('Inbox language'),
                        initialValue: _language,
                        onSelected: (language) =>
                            setState(() => _language = language),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _SmartPlusInboxLanguage.english,
                            child: Text('English'),
                          ),
                          PopupMenuItem(
                            value: _SmartPlusInboxLanguage.tagalog,
                            child: Text('Tagalog'),
                          ),
                        ],
                        icon: const Icon(Icons.language_rounded),
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
                                  _text('No action needed right now'),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _text(
                                    'SmartPlus will add suggestions when there is something worth reviewing.',
                                  ),
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
                                            _text(notification.title),
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
                                                ? _text('Forecast')
                                                : _text('Rule'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(_text(notification.message)),
                                    const SizedBox(height: 10),
                                    _evidenceRow(
                                      context,
                                      Icons.storage_outlined,
                                      '${_text('Source')}: ${_text(notification.sourceData)}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.date_range_outlined,
                                      '${_text('Range')}: ${_text(notification.dataRange)}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.verified_outlined,
                                      '${_text('Data quality')}: ${_text(notification.dataQuality.name)} — ${_text(notification.confidence)}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.psychology_alt_outlined,
                                      '${_text('Why')}: ${_text(notification.why)}',
                                    ),
                                    _evidenceRow(
                                      context,
                                      Icons.task_alt_outlined,
                                      '${_text('Suggested next step')}: ${_text(notification.proposedAction)}',
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      notification.insightKind ==
                                              SmartPlusInsightKind.forecast
                                          ? _text(
                                              'This is an estimate from the stated data range, not a guarantee.',
                                            )
                                          : _text(
                                              'This is a review rule, not an automatic decision.',
                                            ),
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
                                          label: Text(
                                            _text('Open supporting records'),
                                          ),
                                        ),
                                      ),
                                    _feedbackSelector(
                                      context,
                                      service,
                                      notification.id,
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: reviewed
                                          ? Chip(
                                              avatar: const Icon(
                                                Icons.verified_outlined,
                                                size: 18,
                                              ),
                                              label: Text(
                                                _text('Reviewed by owner'),
                                              ),
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
                                              label: Text(
                                                _text('Confirm review'),
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

  Widget _feedbackSelector(
    BuildContext context,
    SmartPlusNotificationService service,
    String notificationId,
  ) {
    final selected = service.feedbackFor(notificationId);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: selected == null
          ? Wrap(
              key: ValueKey('feedback-options-$notificationId'),
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_text('Was this helpful?')),
                _feedbackChip(
                  context,
                  service,
                  notificationId,
                  verdict: 'useful',
                  label: _text('Useful'),
                  icon: Icons.thumb_up_alt_outlined,
                  selected: false,
                ),
                _feedbackChip(
                  context,
                  service,
                  notificationId,
                  verdict: 'ignored',
                  label: _text('Ignore'),
                  icon: Icons.remove_circle_outline,
                  selected: false,
                ),
                _feedbackChip(
                  context,
                  service,
                  notificationId,
                  verdict: 'inaccurate',
                  label: _text('Inaccurate'),
                  icon: Icons.flag_outlined,
                  selected: false,
                ),
              ],
            )
          : Semantics(
              key: ValueKey('feedback-saved-$notificationId-$selected'),
              liveRegion: true,
              label:
                  '${_text('Feedback saved')}: ${_text(_feedbackLabel(selected))}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_text('Feedback saved')}: ${_text(_feedbackLabel(selected))}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _feedbackLabel(String verdict) => switch (verdict) {
    'useful' => 'Useful',
    'ignored' => 'Ignore',
    'inaccurate' => 'Inaccurate',
    _ => verdict,
  };

  Widget _feedbackChip(
    BuildContext context,
    SmartPlusNotificationService service,
    String notificationId, {
    required String verdict,
    required String label,
    required IconData icon,
    required bool selected,
  }) => ChoiceChip(
    selected: selected,
    avatar: Icon(icon, size: 16),
    label: Text(label),
    onSelected: (isSelected) {
      if (isSelected && !selected) {
        _recordFeedback(context, service, notificationId, verdict);
      }
    },
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
          problem ?? 'Marked as ${verdict == 'ignored' ? 'ignored' : verdict}.',
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
                  title: const Text('Email notifications'),
                  subtitle: const Text(
                    'Email the registered owner when SmartPlus finds a new important suggestion.',
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
                      'In-app and owner email alerts: on due date, one day overdue, then every three days overdue.',
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

/// Presentation-only translations for the inbox. Product names, amounts,
/// purchase-order numbers, and other business evidence remain unchanged.
class _SmartPlusInboxText {
  static String translate(String english, {required bool tagalog}) {
    if (!tagalog) return english;
    final exact = _tagalog[english];
    if (exact != null) return exact;

    // Live SmartPlus messages contain product names, quantities, dates, and
    // purchase-order numbers. Translate their stable wording without changing
    // those business values.
    return english
        .replaceAll(
          'No products are currently',
          'Walang produkto na kasalukuyang',
        )
        .replaceAll(
          'Products are out of stock',
          'Ubos na ang stock ng mga produkto',
        )
        .replaceAll('Low-stock', 'Mababang stock')
        .replaceAll('low-stock', 'mababang stock')
        .replaceAll('product(s)', 'produkto')
        .replaceAll('customer(s)', 'customer')
        .replaceAll('sale(s)', 'benta')
        .replaceAll('day(s)', 'araw')
        .replaceAll('needs review', 'ay kailangang suriin')
        .replaceAll('requires review', 'ay nangangailangan ng pagsusuri')
        .replaceAll('Review ', 'Suriin ang ')
        .replaceAll('Open ', 'Buksan ang ')
        .replaceAll('Current ', 'Kasalukuyang ')
        .replaceAll('current ', 'kasalukuyang ')
        .replaceAll('Last ', 'Huling ')
        .replaceAll('Next ', 'Susunod na ')
        .replaceAll('Today', 'Ngayon')
        .replaceAll('today', 'ngayon')
        .replaceAll('and ', 'at ')
        .replaceAll(' before ', ' bago ')
        .replaceAll(' after ', ' pagkatapos ng ');
  }

  static const Map<String, String> _tagalog = {
    'SmartPlus suggestions': 'Mga mungkahi ng SmartPlus',
    'Suggestions based on your business activity':
        'Mga mungkahing batay sa aktibidad ng iyong negosyo',
    'Refresh suggestions': 'I-refresh ang mga mungkahi',
    'Notification preferences': 'Mga kagustuhan sa notification',
    'Inbox language': 'Wika ng inbox',
    'No action needed right now': 'Walang kailangang aksyon sa ngayon',
    'SmartPlus will add suggestions when there is something worth reviewing.':
        'Magdadagdag ang SmartPlus ng mungkahi kapag may kailangang suriin.',
    'Forecast': 'Pagtataya',
    'Rule': 'Patakaran',
    'Source': 'Pinagmulan',
    'Range': 'Saklaw',
    'Data quality': 'Kalidad ng data',
    'Why': 'Dahilan',
    'Suggested next step': 'Inirerekomendang susunod na hakbang',
    'Open supporting records': 'Buksan ang kaugnay na mga rekord',
    'Reviewed by owner': 'Nasuri na ng may-ari',
    'Confirm review': 'Kumpirmahin ang pagsusuri',
    'Was this helpful?': 'Nakatulong ba ito?',
    'Feedback saved': 'Naitala ang feedback',
    'Useful': 'Nakatulong',
    'Ignore': 'Balewalain',
    'Inaccurate': 'Hindi tumpak',
    'This is an estimate from the stated data range, not a guarantee.':
        'Ito ay pagtataya mula sa nakasaad na saklaw ng data, hindi garantiya.',
    'This is a review rule, not an automatic decision.':
        'Ito ay patakaran para sa pagsusuri, hindi awtomatikong desisyon.',
    'Business setup complete': 'Kumpleto na ang pag-set up ng negosyo',
    'Loyalty points expiring soon':
        'Malapit nang mag-expire ang loyalty points',
    'Consented customer follow-up available':
        'May available na follow-up para sa customer na may pahintulot',
    'Data freshness': 'Kasariwaan ng data',
    'Forecasts are paused until data improves':
        'Naka-pause ang mga pagtataya hanggang gumanda ang data',
    'Products are out of stock': 'Ubos na ang stock ng mga produkto',
    'Low-stock reorder suggested':
        'Inirerekomenda ang pag-order muli para sa mababang stock',
    'Top-selling product needs attention':
        'Kailangang tingnan ang produktong mabilis mabenta',
    'Weekly sales need review': 'Kailangang suriin ang lingguhang benta',
    'Large discounts require review':
        'Kailangang suriin ang malalaking diskwento',
    'Refund activity needs review': 'Kailangang suriin ang mga refund',
    'Forecast requires stronger records':
        'Kailangan ng mas maayos na mga rekord para sa pagtataya',
    'Today’s decision brief': 'Buod ng mahahalagang desisyon ngayon',
    'Expired stock needs immediate review':
        'Kailangang agad suriin ang expired na stock',
    'Near-expiry stock needs review':
        'Kailangang suriin ang stock na malapit mag-expire',
    'Potential dead stock detected': 'May natukoy na posibleng dead stock',
    'Seasonal demand forecast is ready to review':
        'Handa nang suriin ang pana-panahong pagtataya ng demand',
    'Supplier order awaiting confirmation':
        'Naghihintay ng kumpirmasyon ang order sa supplier',
    'Shipment marked complete but not received':
        'Nakumpleto ang shipment ngunit hindi pa natatanggap',
    'Partial supplier delivery needs review':
        'Kailangang suriin ang bahagyang delivery ng supplier',
    'Delivered stock has not been added to inventory':
        'Hindi pa naidadagdag sa imbentaryo ang na-deliver na stock',
    'Supplier delivery is due today':
        'Nakatakda ngayong araw ang delivery ng supplier',
    'Supplier delivery is overdue': 'Late na ang delivery ng supplier',
    'Supplier reliability trend needs review':
        'Kailangang suriin ang pagiging maaasahan ng supplier',
    'checking': 'Sinusuri',
    'weak': 'Mahina',
    'limited': 'Limitado',
    'strong': 'Matibay',
    'High confidence': 'Mataas ang kumpiyansa',
    'Moderate confidence': 'Katamtaman ang kumpiyansa',
    'Low confidence': 'Mababa ang kumpiyansa',
    'Confidence pending': 'Hinihintay ang kumpiyansa',
  };
}
