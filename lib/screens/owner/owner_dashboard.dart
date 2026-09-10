import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_monitoring_system/screens/auth/login_screen.dart';
import 'package:smart_monitoring_system/screens/owner/cctv_screen.dart';
import 'package:smart_monitoring_system/screens/owner/manage_owner_account_screen.dart';
import 'package:smart_monitoring_system/screens/admin/admin_dashboard.dart';
import 'package:smart_monitoring_system/screens/admin/financial_compliance_screen.dart';
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
import '../../models/sale.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/ai_help_button.dart';
import '../../utils/responsive_utils.dart';
import '../../services/package_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/pos_service.dart';
import '../../theme.dart';
import '../../utils/interaction_feedback.dart';
import '../../utils/currency_formatter.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';
import 'package:smart_monitoring_system/screens/shared/settings_screen.dart';
import 'package:smart_monitoring_system/widgets/app_design_system.dart';
import 'package:smart_monitoring_system/widgets/first_time_setup_card.dart';
import 'package:smart_monitoring_system/widgets/package_upgrade_dialog.dart';

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
    final pos = GetIt.I<POSService>();
    final lowStockCount = pos.products
        .where((product) => product.lowStock || product.quantity == 0)
        .length;
    final now = DateTime.now();
    final todaySales = pos.recentSales.where(
      (sale) =>
          sale.status == SaleStatus.completed &&
          sale.saleDate.year == now.year &&
          sale.saleDate.month == now.month &&
          sale.saleDate.day == now.day,
    );
    final todayRevenue = todaySales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final productsById = {for (final product in pos.products) product.id: product};
    final estimatedProfit = todaySales.fold<double>(0, (sum, sale) {
      final saleProfit = sale.items.fold<double>(0, (itemSum, item) {
        final buyingPrice =
            productsById[item.productId]?.buyingPrice ?? item.unitPrice;
        return itemSum + (item.total - (buyingPrice * item.quantity));
      });
      return sum + saleProfit;
    });
    final pendingOrders = pos.recentSales
        .where((sale) => sale.status == SaleStatus.pending)
        .length;

    return AnimatedBuilder(
      animation: Listenable.merge([packageService, pos]),
      builder: (context, _) => Scaffold(
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
              onPressed: () async {
                final confirmed = await showAppDestructiveConfirmation(
                  context,
                  title: 'Sign out?',
                  message:
                      'You will need to sign in again to access this business.',
                  confirmLabel: 'Sign out',
                );
                if (!confirmed || !context.mounted) return;
                GetIt.I<SupabaseSyncService>().clearBusinessContext();
                await GoogleAuthService().clearSession();
                if (!mounted) return;
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
                          builder: (_) =>
                              CashierPOS(cashierName: widget.user.name),
                        ),
                      );
                    case 2:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InventoryScreen(user: widget.user),
                        ),
                      );
                    case 3:
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SalesReportScreen()),
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
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: 'Inventory',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Reports',
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
                    title: 'Owner dashboard',
                    subtitle:
                        'Welcome, ${widget.user.name}. Review operations and choose a workspace.',
                    breadcrumbs: const ['Home', 'Dashboard'],
                    action: FilledButton.icon(
                      onPressed: () {
                        InteractionFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CashierPOS(cashierName: widget.user.name),
                          ),
                        );
                      },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('Open POS'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FirstTimeSetupCard(owner: widget.user),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                      return GridView.count(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 1 ? 3 : 1.65,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          AppMetricCard(
                            label: 'Sales today',
                            value: AppCurrency.peso(todayRevenue),
                            icon: Icons.payments_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            detail: '${todaySales.length} completed transactions',
                          ),
                          AppMetricCard(
                            label: 'Estimated profit',
                            value: AppCurrency.peso(estimatedProfit),
                            icon: Icons.trending_up_outlined,
                            color: AppColors.successGreen,
                            detail: 'Based on current product cost',
                          ),
                          AppMetricCard(
                            label: 'Low-stock alerts',
                            value: '$lowStockCount',
                            icon: Icons.warning_amber_rounded,
                            color: lowStockCount == 0
                                ? AppColors.successGreen
                                : AppColors.warningOrange,
                            detail: lowStockCount == 0
                                ? 'Inventory levels look healthy'
                                : 'Review items that need restocking',
                          ),
                          AppMetricCard(
                            label: 'Pending orders',
                            value: '$pendingOrders',
                            icon: Icons.pending_actions_outlined,
                            color: AppColors.accentTeal,
                            detail: pendingOrders == 0
                                ? 'No pending orders'
                                : 'Orders awaiting completion',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Workspaces',
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
                        packageService.hasExpenseTrackingAccess
                            ? _DashboardSquareTile(
                                icon: Icons.receipt_long_outlined,
                                color: Colors.deepPurple,
                                title: 'Expenses & BIR reports',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FinancialComplianceScreen(),
                                  ),
                                ),
                              )
                            : _DashboardSquareTile(
                                icon: Icons.lock_outline,
                                color: Colors.grey,
                                title: 'Expenses & BIR reports',
                                onTap: () => PackageUpgradeDialog.show(
                                  context,
                                  'Expense tracking and BIR-ready reports',
                                ),
                              ),
                      );

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
