import 'package:flutter/material.dart';
import 'package:smart_monitoring_system/screens/auth/login_screen.dart';
import 'package:get_it/get_it.dart';
import '../../services/package_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/ai_help_button.dart';
import '../../utils/responsive_utils.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';
import 'manage_users_screen.dart';
// Removed Manage Admin Account from Admin Dashboard
import 'manage_products.dart';
import 'reports_screen.dart';
import 'business_registration_screen.dart';
import 'manage_attendance_screen.dart';
import 'payroll_screen.dart';
// Removed owner dashboard quick link; imports not needed

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final packageService = GetIt.I<PackageService>();
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
            padding: EdgeInsets.all(
              ResponsiveUtils.spacingForWidth(MediaQuery.sizeOf(context).width),
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
                        'Welcome, Admin',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
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
                        packageService.hasAttendanceAccess
                            ? _DashboardSquareTile(
                                icon: Icons.access_time,
                                color: Colors.indigo,
                                title: AppLocalizations.t('manage_attendance'),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ManageAttendanceScreen(),
                                  ),
                                ),
                              )
                            : _DashboardSquareTile(
                                icon: Icons.lock_outline,
                                color: Colors.grey,
                                title: AppLocalizations.t('manage_attendance'),
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
                        packageService.hasPayrollAccess
                            ? _DashboardSquareTile(
                                icon: Icons.attach_money,
                                color: Colors.tealAccent.shade700,
                                title: AppLocalizations.t('manage_payroll'),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminPayrollScreen(),
                                  ),
                                ),
                              )
                            : _DashboardSquareTile(
                                icon: Icons.lock_outline,
                                color: Colors.grey,
                                title: AppLocalizations.t('manage_payroll'),
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
