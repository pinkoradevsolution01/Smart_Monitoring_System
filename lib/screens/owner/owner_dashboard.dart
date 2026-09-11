import 'dart:async';
import 'dart:ui';

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
import '../../models/product.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/ai_help_button.dart';
import '../../utils/responsive_utils.dart';
import '../../services/package_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/pos_service.dart';
import '../../services/smart_plus_notification_service.dart';
import '../../theme.dart';
import '../../utils/interaction_feedback.dart';
import '../../utils/currency_formatter.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';
import 'package:smart_monitoring_system/widgets/smart_plus_notification_button.dart';
import 'package:smart_monitoring_system/screens/shared/settings_screen.dart';
import 'package:smart_monitoring_system/screens/shared/user_manual_screen.dart';
import 'package:smart_monitoring_system/widgets/app_design_system.dart';
import 'package:smart_monitoring_system/widgets/first_time_setup_card.dart';
import 'package:smart_monitoring_system/widgets/package_upgrade_dialog.dart';
import 'package:smart_monitoring_system/services/setup_progress_service.dart';

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
  bool _celebratingSetupCompletion = false;
  final List<Sale> _dashboardSales = <Sale>[];
  final List<Product> _dashboardProducts = <Product>[];
  Timer? _metricsRefreshDebounce;
  int _metricsRequest = 0;
  bool _metricsLoading = true;
  late final POSService _pos;
  late final SupabaseSyncService _sync;

  @override
  void initState() {
    super.initState();
    _pos = GetIt.I<POSService>();
    _sync = GetIt.I<SupabaseSyncService>();
    _pos.addListener(_scheduleMetricsRefresh);
    _sync.addListener(_scheduleMetricsRefresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMetrics());
    // If showManageAccount is true, show the manage account screen after a brief delay
    if (widget.showManageAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showManageAccountScreen();
      });
    }
  }

  @override
  void dispose() {
    _metricsRefreshDebounce?.cancel();
    _pos.removeListener(_scheduleMetricsRefresh);
    _sync.removeListener(_scheduleMetricsRefresh);
    super.dispose();
  }

  void _scheduleMetricsRefresh() {
    _metricsRefreshDebounce?.cancel();
    _metricsRefreshDebounce = Timer(
      const Duration(milliseconds: 350),
      _refreshMetrics,
    );
  }

  Future<void> _refreshMetrics() async {
    final request = ++_metricsRequest;
    try {
      final results = await Future.wait<Object>([
        _pos.databaseService.getAllSales(),
        _pos.databaseService.getAllProducts(),
      ]);
      if (!mounted || request != _metricsRequest) return;
      setState(() {
        _dashboardSales
          ..clear()
          ..addAll(results[0] as List<Sale>);
        _dashboardProducts
          ..clear()
          ..addAll(results[1] as List<Product>);
        _metricsLoading = false;
      });
    } catch (_) {
      if (mounted && request == _metricsRequest) {
        setState(() => _metricsLoading = false);
      }
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

  void _openDrawerDestination(Widget destination) {
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
              child: destination,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 220),
        ),
      );
    });
  }

  Future<void> _celebrateSetupCompletion() async {
    if (_celebratingSetupCompletion) return;
    _celebratingSetupCompletion = true;

    final setup = GetIt.I<SetupProgressService>();
    if (!setup.isComplete || await setup.hasCelebrated(widget.user.id)) {
      _celebratingSetupCompletion = false;
      return;
    }
    await setup.markCelebrated(widget.user.id);
    GetIt.I<SmartPlusNotificationService>().notifySetupCompleted();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Image.asset(
          'assets/branding/smartplus_icon.png',
          width: 58,
          height: 58,
          fit: BoxFit.contain,
        ),
        title: const Text('Congratulations!'),
        content: const Text(
          'Your business setup is complete. The User Manual and SmartPlus are now unlocked. Access SmartPlus AI for better business decisions.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Open SmartPlus'),
          ),
        ],
      ),
    );
    if (mounted) showSmartPlusDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final packageService = GetIt.I<PackageService>();
    final pos = _pos;
    final setupProgress = GetIt.I<SetupProgressService>();
    final lowStockCount = _dashboardProducts
        .where((product) => product.lowStock || product.quantity == 0)
        .length;
    final now = DateTime.now();
    final todaySales = _dashboardSales.where(
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
    final productsById = {
      for (final product in _dashboardProducts) product.id: product,
    };
    final estimatedProfit = todaySales.fold<double>(0, (sum, sale) {
      final saleProfit = sale.items.fold<double>(0, (itemSum, item) {
        final buyingPrice =
            productsById[item.productId]?.buyingPrice ?? item.unitPrice;
        return itemSum + (item.total - (buyingPrice * item.quantity));
      });
      return sum + saleProfit;
    });
    final todayPoints = _dashboardSales
        .where(
          (sale) =>
              sale.status == SaleStatus.completed &&
              sale.saleDate.year == now.year &&
              sale.saleDate.month == now.month &&
              sale.saleDate.day == now.day,
        )
        .fold<int>(0, (sum, sale) => sum + sale.loyaltyPointsEarned);
    final weekStart = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    final weekPoints = _dashboardSales
        .where(
          (sale) =>
              sale.status == SaleStatus.completed &&
              !sale.saleDate.isBefore(weekStart),
        )
        .fold<int>(0, (sum, sale) => sum + sale.loyaltyPointsEarned);

    return AnimatedBuilder(
      animation: Listenable.merge([packageService, pos, setupProgress]),
      builder: (context, _) => Scaffold(
        drawerScrimColor: Colors.black.withValues(alpha: 0.18),
        drawer: _OwnerNavigationDrawer(
          user: widget.user,
          packageService: packageService,
          onOpen: _openDrawerDestination,
          setupComplete: setupProgress.isComplete,
        ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (drawerContext) => IconButton(
              tooltip: 'Open navigation menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(drawerContext).openDrawer(),
            ),
          ),
          title: const SizedBox.shrink(),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: const HeaderClock(),
            ),
            if (setupProgress.isComplete)
              const SmartPlusNotificationButton(),
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
        floatingActionButton: setupProgress.isComplete
            ? const SmartPlusFloatingButton()
            : null,
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
                  FirstTimeSetupCard(
                    owner: widget.user,
                    onCompleted: _celebrateSetupCompletion,
                  ),
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
                            detail: _metricsLoading
                                ? 'Updating business data...'
                                : '${todaySales.length} completed transactions',
                          ),
                          AppMetricCard(
                            label: 'Estimated profit',
                            value: AppCurrency.peso(estimatedProfit),
                            icon: Icons.trending_up_outlined,
                            color: AppColors.successGreen,
                            detail: _metricsLoading
                                ? 'Updating business data...'
                                : 'Based on current product cost',
                          ),
                          AppMetricCard(
                            label: 'Low-stock alerts',
                            value: '$lowStockCount',
                            icon: Icons.warning_amber_rounded,
                            color: lowStockCount == 0
                                ? AppColors.successGreen
                                : AppColors.warningOrange,
                            detail: _metricsLoading
                                ? 'Updating business data...'
                                : lowStockCount == 0
                                ? 'Inventory levels look healthy'
                                : 'Review items that need restocking',
                          ),
                          AppMetricCard(
                            label: 'Customer points',
                            value: '$todayPoints',
                            icon: Icons.workspace_premium_rounded,
                            color: AppColors.accentTeal,
                            detail: _metricsLoading
                                ? 'Updating business data...'
                                : '$weekPoints points earned this week',
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
                                builder: (_) =>
                                    InventoryScreen(user: widget.user),
                              ),
                            );
                          },
                        ),
                      );

                      if (packageService.hasDeliveryManagementAccess) {
                        items.add(
                          _DashboardSquareTile(
                            icon: Icons.local_shipping,
                            color: Colors.brown,
                            title: 'For Delivery',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForDeliveryScreen(user: widget.user),
                              ),
                            ),
                          ),
                        );
                      }

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

/// This menu belongs to the owner dashboard shell, so it behaves consistently
/// on Android, Windows, and the web. Developer tools are intentionally absent.
class _OwnerNavigationDrawer extends StatelessWidget {
  final User user;
  final PackageService packageService;
  final ValueChanged<Widget> onOpen;
  final bool setupComplete;

  const _OwnerNavigationDrawer({
    required this.user,
    required this.packageService,
    required this.onOpen,
    required this.setupComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    return Drawer(
      width: isWide ? 340 : 304,
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: colors.surface.withValues(alpha: 0.86),
            child: SafeArea(
              right: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: Text(
                            user.name.trim().isEmpty
                                ? 'O'
                                : user.name.trim()[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Owner workspace',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close navigation menu',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const _DrawerSectionLabel('Dashboard'),
                  _DrawerNavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Owner Dashboard',
                    selected: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const _DrawerSectionLabel('Operations'),
                  _DrawerNavItem(
                    icon: Icons.point_of_sale_rounded,
                    label: 'Point of Sale',
                    onTap: () => onOpen(CashierPOS(cashierName: user.name)),
                  ),
                  _DrawerNavItem(
                    icon: Icons.inventory_2_rounded,
                    label: 'Inventory',
                    onTap: () => onOpen(InventoryScreen(user: user)),
                  ),
                  if (packageService.hasDeliveryManagementAccess)
                    _DrawerNavItem(
                      icon: Icons.local_shipping_rounded,
                      label: 'Delivery',
                      onTap: () => onOpen(ForDeliveryScreen(user: user)),
                    ),
                  if (packageService.hasCCTVAccess)
                    _DrawerNavItem(
                      icon: Icons.videocam_rounded,
                      label: 'Monitor CCTV',
                      onTap: () => onOpen(const CCTVScreen()),
                    ),
                  const _DrawerSectionLabel('Management'),
                  _DrawerNavItem(
                    icon: Icons.people_alt_rounded,
                    label: 'Customers',
                    onTap: () => onOpen(const CustomerManagementScreen()),
                  ),
                  _DrawerNavItem(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Loyalty rewards',
                    onTap: () => onOpen(const LoyaltyRewardsScreen()),
                  ),
                  if (packageService.hasSupplierManagementAccess)
                    _DrawerNavItem(
                      icon: Icons.local_shipping_outlined,
                      label: 'Suppliers',
                      onTap: () => onOpen(const SupplierManagementScreen()),
                    ),
                  if (packageService.hasExpenseTrackingAccess)
                    _DrawerNavItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Expenses & BIR reports',
                      onTap: () => onOpen(const FinancialComplianceScreen()),
                    ),
                  const _DrawerSectionLabel('Reports & settings'),
                  _DrawerNavItem(
                    icon: Icons.assessment_rounded,
                    label: 'Sales reports',
                    onTap: () => onOpen(const SalesReportScreen()),
                  ),
                  if (packageService.hasBackupRestoreAccess)
                    _DrawerNavItem(
                      icon: Icons.backup_rounded,
                      label: 'Backup & restore',
                      onTap: () => onOpen(const BackupRestoreScreen()),
                    ),
                  _DrawerNavItem(
                    icon: Icons.manage_accounts_rounded,
                    label: 'Owner account',
                    onTap: () => onOpen(const ManageOwnerAccountScreen()),
                  ),
                  _DrawerNavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () => onOpen(const SettingsScreen()),
                  ),
                  if (setupComplete)
                    _DrawerNavItem(
                      icon: Icons.menu_book_rounded,
                      label: 'User Manual',
                      subtitle: 'Guides and troubleshooting',
                      onTap: () => onOpen(const UserManualScreen()),
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

class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  const _DrawerSectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
      );
}

class _DrawerNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  @override
  State<_DrawerNavItem> createState() => _DrawerNavItemState();
}

class _DrawerNavItemState extends State<_DrawerNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = widget.selected ? colors.onPrimaryContainer : colors.onSurface;
    return Semantics(
      button: true,
      label: 'Open ${widget.label}',
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: widget.selected
                ? colors.primaryContainer.withValues(alpha: 0.82)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(widget.icon, color: foreground, size: 21),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: foreground,
                                  fontWeight: widget.selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: foreground.withValues(alpha: 0.72),
                                  ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: foreground),
                  ],
                ),
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
    return AppActionTile(icon: icon, color: color, title: title, onTap: onTap);
  }
}
