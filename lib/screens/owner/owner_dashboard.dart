import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_monitoring_system/screens/auth/login_screen.dart';
import 'package:smart_monitoring_system/screens/owner/cctv_screen.dart';
import 'package:smart_monitoring_system/screens/owner/manage_owner_account_screen.dart';
import 'package:smart_monitoring_system/screens/admin/admin_dashboard.dart';
import 'package:smart_monitoring_system/screens/owner/sales_report_screen.dart';
import 'package:smart_monitoring_system/screens/owner/backup_restore_screen.dart';
import 'package:smart_monitoring_system/screens/owner/supplier_management_screen.dart';
import 'package:smart_monitoring_system/screens/owner/for_delivery_screen.dart';
import 'package:smart_monitoring_system/screens/owner/customer_management_screen.dart';
import 'package:smart_monitoring_system/screens/owner/loyalty_rewards_screen.dart';
import 'package:smart_monitoring_system/screens/shared/inventory_screen.dart';
import 'package:smart_monitoring_system/screens/cashier/cashier_pos.dart';
import 'package:smart_monitoring_system/screens/cashier/price_checker_screen.dart';
import 'package:smart_monitoring_system/screens/cashier/ewallet_transfer_screen.dart';
import '../../models/user.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/ai_help_button.dart';
import '../../services/package_service.dart';
import '../../services/supabase_sync_service.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';
import 'package:smart_monitoring_system/screens/shared/settings_screen.dart';

class OwnerDashboard extends StatefulWidget {
  final User user;
  final bool showManageAccount;

  const OwnerDashboard({
    super.key,
    required this.user,
    this.showManageAccount = false,
  });

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  @override
  void initState() {
    super.initState();
    // If showManageAccount is true, show the manage account screen after a brief delay
    if (widget.showManageAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showManageAccountScreen();
      });
    }
  }

  void _showManageAccountScreen() {
    showFullScreenModal(context, const ManageOwnerAccountScreen());
  }

  void showFullScreenModal(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen, fullscreenDialog: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packageService = GetIt.I<PackageService>();

    return AnimatedBuilder(
      animation: packageService,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(AppLocalizations.t('owner_dashboard')),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: const HeaderClock(),
            ),
            IconButton(
              tooltip: AppLocalizations.t('settings'),
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.t('sign_out'),
              icon: const Icon(Icons.logout),
              onPressed: () {
                GetIt.I<SupabaseSyncService>().clearBusinessContext();
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
              padding: const EdgeInsets.all(12.0),
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
                          'Welcome, ${widget.user.name}',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int cols = 1;
                      if (constraints.maxWidth >= 1000) {
                        cols = 4;
                      } else if (constraints.maxWidth >= 800) {
                        cols = 3;
                      } else if (constraints.maxWidth >= 600) {
                        cols = 2;
                      }

                      final items = <Widget>[
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
                        // Manage Users tile removed from Owner dashboard
                        _DashboardSquareTile(
                          icon: Icons.person,
                          color: Colors.blue,
                          title: 'Manage Owner Account',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ManageOwnerAccountScreen(),
                              ),
                            );
                          },
                        ),
                        _DashboardSquareTile(
                          icon: Icons.admin_panel_settings,
                          color: Colors.indigo,
                          title: AppLocalizations.t('admin_dashboard'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminDashboard(),
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
                                    CashierPOS(cashierName: widget.user.name),
                              ),
                            );
                          },
                        ),
                        _DashboardSquareTile(
                          icon: Icons.people_alt,
                          color: Colors.deepOrange,
                          title: AppLocalizations.t('customer_management'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CustomerManagementScreen(),
                              ),
                            );
                          },
                        ),
                        _DashboardSquareTile(
                          icon: Icons.loyalty,
                          color: Colors.pink,
                          title: AppLocalizations.t('loyalty_rewards'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoyaltyRewardsScreen(),
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
                                        cashierName: widget.user.name,
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

                      // CCTV tile (always visible; locked if no access)
                      items.add(
                        packageService.hasCCTVAccess
                            ? _DashboardSquareTile(
                                icon: Icons.camera_alt,
                                color: Colors.blue,
                                title: AppLocalizations.t('monitor_cctv'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CCTVScreen(),
                                    ),
                                  );
                                },
                              )
                            : _DashboardSquareTile(
                                icon: Icons.lock_outline,
                                color: Colors.grey,
                                title: AppLocalizations.t('monitor_cctv'),
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

                      items.add(
                        _DashboardSquareTile(
                          icon: Icons.inventory,
                          color: Colors.orange,
                          title: AppLocalizations.t('inventory_status'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InventoryScreen(user: widget.user),
                              ),
                            );
                          },
                        ),
                      );

                      // For Delivery
                      items.add(
                        _DashboardSquareTile(
                          icon: Icons.local_shipping,
                          color: Colors.brown,
                          title: 'For Delivery',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ForDeliveryScreen(user: widget.user),
                              ),
                            );
                          },
                        ),
                      );

                      // Supplier Management (always visible; locked if no access)
                      items.add(
                        packageService.hasSupplierManagementAccess
                            ? _DashboardSquareTile(
                                icon: Icons.local_shipping,
                                color: Colors.indigo,
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

                      // Backup & Restore (local backup OR cloud sync)
                      items.add(
                        (packageService.hasBackupRestoreAccess ||
                                packageService.hasCloudSyncAccess)
                            ? _DashboardSquareTile(
                                icon: Icons.backup,
                                color: Colors.deepPurple,
                                title: 'Backup & Restore',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BackupRestoreScreen(),
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
