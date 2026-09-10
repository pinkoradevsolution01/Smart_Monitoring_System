import 'package:flutter/material.dart';
import 'package:smart_monitoring_system/screens/auth/login_screen.dart';
import 'package:get_it/get_it.dart';
import '../../services/package_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../services/pos_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/ai_help_button.dart';
import '../../utils/responsive_utils.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';
import 'manage_users_screen.dart';
// Removed Manage Admin Account from Admin Dashboard
import 'manage_products.dart';
import 'reports_screen.dart';
import 'financial_compliance_screen.dart';
import 'business_registration_screen.dart';
import 'manage_attendance_screen.dart';
import 'payroll_screen.dart';
import '../shared/settings_screen.dart';
import '../../theme.dart';
import '../../widgets/app_design_system.dart';
import '../../widgets/package_upgrade_dialog.dart';
// Removed owner dashboard quick link; imports not needed

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final packageService = GetIt.I<PackageService>();
    final pos = GetIt.I<POSService>();
    final users = GetIt.I<UserService>();
    final lowStockCount = pos.products
        .where((product) => product.lowStock || product.quantity <= 0)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('admin_dashboard')),
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
                message: 'You will need to sign in again to access this business.',
                confirmLabel: 'Sign out',
              );
              if (!confirmed || !context.mounted) return;
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
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 700
          ? NavigationBar(
              selectedIndex: 0,
              // Five operational destinations are useful on phones, but five
              // persistent labels are too wide on narrow Android screens.
              // Icons stay visible and the active destination keeps its label.
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (index) {
                switch (index) {
                  case 1:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageUsers()),
                    );
                    break;
                  case 2:
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageProductsScreen(),
                      ),
                    );
                    break;
                  case 3:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    );
                    break;
                  case 4:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Operations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Management',
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
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: EdgeInsets.all(
              ResponsiveUtils.spacingForWidth(MediaQuery.sizeOf(context).width),
            ),
            child: ListView(
              children: [
                AppPageHeader(
                  title: 'Admin dashboard',
                  subtitle: 'Monitor inventory, staff activity, and approvals from one workspace.',
                  breadcrumbs: const ['Home', 'Administration'],
                  action: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BusinessRegistrationScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Add business'),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 3 : 1;
                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 1 ? 3 : 1.7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        AppMetricCard(
                          label: 'Inventory alerts',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: lowStockCount == 0
                              ? AppColors.successGreen
                              : AppColors.warningOrange,
                          detail: lowStockCount == 0
                              ? 'No low-stock products'
                              : 'Items need restocking',
                        ),
                        AppMetricCard(
                          label: 'Active staff',
                          value: '${users.activeUsers.length}',
                          icon: Icons.groups_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          detail: 'Users available for operations',
                        ),
                        AppMetricCard(
                          label: 'Approvals',
                          value: packageService.hasAttendanceAccess
                              ? 'Ready'
                              : 'Review',
                          icon: Icons.verified_user_outlined,
                          color: AppColors.accentTeal,
                          detail: 'Attendance and package controls',
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
                      children: [
                        // Manage Admin Account intentionally removed from Admin Dashboard
                        _DashboardSquareTile(
                          icon: Icons.store,
                          color: Colors.teal,
                          title: AppLocalizations.t('business_registration'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const BusinessRegistrationScreen(),
                            ),
                          ),
                        ),
                        _DashboardSquareTile(
                          icon: Icons.people,
                          color: Colors.blue,
                          title: AppLocalizations.t('manage_users'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageUsers(),
                            ),
                          ),
                        ),
                        if (packageService.hasAttendanceAccess)
                          _DashboardSquareTile(
                            icon: Icons.access_time,
                            color: Colors.indigo,
                            title: AppLocalizations.t('manage_attendance'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageAttendanceScreen(),
                              ),
                            ),
                          ),
                        _DashboardSquareTile(
                          icon: Icons.inventory,
                          color: Colors.orange,
                          title: AppLocalizations.t('manage_products'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageProductsScreen(),
                            ),
                          ),
                        ),
                        if (packageService.hasPayrollAccess)
                          _DashboardSquareTile(
                            icon: Icons.attach_money,
                            color: Colors.tealAccent.shade700,
                            title: AppLocalizations.t('manage_payroll'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminPayrollScreen(),
                              ),
                            ),
                          ),
                        _DashboardSquareTile(
                          icon: Icons.bar_chart,
                          color: Colors.purple,
                          title: AppLocalizations.t('reports'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportsScreen(),
                            ),
                          ),
                        ),
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
                      ],
                    );
                  },
                ),
                const SizedBox(height: 100),
                const SizedBox(height: 16),
                Card(
                  color: Colors.red.shade50,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.delete_forever, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.t('reset_all_data'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.t('reset_all_data_desc'),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.security, color: Colors.red),
                            label: Text(
                              AppLocalizations.t('reset').toUpperCase(),
                              style: const TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                            onPressed: () => _showResetDialog(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(AppLocalizations.t('confirm_reset_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.t('confirm_reset_message')),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('type_reset_label'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (controller.text.trim().toUpperCase() == 'RESET') {
                  await DatabaseService().resetAllData();
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.t('reset_success')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.t('reset')),
            ),
          ],
        );
      },
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
    return AppActionTile(
      icon: icon,
      color: color,
      title: title,
      onTap: onTap,
    );
  }
}
