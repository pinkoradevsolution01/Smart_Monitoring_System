import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/package_service.dart';
import '../../services/database_service.dart';
import '../../services/cloud_subscription_service.dart';
import '../../services/developer_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../services/google_auth_service.dart';
import '../../models/pricing_package.dart';
import '../shared/developer_auth_screen.dart';
// removed unused import: package selection is no longer referenced here
import '../auth/login_screen.dart';
import 'activity_logs_screen.dart';
import 'activation_code_generator_screen.dart';
import 'activation_requests_screen.dart';
import 'code_revocation_screen.dart';
import 'customer_activation_screen.dart';
import 'subscription_records_screen.dart';
import 'backend_connection_test.dart';
import 'developer_account_screen.dart';
import 'demo_access_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  final packageService = GetIt.I<PackageService>();
  final cloudSubscriptionService = CloudSubscriptionService();

  @override
  void initState() {
    super.initState();
    // Fetch subscription data on load
    cloudSubscriptionService.fetchSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Developer Dashboard'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              GetIt.I<SupabaseSyncService>().clearBusinessContext();
              await DeveloperAuthScreen.clearAuthentication();
              await GoogleAuthService().clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Welcome
                _buildWelcomeCard(),
                const SizedBox(height: 24),

                // Demo Access Section
                _buildSectionTitle('Quick Demo Access'),
                const SizedBox(height: 12),
                _DeveloperCard(
                  icon: Icons.videogame_asset,
                  color: Colors.indigo,
                  title: 'Demo Access Portal',
                  description:
                      'Temporary in-memory role previews for client demonstrations',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DemoAccessScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                // Package Management Section
                _buildSectionTitle('Package Management'),
                const SizedBox(height: 12),
                _DeveloperCard(
                  icon: Icons.edit_outlined,
                  color: Colors.blueGrey,
                  title: 'Edit Packages',
                  description:
                      'Modify Basic/Standard/Premium/Enterprise details',
                  onTap: () => _showEditPackagesDialog(),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Customer Requests'),
                const SizedBox(height: 12),
                _DeveloperCard(
                  icon: Icons.mail_outline,
                  color: Colors.deepPurple,
                  title: 'Activation Requests',
                  description:
                      'View and fulfill customer activation code requests',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivationRequestsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Cloud Database'),
                const SizedBox(height: 12),
                _buildSubscriptionStatsCard(),
                _DeveloperCard(
                  icon: Icons.cloud_outlined,
                  color: Colors.cyan,
                  title: 'Subscription Records',
                  description:
                      'View all subscription records from cloud database',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionRecordsScreen(
                          cloudSubscriptionService: cloudSubscriptionService,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Data Management'),
                const SizedBox(height: 12),
                _DeveloperCard(
                  icon: Icons.qr_code_2,
                  color: Colors.green,
                  title: 'Activation Code Generator',
                  description: 'Generate and export activation codes to CSV',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivationCodeGeneratorScreen(),
                      ),
                    );
                  },
                ),
                _DeveloperCard(
                  icon: Icons.send,
                  color: Colors.lightGreen,
                  title: 'Send to Customer',
                  description: 'Copy activation codes to send to customers',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerActivationScreen(),
                      ),
                    );
                  },
                ),
                _DeveloperCard(
                  icon: Icons.block,
                  color: Colors.red,
                  title: 'Code Revocation',
                  description: 'Revoke used codes and cancel subscriptions',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CodeRevocationScreen(),
                      ),
                    );
                  },
                ),
                _DeveloperCard(
                  icon: Icons.wifi_tethering,
                  color: Colors.indigo,
                  title: 'System Health & Diagnostics',
                  description: 'Check the Droplet API and MySQL availability',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BackendConnectionTest(),
                      ),
                    );
                  },
                ),
                _DeveloperCard(
                  icon: Icons.cleaning_services,
                  color: Colors.purple,
                  title: 'Clear SharedPreferences',
                  description: 'Clear all app settings and preferences',
                  onTap: () => _showClearPreferencesDialog(),
                ),
                _DeveloperCard(
                  icon: Icons.list_alt,
                  color: Colors.teal,
                  title: 'Activity Logs',
                  description: 'View recent activity and audit logs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivityLogsScreen(),
                      ),
                    );
                  },
                ),
                _DeveloperCard(
                  icon: Icons.subscriptions,
                  color: Colors.indigo,
                  title: 'Subscribers',
                  description: 'View registered subscribers',
                  onTap: () {
                    Navigator.pushNamed(context, '/subscribers');
                  },
                ),
                _DeveloperCard(
                  icon: Icons.delete_forever,
                  color: Colors.red,
                  title: 'Factory Reset',
                  description: 'Delete all data and reset to initial state',
                  onTap: () => _showFactoryResetDialog(),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Account Settings'),
                const SizedBox(height: 12),
                _DeveloperCard(
                  icon: Icons.account_circle,
                  color: Colors.indigo,
                  title: 'Manage Account',
                  description: 'Change developer password and information',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeveloperAccountScreen(),
                      ),
                    );
                  },
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return ListenableBuilder(
      listenable: GetIt.I<DeveloperService>(),
      builder: (context, _) {
        final devService = GetIt.I<DeveloperService>();
        final name = devService.displayName.isNotEmpty
            ? devService.displayName
            : (devService.username.isNotEmpty
                ? devService.username
                : 'Developer');

        return Card(
          color: Colors.grey[850],
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Welcome, $name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Developer tools and settings are below.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionStatsCard() {
    return ListenableBuilder(
      listenable: cloudSubscriptionService,
      builder: (context, _) {
        if (cloudSubscriptionService.isLoading) {
          return const Card(
            color: Color(0xFF2A2A2A),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (cloudSubscriptionService.error != null) {
          return Card(
            color: const Color(0xFF2A2A2A),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    cloudSubscriptionService.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => cloudSubscriptionService.refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          color: const Color(0xFF2A2A2A),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_done, color: Colors.cyan, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Subscription Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () => cloudSubscriptionService.refresh(),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total',
                        cloudSubscriptionService.totalSubscriptions.toString(),
                        Colors.blue,
                        Icons.all_inclusive,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Active',
                        cloudSubscriptionService.activeSubscriptions.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Expired',
                        cloudSubscriptionService.expiredSubscriptions
                            .toString(),
                        Colors.red,
                        Icons.cancel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Unique devices info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.devices, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unique Devices: ${cloudSubscriptionService.uniqueDeviceCount} total • ${cloudSubscriptionService.activeUniqueDeviceCount} active',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 18),
                        color: Colors.amber,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showSubscriptionInfoDialog(),
                        tooltip: 'More info',
                      ),
                    ],
                  ),
                ),
                if (cloudSubscriptionService.packageCounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  const Text(
                    'By Package:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...cloudSubscriptionService.packageCounts.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // removed _buildInfoRow — it was used only by the Current Package card

  void _showClearPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear SharedPreferences'),
        content: const Text(
          'This will clear all app settings including:\n'
          '• Package selection\n'
          '• Theme settings\n'
          '• Language preferences\n'
          '• Motion settings\n\n'
          '⚠️ Database data will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'SharedPreferences cleared. Restart app to see changes.',
                    ),
                    backgroundColor: Colors.purple,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Clear Preferences'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text('Subscription vs Subscribers'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Understanding the difference:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                '📱 Unique Devices (Subscribers)',
                'Count of unique devices/installations that have activated codes. One device can have multiple subscriptions if they activated multiple packages.',
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                '📋 Subscription Records',
                'Total count of all activated codes. If one device activates Basic + Standard packages, that counts as 2 subscription records.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Example:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 1 device activates Basic package = 1 subscriber, 1 record\n'
                      '• Same device activates Standard package = 1 subscriber, 2 records\n'
                      '• Different device activates Premium = 2 subscribers, 3 records',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.devices, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'View "Subscription Records" to see all activations with device IDs and package details.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubscriptionRecordsScreen(
                    cloudSubscriptionService: cloudSubscriptionService,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('View Records'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
      ],
    );
  }

  void _showFactoryResetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Factory Reset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will DELETE ALL DATA:\n'
                '• All products\n'
                '• All sales records\n'
                '• All user accounts\n'
                '• All settings\n'
                '• Package selection\n\n'
                'Type "DELETE" to confirm:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (controller.text.trim().toUpperCase() == 'DELETE') {
                // Clear database
                await DatabaseService().resetAllData();
                // Clear SharedPreferences (including developer auth)
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                // Reset package service
                await packageService.resetSetup();
                if (context.mounted) {
                  // Return to developer authentication screen
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeveloperAuthScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
            child: const Text('Factory Reset'),
          ),
        ],
      ),
    );
  }

  void _showEditPackagesDialog() async {
    final prefs = await SharedPreferences.getInstance();

    // Load current overrides (if any)
    final overrides = <PackageType, Map<String, dynamic>>{};
    for (final pkg in PricingPackage.packages) {
      final key = 'pkg_override_${pkg.type.toString().split('.').last}';
      final raw = prefs.getString(key);
      if (raw != null) {
        try {
          final map = json.decode(raw) as Map<String, dynamic>;
          overrides[pkg.type] = map;
        } catch (e) {
          debugPrint('Failed to parse override for $key: $e');
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) {
          // controllers per package
          final controllers =
              <PackageType, Map<String, TextEditingController>>{};
          for (final pkg in PricingPackage.packages) {
            final o = overrides[pkg.type] ?? {};
            controllers[pkg.type] = {
              'name': TextEditingController(text: o['name'] ?? pkg.name),
              'price': TextEditingController(text: o['price'] ?? pkg.price),
              'oldPrice': TextEditingController(
                text: o['oldPrice'] ?? pkg.oldPrice ?? '',
              ),
              'period': TextEditingController(text: o['period'] ?? pkg.period),
              'description': TextEditingController(
                text: o['description'] ?? pkg.description,
              ),
            };
          }

          return AlertDialog(
            title: const Text('Edit Packages'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: PricingPackage.packages.map((pkg) {
                    final ctrls = controllers[pkg.type]!;
                    return ExpansionTile(
                      title: Text(pkg.name),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: ctrls['name'],
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: ctrls['price'],
                                decoration: const InputDecoration(
                                  labelText: 'Price',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: ctrls['oldPrice'],
                                decoration: const InputDecoration(
                                  labelText: 'Old Price (optional)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: ctrls['period'],
                                decoration: const InputDecoration(
                                  labelText: 'Period (e.g. /month)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: ctrls['description'],
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      // clear override for this package
                                      final key =
                                          'pkg_override_${pkg.type.toString().split('.').last}';
                                      prefs.remove(key);
                                      setState(() {
                                        overrides.remove(pkg.type);
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Override cleared for ${pkg.name}',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Clear Override'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Save all overrides
                  for (final pkg in PricingPackage.packages) {
                    final ctrls = controllers[pkg.type]!;
                    final map = {
                      'name': ctrls['name']!.text.trim(),
                      'price': ctrls['price']!.text.trim(),
                      'oldPrice': ctrls['oldPrice']!.text.trim(),
                      'period': ctrls['period']!.text.trim(),
                      'description': ctrls['description']!.text.trim(),
                    };
                    final key =
                        'pkg_override_${pkg.type.toString().split('.').last}';
                    await prefs.setString(key, json.encode(map));
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Package overrides saved')),
                    );
                    setState(() {});
                  }
                },
                child: const Text('Save All'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _DeveloperCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[850],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}
