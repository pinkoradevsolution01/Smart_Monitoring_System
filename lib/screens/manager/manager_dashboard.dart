import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_monitoring_system/screens/auth/login_screen.dart';
import 'package:smart_monitoring_system/screens/owner/cctv_screen.dart';
import 'package:smart_monitoring_system/screens/owner/sales_report_screen.dart';
import 'package:smart_monitoring_system/screens/owner/backup_restore_screen.dart';
import 'package:smart_monitoring_system/screens/owner/supplier_management_screen.dart';
import 'package:smart_monitoring_system/screens/owner/for_delivery_screen.dart';
import 'package:smart_monitoring_system/screens/shared/inventory_screen.dart';
import 'package:smart_monitoring_system/screens/cashier/cashier_pos.dart';
import 'package:smart_monitoring_system/screens/cashier/price_checker_screen.dart';
import 'package:smart_monitoring_system/screens/cashier/ewallet_transfer_screen.dart';
import '../../models/user.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/ai_help_button.dart';
import '../../services/package_service.dart';
import '../../services/attendance_service.dart';
import '../../utils/responsive_utils.dart';

class ManagerDashboard extends StatelessWidget {
  final User user;

  const ManagerDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final packageService = GetIt.I<PackageService>();

    return AnimatedBuilder(
      animation: packageService,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(AppLocalizations.t('manager_dashboard')),
          actions: [
            IconButton(
              tooltip: AppLocalizations.t('sign_out'),
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        floatingActionButton: const AIHelpButton(),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: EdgeInsets.all(
                ResponsiveUtils.responsivePadding(
                  MediaQuery.sizeOf(context).width,
                ).left,
              ),
              child: ListView(
                children: [
                  // Dashboard welcome section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome, ${user.name}',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
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
                          icon: Icons.bar_chart,
                          color: Colors.purple,
                          title: AppLocalizations.t('view_sales_reports'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SalesReportScreen(),
                              ),
                            );
                          },
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
                          color: Colors.teal,
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

                      // E-Wallet tile
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

                      if (packageService.hasCCTVAccess) {
                        items.add(
                          _DashboardSquareTile(
                            icon: Icons.camera_alt,
                            color: Colors.blue,
                            title: AppLocalizations.t('monitor_cctv'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CCTVScreen()),
                            ),
                          ),
                        );
                      }

                      items.add(
                        _DashboardSquareTile(
                          icon: Icons.inventory,
                          color: Colors.orange,
                          title: AppLocalizations.t('inventory_status'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InventoryScreen(user: user),
                              ),
                            );
                          },
                        ),
                      );

                      // Supplier Management
                      items.add(
                        packageService.hasSupplierManagementAccess
                            ? _DashboardSquareTile(
                                icon: Icons.group_work,
                                color: Colors.brown,
                                title: AppLocalizations.t(
                                  'supplier_management',
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SupplierManagementScreen(),
                                    ),
                                  );
                                },
                              )
                            : _DashboardSquareTile(
                                icon: Icons.lock_outline,
                                color: Colors.grey,
                                title: AppLocalizations.t(
                                  'supplier_management',
                                ),
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Feature Locked'),
                                    content: const Text(
                                      'This feature is only available in the Premium package and above.',
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

                      if (packageService.hasDeliveryManagementAccess) {
                        items.add(
                          _DashboardSquareTile(
                            icon: Icons.local_shipping,
                            color: Colors.cyan,
                            title: AppLocalizations.t('for_delivery'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForDeliveryScreen(user: user),
                              ),
                            ),
                          ),
                        );
                      }

                      // Backup & Restore
                      items.add(
                        packageService.hasBackupRestoreAccess
                            ? _DashboardSquareTile(
                                icon: Icons.backup,
                                color: Colors.deepPurple,
                                title: 'Backup & Restore',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BackupRestoreScreen(),
                                    ),
                                  );
                                },
                              )
                            : _DashboardSquareTile(
                                icon: Icons.lock_outline,
                                color: Colors.grey,
                                title: 'Backup & Restore',
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
                          childAspectRatio: 1,
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
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      _entries = list.reversed.toList();
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
