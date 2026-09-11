import 'package:flutter/material.dart';
import 'package:smart_monitoring_system/screens/auth/login_screen.dart';
import 'package:get_it/get_it.dart';
import '../../services/package_service.dart';
import 'cashier_pos.dart';
import 'price_checker_screen.dart';
import 'ewallet_transfer_screen.dart';
import '../../models/user.dart';
import '../../utils/app_localizations.dart';
import '../../utils/responsive_utils.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';
import '../../services/attendance_service.dart';
import '../../services/pos_service.dart';
import '../../theme.dart';
import '../../utils/interaction_feedback.dart';
import 'package:smart_monitoring_system/widgets/app_design_system.dart';
import '../shared/settings_screen.dart';

class CashierDashboard extends StatelessWidget {
  final User user;

  const CashierDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final packageService = GetIt.I<PackageService>();
    final pos = GetIt.I<POSService>();
    return AnimatedBuilder(
      animation: Listenable.merge([packageService, pos]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.t('cashier_dashboard')),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: const HeaderClock(),
            ),
            IconButton(
              tooltip: AppLocalizations.t('sign_out'),
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final confirmed = await showAppDestructiveConfirmation(
                  context,
                  title: 'Sign out?',
                  message:
                      'You will need to sign in again to access this business.',
                  confirmLabel: 'Sign out',
                );
                if (!confirmed || !context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 700
            ? NavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (index) {
                  InteractionFeedback.tap();
                  switch (index) {
                    case 1:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CashierPOS(cashierName: user.name),
                        ),
                      );
                    case 2:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PriceCheckerScreen(),
                        ),
                      );
                    case 3:
                      if (!packageService.hasAttendanceAccess) {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Feature locked'),
                            content: const Text(
                              'Attendance is available in the Premium package and above.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _AttendanceCard(user: user),
                          ),
                        ),
                      );
                    case 4:
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.point_of_sale_outlined),
                    selectedIcon: Icon(Icons.point_of_sale),
                    label: 'POS',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.qr_code_scanner_outlined),
                    selectedIcon: Icon(Icons.qr_code_scanner),
                    label: 'Check price',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.access_time_outlined),
                    selectedIcon: Icon(Icons.access_time),
                    label: 'Attendance',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              )
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: ResponsiveUtils.responsivePadding(
                MediaQuery.sizeOf(context).width,
              ),
              child: ListView(
                children: [
                  AppPageHeader(
                    title: 'Cashier dashboard',
                    subtitle:
                        'Welcome, ${user.name}. Start a sale or access your cashier tools.',
                    breadcrumbs: const ['Home', 'Cashier'],
                    action: FilledButton.icon(
                      onPressed: () {
                        InteractionFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CashierPOS(cashierName: user.name),
                          ),
                        );
                      },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('New sale'),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 700 ? 3 : 1;
                      return GridView.count(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 1 ? 3 : 1.7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          AppMetricCard(
                            label: 'Products ready to sell',
                            value:
                                '${pos.products.where((p) => p.quantity > 0).length}',
                            icon: Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            detail: 'Items with available stock',
                          ),
                          AppMetricCard(
                            label: 'Cart items',
                            value:
                                '${pos.cart.fold<int>(0, (sum, item) => sum + item.quantity)}',
                            icon: Icons.shopping_cart_outlined,
                            color: AppColors.accentTeal,
                            detail: 'Current open order',
                          ),
                          AppMetricCard(
                            label: 'Shift tools',
                            value: packageService.hasAttendanceAccess
                                ? 'Ready'
                                : 'Locked',
                            icon: Icons.access_time,
                            color: packageService.hasAttendanceAccess
                                ? AppColors.successGreen
                                : AppColors.warningOrange,
                            detail: 'Attendance and payment features',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = ResponsiveUtils.columnsForWidth(
                        constraints.maxWidth,
                      );

                      final items = <Widget>[
                        if (packageService.hasAttendanceAccess)
                          _DashboardSquareTile(
                            icon: Icons.access_time,
                            color: Colors.indigo,
                            title: AppLocalizations.t('attendance'),
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: _AttendanceCard(user: user),
                                ),
                              ),
                            ),
                          ),
                        _DashboardSquareTile(
                          icon: Icons.point_of_sale,
                          color: Colors.green,
                          title: AppLocalizations.t('open_pos'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CashierPOS(cashierName: user.name),
                              ),
                            );
                          },
                        ),
                        _DashboardSquareTile(
                          icon: Icons.qr_code_scanner,
                          color: Colors.blue,
                          title: AppLocalizations.t('price_checker'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PriceCheckerScreen(),
                              ),
                            );
                          },
                        ),
                      ];

                      // E-Wallet tile (always visible; locked if no access)
                      items.add(
                        packageService.hasEWalletAccess
                            ? _DashboardSquareTile(
                                icon: Icons.account_balance_wallet,
                                color: Colors.amber,
                                title: AppLocalizations.t('ewallet_transfer'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EWalletTransferScreen(
                                        cashierName: user.name,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _DashboardSquareTile(
                                icon: Icons.lock_outline,
                                color: Colors.grey,
                                title: AppLocalizations.t('ewallet_transfer'),
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Feature Locked'),
                                    content: const Text(
                                      'This feature is only available in the Standard package and above.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(
                                          AppLocalizations.t('close'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      );

                      return GridView(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: ResponsiveUtils.isMobile(context)
                              ? 1.05
                              : 1,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: items,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _DashboardCard removed — replaced by square tiles in dashboard layout

class _DashboardSquareTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _DashboardSquareTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppActionTile(icon: icon, color: color, title: title, onTap: onTap);
  }
}

class _AttendanceCard extends StatefulWidget {
  final User user;

  const _AttendanceCard({required this.user});

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard> {
  List<AttendanceEntry> _entries = [];
  bool _loading = true;
  String _nextLabel = 'IN';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AttendanceService.instance.loadEntries(widget.user.id);
    final nextType = await AttendanceService.instance.nextTypeForUser(
      widget.user.id,
    );
    setState(() {
      _entries = list.reversed.toList(); // show newest first
      _nextLabel = _friendlyLabel(nextType);
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final list = await AttendanceService.instance.toggle(widget.user.id);
    final nextType = await AttendanceService.instance.nextTypeForUser(
      widget.user.id,
    );
    setState(() {
      _entries = list.reversed.toList();
      _nextLabel = _friendlyLabel(nextType);
      _loading = false;
    });
    final last = _entries.isNotEmpty ? _entries.first : null;
    if (last != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_friendlyLabel(last.type)} @ ${_formatTime(last.time)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _friendlyLabel(String type) {
    switch (type) {
      case 'LUNCH':
        return 'LB';
      case 'SNACK':
        return 'SB';
      case 'OUT':
        return 'OUT';
      case 'IN':
      default:
        return 'IN';
    }
  }

  String _formatTime(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextLabel;
    return SizedBox(
      width: ResponsiveUtils.dialogWidth(MediaQuery.sizeOf(context).width),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.t('attendance'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('${AppLocalizations.t('next')}: $next'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: Text(next),
            onPressed: _loading ? null : _toggle,
          ),
          const SizedBox(height: 12),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _entries.isEmpty
                  ? Text(AppLocalizations.t('no_records'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _entries.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final e = _entries[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: e.type == 'IN'
                                ? Colors.green
                                : (e.type == 'OUT' ? Colors.red : Colors.amber),
                            child: Text(
                              _friendlyLabel(e.type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          title: Text(_formatTime(e.time)),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
