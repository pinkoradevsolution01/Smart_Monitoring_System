import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../models/sale.dart';
import '../models/user.dart';
import '../screens/admin/business_registration_screen.dart';
import '../screens/admin/manage_products.dart';
import '../screens/admin/manage_users_screen.dart';
import '../screens/cashier/cashier_pos.dart';
import '../screens/shared/package_selection_screen.dart';
import '../services/business_info_service.dart';
import '../services/package_service.dart';
import '../services/pos_service.dart';
import '../services/user_service.dart';
import 'app_design_system.dart';

/// A live setup checklist for a new business. Every completion state is read
/// from the existing services; it does not create duplicate setup records.
class FirstTimeSetupCard extends StatefulWidget {
  final User owner;

  const FirstTimeSetupCard({super.key, required this.owner});

  @override
  State<FirstTimeSetupCard> createState() => _FirstTimeSetupCardState();
}

class _FirstTimeSetupCardState extends State<FirstTimeSetupCard> {
  final _business = GetIt.I<BusinessInfoService>();
  final _package = GetIt.I<PackageService>();
  final _pos = GetIt.I<POSService>();
  final _users = GetIt.I<UserService>();
  bool _hasFirstSale = false;

  @override
  void initState() {
    super.initState();
    _refreshSaleProgress();
  }

  Future<void> _refreshSaleProgress() async {
    try {
      final sales = await _pos.databaseService.getAllSales();
      final hasCompletedSale = sales.any(
        (sale) => sale.status == SaleStatus.completed,
      );
      if (mounted) setState(() => _hasFirstSale = hasCompletedSale);
    } catch (_) {
      // The checklist remains usable if a device is temporarily offline.
    }
  }

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _refreshSaleProgress();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_business, _package, _pos, _users]),
      builder: (context, _) {
        final hasCashier = _users.activeUsers.any(
          (user) => user.role == UserRole.cashier && user.id != 'cashier-1',
        );
        final steps = <_SetupStep>[
          _SetupStep(
            title: 'Owner account',
            detail: 'Your secure owner access is ready.',
            complete: widget.owner.isActive,
          ),
          _SetupStep(
            title: 'Business profile',
            detail: 'Add your store name, business type, address, and logo.',
            complete: _business.isConfigured,
            actionLabel: 'Set up business',
            onAction: () => _open(
              context,
              const BusinessRegistrationScreen(),
            ),
          ),
          _SetupStep(
            title: 'Subscription',
            detail: 'Choose and activate the package for your business.',
            complete: _package.setupComplete && _package.hasPackage,
            actionLabel: 'Choose package',
            onAction: () => _open(
              context,
              PackageSelectionScreen(
                packageService: _package,
                currentUser: widget.owner,
              ),
            ),
          ),
          _SetupStep(
            title: 'Products',
            detail: 'Add the products and opening stock you will sell.',
            complete: _pos.products.isNotEmpty,
            actionLabel: 'Add products',
            onAction: () => _open(context, const ManageProductsScreen()),
          ),
          _SetupStep(
            title: 'Cashier',
            detail: 'Create at least one cashier account for daily sales.',
            complete: hasCashier,
            actionLabel: 'Add cashier',
            onAction: () => _open(context, const ManageUsers()),
          ),
          _SetupStep(
            title: 'First sale',
            detail: 'Complete a test or live sale to verify your workflow.',
            complete: _hasFirstSale,
            actionLabel: 'Open POS',
            onAction: () => _open(
              context,
              CashierPOS(cashierName: widget.owner.name),
            ),
          ),
        ];
        final completeCount = steps.where((step) => step.complete).length;
        final progress = completeCount / steps.length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      completeCount == steps.length
                          ? Icons.task_alt_outlined
                          : Icons.rocket_launch_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        completeCount == steps.length
                            ? 'Business setup complete'
                            : 'Finish setting up your business',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AppStatusBadge(
                      label: '$completeCount of ${steps.length}',
                      status: completeCount == steps.length
                          ? AppStatus.success
                          : AppStatus.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress, minHeight: 8),
                const SizedBox(height: 12),
                ...steps.map(
                  (step) => _SetupStepTile(
                    step: step,
                    isNext: !step.complete &&
                        steps.takeWhile((item) => item.complete).length ==
                            steps.indexOf(step),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SetupStep {
  final String title;
  final String detail;
  final bool complete;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SetupStep({
    required this.title,
    required this.detail,
    required this.complete,
    this.actionLabel,
    this.onAction,
  });
}

class _SetupStepTile extends StatelessWidget {
  final _SetupStep step;
  final bool isNext;

  const _SetupStepTile({required this.step, required this.isNext});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        step.complete ? Icons.check_circle : Icons.radio_button_unchecked,
        color: step.complete
            ? Theme.of(context).colorScheme.primary
            : muted,
      ),
      title: Text(
        step.title,
        style: TextStyle(fontWeight: isNext ? FontWeight.w800 : FontWeight.w600),
      ),
      subtitle: Text(step.detail),
      trailing: step.complete
          ? const Text('Done')
          : TextButton(
              onPressed: step.onAction,
              child: Text(step.actionLabel ?? 'Open'),
            ),
    );
  }
}
