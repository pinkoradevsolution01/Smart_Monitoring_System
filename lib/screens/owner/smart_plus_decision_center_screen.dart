import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../services/smart_plus_notification_service.dart';
import '../../services/smart_plus_action_service.dart';
import '../../services/backend_api_service.dart';
import '../owner/customer_management_screen.dart';
import '../owner/sales_report_screen.dart';
import '../owner/supplier_management_screen.dart';
import '../shared/inventory_screen.dart';

/// Owner-only, read-only summary of the items that need attention today.
/// SmartPlus links to records but never changes sales, stock, or orders here.
class SmartPlusDecisionCenterScreen extends StatefulWidget {
  const SmartPlusDecisionCenterScreen({super.key});

  @override
  State<SmartPlusDecisionCenterScreen> createState() =>
      _SmartPlusDecisionCenterScreenState();
}

class _SmartPlusDecisionCenterScreenState
    extends State<SmartPlusDecisionCenterScreen> {
  final _actionService = SmartPlusActionService();
  late Future<List<SmartPlusActionDraft>> _actions = _actionService
      .listDrafts();

  void _reloadActions() {
    // `setState` callbacks must be synchronous. Assigning the Future is
    // synchronous; fetching the server data happens afterward in FutureBuilder.
    setState(() {
      _actions = _actionService.listDrafts();
    });
  }

  Future<void> _refresh(SmartPlusNotificationService service) {
    service.refresh(forceSupplierCheck: true);
    if (mounted) _reloadActions();
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    final service = GetIt.I<SmartPlusNotificationService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('What needs attention today?'),
        actions: [
          IconButton(
            tooltip: 'Refresh decision center',
            onPressed: () => _refresh(service),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Action review center',
            onPressed: () async {
              final approvedAction =
                  await showModalBottomSheet<SmartPlusActionDraft>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const _ActionDraftsSheet(),
                  );
              if (!context.mounted) return;
              if (approvedAction != null) {
                await _openApprovedWorkflow(context, approvedAction);
              }
              if (context.mounted) {
                service.refresh(forceSupplierCheck: true);
                _reloadActions();
              }
            },
            icon: const Icon(Icons.fact_check_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final brief = service.dailyBrief;
          return FutureBuilder<List<SmartPlusActionDraft>>(
            future: _actions,
            builder: (context, actionSnapshot) {
              if (actionSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (actionSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load review status. Please try again.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _refresh(service),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final actions =
                  actionSnapshot.data ?? const <SmartPlusActionDraft>[];
              final attention = service.notifications.where((item) {
                // Completion confirmations belong in the notification inbox,
                // not among outstanding items requiring attention.
                if (item.id.startsWith('action-completed-')) return false;
                return actionForSmartPlusNotification(item, actions)?.status !=
                    'executed';
              }).toList();
              final critical = attention
                  .where(
                    (item) => item.level == SmartPlusNotificationLevel.critical,
                  )
                  .toList();
              final reviewSoon = attention
                  .where(
                    (item) => item.level == SmartPlusNotificationLevel.warning,
                  )
                  .toList();
              final informational = attention
                  .where(
                    (item) => item.level == SmartPlusNotificationLevel.info,
                  )
                  .toList();
              return RefreshIndicator(
                onRefresh: () => _refresh(service),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Daily brief',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${service.dataTrust.freshnessLabel} • ${service.dataTrust.confidenceLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _BriefGrid(brief: brief),
                    const SizedBox(height: 24),
                    _AlertSection(
                      title: 'Critical',
                      subtitle: 'Act before normal operations continue.',
                      icon: Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                      alerts: critical,
                      actions: actions,
                      onActionSaved: _reloadActions,
                    ),
                    _AlertSection(
                      title: 'Review soon',
                      subtitle: 'Important items that need an owner decision.',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                      alerts: reviewSoon,
                      actions: actions,
                      onActionSaved: _reloadActions,
                    ),
                    _AlertSection(
                      title: 'Informational',
                      subtitle: 'Useful context for planning and follow-up.',
                      icon: Icons.lightbulb_outline_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      alerts: informational,
                      actions: actions,
                      onActionSaved: _reloadActions,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openApprovedWorkflow(
    BuildContext context,
    SmartPlusActionDraft action,
  ) async {
    if (action.actionType == 'reorder') {
      final productId = _asPositiveInt(action.proposal['productId']);
      final quantity = _asPositiveInt(action.proposal['quantity']);
      if (productId == null || quantity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This reorder recommendation no longer has a valid product or quantity. Refresh SmartPlus and create a new review.',
            ),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InventoryScreen(
            smartPlusReorderProductId: productId,
            smartPlusSuggestedQuantity: quantity,
            smartPlusActionId: action.id,
          ),
        ),
      );
      return;
    }

    final targetName = action.proposal['recordTarget']?.toString();
    final targets = SmartPlusRecordTarget.values.where(
      (value) => value.name == targetName,
    );
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This task has no linked workspace. Review its details before marking it complete.',
          ),
        ),
      );
      return;
    }

    if (_isDamageSettlement(action)) {
      final selectedTarget = await _chooseDamageWorkspace(context);
      if (!context.mounted || selectedTarget == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _GuidedSmartPlusTaskScreen(
            action: action,
            target: selectedTarget,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _GuidedSmartPlusTaskScreen(action: action, target: targets.first),
      ),
    );
  }

  int? _asPositiveInt(dynamic value) {
    final number = value is num ? value.toInt() : int.tryParse('$value');
    return number != null && number > 0 ? number : null;
  }

  bool _isDamageSettlement(SmartPlusActionDraft action) =>
      action.title.toLowerCase().contains('damage') ||
      action.proposal['workflow'] == 'damage_settlement';

  Future<SmartPlusRecordTarget?> _chooseDamageWorkspace(
    BuildContext context,
  ) => showDialog<SmartPlusRecordTarget>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Choose a damage settlement workspace'),
      content: const Text(
        'Choose where you will record the real settlement. Both paths use the same damage-report records. Complete the SmartPlus task only after an approved return or payment is recorded.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.pop(dialogContext, SmartPlusRecordTarget.inventory),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Inventory'),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.pop(dialogContext, SmartPlusRecordTarget.suppliers),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Supplier Management'),
        ),
      ],
    ),
  );
}

/// Guides an owner through a non-reorder SmartPlus task. The guide does not
/// alter business data; it opens the correct workspace and requires an
/// explicit owner completion confirmation afterward.
class _GuidedSmartPlusTaskScreen extends StatefulWidget {
  const _GuidedSmartPlusTaskScreen({
    required this.action,
    required this.target,
  });

  final SmartPlusActionDraft action;
  final SmartPlusRecordTarget target;

  @override
  State<_GuidedSmartPlusTaskScreen> createState() =>
      _GuidedSmartPlusTaskScreenState();
}

class _GuidedSmartPlusTaskScreenState
    extends State<_GuidedSmartPlusTaskScreen> {
  final _service = SmartPlusActionService();
  bool _workspaceOpened = false;
  bool _completing = false;

  String get _workspaceLabel => switch (widget.target) {
    SmartPlusRecordTarget.inventory => 'Inventory',
    SmartPlusRecordTarget.sales => 'Sales reports',
    SmartPlusRecordTarget.customers => 'Customer Management',
    SmartPlusRecordTarget.suppliers => 'Supplier Management',
  };

  String get _nextStep => widget.proposalText.isEmpty
      ? 'Review the related records and complete the required follow-up.'
      : widget.proposalText;

  String get _workspaceInstruction {
    final title = widget.action.title.toLowerCase();
    if (widget.target == SmartPlusRecordTarget.suppliers &&
        title.contains('approval')) {
      return 'In Purchase Orders, open the pending order, review its supplier, items, amount, and delivery details, then approve it with the required owner signature or cancel it if it should not proceed.';
    }
    if (widget.target == SmartPlusRecordTarget.suppliers &&
        (title.contains('restock') || title.contains('delivery'))) {
      return 'In Purchase Orders, open the approved or completed order. Only after goods physically arrive, record the delivery receipt and received quantities, then restock the good items. The expected delivery date does not prevent recording a real early delivery.';
    }
    if (widget.target == SmartPlusRecordTarget.suppliers &&
        title.contains('damage')) {
      return 'Open the Damage Reports tab. Review every unsettled report and record either an approved supplier return or responsible-person payment before confirming completion.';
    }
    return 'Open the related workspace, review the relevant records, and make the required owner-approved change.';
  }

  bool get _isDamageSettlement =>
      widget.action.title.toLowerCase().contains('damage') ||
      widget.action.proposal['workflow'] == 'damage_settlement';

  Future<void> _openWorkspace() async {
    final screen = switch (widget.target) {
      SmartPlusRecordTarget.inventory => InventoryScreen(
        initialTab: _isDamageSettlement ? 3 : null,
      ),
      SmartPlusRecordTarget.sales => const SalesReportScreen(),
      SmartPlusRecordTarget.customers => const CustomerManagementScreen(),
      SmartPlusRecordTarget.suppliers => SupplierManagementScreen(
        initialTab: _isDamageSettlement ? 3 : null,
      ),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => _workspaceOpened = true);
  }

  Future<void> _completeTask() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Complete this SmartPlus task?'),
            content: Text(
              'Confirm that you completed the required follow-up for "${widget.action.title}" in $_workspaceLabel. SmartPlus will record your completion but will not make or undo any business change.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not yet'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Mark task complete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _completing = true);
    try {
      await _service.execute(widget.action.id);
      if (!mounted) return;
      if (GetIt.I.isRegistered<SmartPlusNotificationService>()) {
        GetIt.I<SmartPlusNotificationService>().notifyActionCompleted(
          actionId: widget.action.id,
          title: 'Task completed',
          message:
              'You completed the SmartPlus task: ${widget.action.title}. A completion email is sent to the registered owner when SmartPlus email notifications are enabled.',
        );
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.celebration_rounded, color: Colors.green),
          title: const Text('Congratulations! You completed the task.'),
          content: const Text(
            'SmartPlus recorded the completed action and added an in-app notification. A completion email is also sent to the registered owner when SmartPlus email notifications are enabled.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(safeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('SmartPlus task guide')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.action.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete each step. SmartPlus will only mark this task complete after your confirmation.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _GuideStep(
            number: 1,
            title: 'Review the recommendation',
            detail: _nextStep,
            complete: true,
          ),
          _GuideStep(
            number: 2,
            title: 'Complete the follow-up in $_workspaceLabel',
            detail: _workspaceInstruction,
            complete: _workspaceOpened,
            action: FilledButton.icon(
              onPressed: _openWorkspace,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text('Open $_workspaceLabel'),
            ),
          ),
          _GuideStep(
            number: 3,
            title: 'Confirm completion',
            detail: _workspaceOpened
                ? 'When the task is truly finished, confirm it below. A check icon, in-app notice, and email confirmation will follow.'
                : 'Open the related workspace first, then return here to confirm completion.',
            complete: false,
            action: FilledButton.icon(
              onPressed: _workspaceOpened && !_completing
                  ? _completeTask
                  : null,
              icon: _completing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Mark task complete'),
            ),
          ),
        ],
      ),
    );
  }
}

extension on _GuidedSmartPlusTaskScreen {
  String get proposalText {
    final value = action.proposal['recommendedNextStep']?.toString().trim();
    return value ?? '';
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.detail,
    required this.complete,
    this.action,
  });

  final int number;
  final String title;
  final String detail;
  final bool complete;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: complete
                  ? Colors.green.withValues(alpha: 0.16)
                  : colors.primaryContainer,
              foregroundColor: complete
                  ? Colors.green.shade700
                  : colors.primary,
              child: complete
                  ? const Icon(Icons.check_rounded)
                  : Text(
                      '$number',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step $number: $title',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(detail),
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionDraftsSheet extends StatefulWidget {
  const _ActionDraftsSheet();

  @override
  State<_ActionDraftsSheet> createState() => _ActionDraftsSheetState();
}

class _ActionDraftsSheetState extends State<_ActionDraftsSheet> {
  final _service = SmartPlusActionService();
  late Future<List<SmartPlusActionDraft>> _drafts = _service.listDrafts();

  void _reload() => setState(() => _drafts = _service.listDrafts());

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: FutureBuilder<List<SmartPlusActionDraft>>(
        future: _drafts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(safeApiError(snapshot.error!)),
              ),
            );
          }
          final drafts = snapshot.data ?? const [];
          return Column(
            children: [
              const ListTile(
                leading: Icon(Icons.fact_check_outlined),
                title: Text('Action review center'),
                subtitle: Text(
                  'Review SmartPlus recommendations before taking a business action.',
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _ActionSafetyNotice(),
              ),
              Expanded(
                child: drafts.isEmpty
                    ? const _EmptyDrafts()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: drafts.length,
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          return Card(
                            child: ListTile(
                              leading: _ActionStatusIcon(status: draft.status),
                              onTap: () => _showDetails(draft),
                              title: Text(draft.title),
                              subtitle: Text(_draftListSummary(draft)),
                              /*
                              subtitle: Text(
                                '${draft.actionType} • ${draft.status}${draft.resultMessage == null ? '' : '\n${draft.resultMessage}'}',
                              ),
                              */
                              isThreeLine: draft.resultMessage != null,
                              trailing: draft.status == 'draft'
                                  ? FilledButton(
                                      onPressed: () => _approve(draft),
                                      child: const Text('Review'),
                                    )
                                  : draft.status == 'approved'
                                  ? FilledButton.tonal(
                                      // Completing a SmartPlus task must go
                                      // through its linked workspace first.
                                      // This prevents a single tap from
                                      // falsely marking a manual follow-up as
                                      // done.
                                      onPressed: () =>
                                          Navigator.of(context).pop(draft),
                                      child: const Text('Continue task'),
                                    )
                                  : draft.status == 'executed'
                                  ? const Tooltip(
                                      message: 'Task completed',
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                      ),
                                    )
                                  : null,
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

  Future<void> _approve(SmartPlusActionDraft draft) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Approve this recommendation?'),
            content: Text(
              'You are approving “${draft.title}”. The secure backend will re-check your owner role, subscription, business, and current records before approval.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Approve review'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _service.approve(draft.id);
      if (!mounted) return;
      Navigator.of(context).pop(draft);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(safeApiError(error))));
      }
    }
  }

  Future<void> _showDetails(SmartPlusActionDraft draft) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(draft.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLabel('Status'),
              Text(_statusLabel(draft.status)),
              const SizedBox(height: 14),
              _detailLabel('Recommended follow-up'),
              Text(_proposalDescription(draft)),
              const SizedBox(height: 14),
              _detailLabel('Why SmartPlus suggested this'),
              Text(_valueOrFallback(draft.evidence['why'])),
              const SizedBox(height: 14),
              _detailLabel('Source data'),
              Text(_valueOrFallback(draft.evidence['sourceData'])),
              const SizedBox(height: 6),
              _detailLabel('Data range'),
              Text(_valueOrFallback(draft.evidence['dataRange'])),
              if (draft.resultMessage != null) ...[
                const SizedBox(height: 14),
                _detailLabel('Review result'),
                Text(draft.resultMessage!),
              ],
              const SizedBox(height: 18),
              const Text(
                'SmartPlus does not place orders, send supplier messages, or change stock, prices, sales, payments, or discounts. Complete the follow-up yourself after review.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailLabel(String value) => Text(
    value.toUpperCase(),
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
  );

  String _proposalDescription(SmartPlusActionDraft draft) {
    final quantity = draft.proposal['quantity'];
    if (draft.actionType == 'reorder' && quantity != null) {
      return 'Review a suggested reorder of $quantity unit(s). Check the supplier, current price, and delivery date before you create a purchase order.';
    }
    return _valueOrFallback(
      draft.proposal['recommendedNextStep'],
      fallback:
          'Review the related business records and complete any change manually.',
    );
  }

  String _valueOrFallback(dynamic value, {String fallback = 'Not available'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _statusLabel(String status) => switch (status) {
    'draft' => 'Needs your review',
    'approved' => 'Approved - complete the follow-up manually',
    'executed' => 'Manual follow-up marked complete',
    'rejected' => 'Not approved',
    'failed' => 'Could not complete review',
    _ => status,
  };

  String _draftListSummary(SmartPlusActionDraft draft) {
    final summary =
        '${_actionTypeLabel(draft.actionType)} - ${_statusLabel(draft.status)}';
    final result = draft.resultMessage?.trim();
    return result == null || result.isEmpty ? summary : '$summary\n$result';
  }

  String _actionTypeLabel(String actionType) => switch (actionType) {
    'reorder' => 'Reorder recommendation',
    'price_change_proposal' => 'Price-change proposal',
    'supplier_message' => 'Supplier follow-up',
    'promotion' => 'Promotion proposal',
    'staff_follow_up' => 'Owner follow-up',
    _ => 'Owner follow-up',
  };
}

class _ActionSafetyNotice extends StatelessWidget {
  const _ActionSafetyNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'How it works: review the recommendation, approve its secure re-check, then complete the real task manually in the appropriate module. SmartPlus never makes the change for you.',
        ),
      ),
    );
  }
}

class _EmptyDrafts extends StatelessWidget {
  const _EmptyDrafts();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt_rounded, size: 42),
          SizedBox(height: 12),
          Text('No action reviews yet.'),
          SizedBox(height: 6),
          Text(
            'Open a SmartPlus suggestion and choose Draft safe action when you want to save a recommendation for review.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ActionStatusIcon extends StatelessWidget {
  const _ActionStatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      'draft' => (Icons.rate_review_outlined, colors.primary),
      'approved' => (Icons.pending_actions_outlined, Colors.orange.shade800),
      'executed' => (Icons.task_alt_rounded, Colors.green.shade700),
      'failed' => (Icons.error_outline_rounded, colors.error),
      _ => (Icons.info_outline_rounded, colors.onSurfaceVariant),
    };
    return Icon(icon, color: color);
  }
}

class _BriefGrid extends StatelessWidget {
  const _BriefGrid({required this.brief});

  final SmartPlusDailyBrief brief;

  @override
  Widget build(BuildContext context) {
    String currency(double value) => '₱ ${value.toStringAsFixed(2)}';
    final entries = <({IconData icon, String label, String value})>[
      (
        icon: Icons.payments_outlined,
        label: 'Sales',
        value: currency(brief.sales),
      ),
      (
        icon: Icons.trending_up_rounded,
        label: 'Gross profit',
        value: currency(brief.grossProfit),
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Expenses',
        value: brief.expenses == null
            ? 'Unavailable'
            : currency(brief.expenses!),
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Low stock',
        value: '${brief.lowStockCount}',
      ),
      (
        icon: Icons.sell_outlined,
        label: 'Discount reviews',
        value: '${brief.unusualDiscountCount}',
      ),
      (
        icon: Icons.star_outline_rounded,
        label: 'Top products',
        value: brief.topProducts.isEmpty
            ? 'No sales yet'
            : brief.topProducts.join(', '),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: columns == 3 ? 2.35 : 1.55,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      entry.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AlertSection extends StatelessWidget {
  const _AlertSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.alerts,
    required this.actions,
    required this.onActionSaved,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<SmartPlusNotification> alerts;
  final List<SmartPlusActionDraft> actions;
  final VoidCallback onActionSaved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${alerts.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Nothing in this priority level right now.'),
              ),
            )
          else
            ...alerts.map((alert) {
              final action = _actionForAlert(alert);
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        alert.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        alert.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: alert.recordTarget == null
                          ? null
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: alert.recordTarget == null
                          ? null
                          : () => _openRecords(context, alert.recordTarget!),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 6),
                        child: _actionStatusControl(context, alert, action),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  SmartPlusActionDraft? _actionForAlert(SmartPlusNotification alert) {
    return actionForSmartPlusNotification(alert, actions);
  }

  Widget _actionStatusControl(
    BuildContext context,
    SmartPlusNotification alert,
    SmartPlusActionDraft? action,
  ) {
    if (!alert.requiresOwnerConfirmation) {
      final syncComplete =
          alert.id == 'smartplus-data-freshness' &&
          alert.message.startsWith('Last synced');
      return Tooltip(
        message: syncComplete
            ? 'A successful cloud sync was recorded automatically.'
            : 'Waiting for the first successful cloud sync.',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              syncComplete
                  ? Icons.check_circle_rounded
                  : Icons.sync_problem_rounded,
              size: 20,
              color: syncComplete ? Colors.green : Colors.orange.shade800,
            ),
            const SizedBox(width: 6),
            Text(
              syncComplete ? 'Sync complete' : 'Sync pending',
              style: TextStyle(
                color: syncComplete ? Colors.green : Colors.orange.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    if (action == null) {
      return TextButton.icon(
        onPressed: () => _draftAction(context, alert),
        icon: const Icon(Icons.edit_note_rounded, size: 18),
        label: const Text('Save for owner review'),
      );
    }
    if (action.status == 'executed') {
      return const Tooltip(
        message: 'Task completed',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 20, color: Colors.green),
            SizedBox(width: 6),
            Text(
              'Task completed',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    final isApproved = action.status == 'approved';
    return Tooltip(
      message: isApproved
          ? 'Continue this task in Action review center.'
          : 'This recommendation is saved for owner review.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved
                ? Icons.pending_actions_rounded
                : Icons.bookmark_added_rounded,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(isApproved ? 'Task in progress' : 'Saved for review'),
        ],
      ),
    );
  }

  Future<void> _openRecords(
    BuildContext context,
    SmartPlusRecordTarget target,
  ) async {
    final screen = switch (target) {
      SmartPlusRecordTarget.inventory => const InventoryScreen(),
      SmartPlusRecordTarget.sales => const SalesReportScreen(),
      SmartPlusRecordTarget.customers => const CustomerManagementScreen(),
      SmartPlusRecordTarget.suppliers => const SupplierManagementScreen(),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!context.mounted) return;
    GetIt.I<SmartPlusNotificationService>().refresh(forceSupplierCheck: true);
    onActionSaved();
  }

  Future<void> _draftAction(
    BuildContext context,
    SmartPlusNotification notification,
  ) async {
    // The alert already carries the relevant context. Asking the owner to
    // choose from unrelated action types made this workflow ambiguous.
    final actionType = notification.draftActionType ?? 'staff_follow_up';
    try {
      await SmartPlusActionService().draftAction(
        notification,
        actionType: actionType,
      );
      if (!context.mounted) return;
      onActionSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recommendation saved in the Action review center.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeApiError(error))));
    }
  }
}
