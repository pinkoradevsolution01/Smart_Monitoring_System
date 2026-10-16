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
class SmartPlusDecisionCenterScreen extends StatelessWidget {
  const SmartPlusDecisionCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = GetIt.I<SmartPlusNotificationService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('What needs attention today?'),
        actions: [
          IconButton(
            tooltip: 'Refresh decision center',
            onPressed: () => service.refresh(forceSupplierCheck: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'SmartPlus action drafts',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _ActionDraftsSheet(),
            ),
            icon: const Icon(Icons.fact_check_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final brief = service.dailyBrief;
          final critical = service.notifications
              .where(
                (item) => item.level == SmartPlusNotificationLevel.critical,
              )
              .toList();
          final reviewSoon = service.notifications
              .where((item) => item.level == SmartPlusNotificationLevel.warning)
              .toList();
          final informational = service.notifications
              .where((item) => item.level == SmartPlusNotificationLevel.info)
              .toList();
          return RefreshIndicator(
            onRefresh: () async => service.refresh(forceSupplierCheck: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Daily brief',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
                ),
                _AlertSection(
                  title: 'Review soon',
                  subtitle: 'Important items that need an owner decision.',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                  alerts: reviewSoon,
                ),
                _AlertSection(
                  title: 'Informational',
                  subtitle: 'Useful context for planning and follow-up.',
                  icon: Icons.lightbulb_outline_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                  alerts: informational,
                ),
              ],
            ),
          );
        },
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
                title: Text('SmartPlus action drafts'),
                subtitle: Text(
                  'Every approval and execution is recorded by the secure backend.',
                ),
              ),
              Expanded(
                child: drafts.isEmpty
                    ? const Center(child: Text('No SmartPlus drafts yet.'))
                    : ListView.builder(
                        itemCount: drafts.length,
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          return Card(
                            child: ListTile(
                              title: Text(draft.title),
                              subtitle: Text(
                                '${draft.actionType} • ${draft.status}${draft.resultMessage == null ? '' : '\n${draft.resultMessage}'}',
                              ),
                              isThreeLine: draft.resultMessage != null,
                              trailing: draft.status == 'draft'
                                  ? FilledButton(
                                      onPressed: () => _approve(draft),
                                      child: const Text('Approve'),
                                    )
                                  : draft.status == 'approved'
                                  ? FilledButton.tonal(
                                      onPressed: () => _execute(draft),
                                      child: const Text('Execute'),
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
            title: const Text('Approve SmartPlus action?'),
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
                child: const Text('Approve'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _service.approve(draft.id);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(safeApiError(error))));
      }
    }
  }

  Future<void> _execute(SmartPlusActionDraft draft) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Execute approved action?'),
            content: const Text(
              'The backend will re-check your owner session, subscription, tenant, and current proposal data. SmartPlus will not change POS, payment, discount, or stock data automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Execute'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _service.execute(draft.id);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(safeApiError(error))));
      }
    }
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<SmartPlusNotification> alerts;

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
            ...alerts.map(
              (alert) => Card(
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
                        child: TextButton.icon(
                          onPressed: () => _draftFollowUp(context, alert),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Draft owner follow-up'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openRecords(BuildContext context, SmartPlusRecordTarget target) {
    final screen = switch (target) {
      SmartPlusRecordTarget.inventory => const InventoryScreen(),
      SmartPlusRecordTarget.sales => const SalesReportScreen(),
      SmartPlusRecordTarget.customers => const CustomerManagementScreen(),
      SmartPlusRecordTarget.suppliers => const SupplierManagementScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _draftFollowUp(
    BuildContext context,
    SmartPlusNotification notification,
  ) async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Draft a safe owner follow-up?'),
            content: Text(
              'SmartPlus will save a review-only draft for “${notification.title}”. It will not change stock, prices, suppliers, carts, discounts, or payments.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save draft'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved || !context.mounted) return;
    try {
      await SmartPlusActionService().draftFollowUp(notification);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SmartPlus draft saved for owner review.'),
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
