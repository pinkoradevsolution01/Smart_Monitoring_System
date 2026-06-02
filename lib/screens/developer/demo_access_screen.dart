import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/demo_access_service.dart';
import '../../services/user_service.dart';
import '../../services/pos_service.dart';
import '../../models/user.dart' as user_model;
import '../owner/owner_dashboard.dart';
import '../cashier/cashier_dashboard.dart';
import '../manager/manager_dashboard.dart';
import '../inventory_clerk/inventory_clerk_dashboard.dart';
import '../delivery_receiver/delivery_receiver_dashboard.dart';
import '../sales_promoter/sales_promoter_dashboard.dart';
import '../shared/loading_screen.dart';

class DemoAccessScreen extends StatefulWidget {
  const DemoAccessScreen({super.key});

  @override
  State<DemoAccessScreen> createState() => _DemoAccessScreenState();
}

class _DemoAccessScreenState extends State<DemoAccessScreen> {
  final demoService = DemoAccessService();
  final userService = GetIt.I.get<UserService>();
  final posService = GetIt.I.get<POSService>();

  bool isInitializing = false;
  bool isSeeding = false;
  bool isClearing = false;
  String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎮 Demo Access'),
        backgroundColor: Colors.indigo[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo[900]!, Colors.indigo[800]!],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Welcome Banner
                _buildWelcomeBanner(),
                const SizedBox(height: 24),

                // Setup Section
                _buildSectionTitle('Setup Demo Environment'),
                const SizedBox(height: 12),
                _buildSetupCard(),
                const SizedBox(height: 24),

                // Demo Accounts Section
                _buildSectionTitle('Quick Login - Demo Accounts'),
                const SizedBox(height: 12),
                ..._buildDemoAccountCards(),
                const SizedBox(height: 24),

                // Cleanup Section
                _buildSectionTitle('Cleanup'),
                const SizedBox(height: 12),
                _buildCleanupCard(),

                if (statusMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      statusMessage!,
                      style: const TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Card(
      color: Colors.indigo[700],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videogame_asset, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Demo Access Portal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick access to test all system features with pre-configured demo accounts and sample data. Perfect for development, testing, and demonstrations.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo password: demo123 • Demo PIN: 1234',
                      style: TextStyle(color: Colors.cyan, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildSetupCard() {
    return Card(
      color: Colors.grey[850],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: isInitializing ? null : _initializeDemoAccounts,
                icon: const Icon(Icons.people),
                label: isInitializing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('1. Initialize Demo Accounts'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create demo accounts for all roles + activate Standard Package (all features enabled)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Divider(color: Colors.white24, height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: isSeeding ? null : _seedDemoData,
                icon: const Icon(Icons.grass),
                label: isSeeding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('2. Seed Demo Data'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Load sample products (clothing, accessories) and sales transactions',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDemoAccountCards() {
    final roles = demoService.getAvailableDemoRoles();
    return roles.map((role) {
      final account = demoService.getDemoAccountByRole(role);
      if (account == null) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildDemoAccountCard(role: role, account: account),
      );
    }).toList();
  }

  Widget _buildDemoAccountCard({
    required String role,
    required Map<String, String> account,
  }) {
    return Card(
      color: Colors.grey[850],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DemoAccessService.formatRoleForDisplay(role),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account['email']!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                onPressed: () => _quickLoginToRole(role, account),
                icon: const Icon(Icons.login),
                label: const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupCard() {
    return Card(
      color: Colors.grey[850],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: isClearing ? null : _showClearConfirmDialog,
                icon: const Icon(Icons.delete_sweep),
                label: isClearing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Clear All Demo Data'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Remove all demo accounts, products, and sales transactions',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeDemoAccounts() async {
    setState(() => isInitializing = true);

    try {
      final success = await demoService.initializeDemoAccounts();
      setState(() {
        statusMessage = success
            ? '✅ Demo mode initialized!\n📦 Standard Package activated\n👥 Demo accounts created'
            : '⚠️ Some demo accounts may already exist';
        isInitializing = false;
      });
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error: $e';
        isInitializing = false;
      });
    }
  }

  void _seedDemoData() async {
    setState(() => isSeeding = true);

    try {
      final productsSeeded = await demoService.seedDemoProducts();

      setState(() {
        if (productsSeeded) {
          statusMessage = '✅ Products seeded successfully!';
        } else {
          statusMessage = '⚠️ Products already exist or seed failed.';
        }
        isSeeding = false;
      });

      // Refresh products in POS service if available
      if (posService.products.isNotEmpty) {
        // Products already loaded
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error: $e';
        isSeeding = false;
      });
    }
  }

  void _quickLoginToRole(String role, Map<String, String> account) async {
    try {
      // Authenticate user
      final user = userService.authenticateUser(
        account['email']!,
        account['password']!,
      );

      if (user != null && mounted) {
        // Navigate to appropriate dashboard with loading screen
        final dashboard = _getDashboardForRole(user);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoadingScreen(destination: dashboard),
          ),
          (route) => false,
        );
      } else if (mounted) {
        _showErrorDialog('Authentication failed', 'Demo account not found');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Login Error', e.toString());
      }
    }
  }

  Widget _getDashboardForRole(user_model.User user) {
    switch (user.role) {
      case user_model.UserRole.owner:
        return OwnerDashboard(user: user);
      case user_model.UserRole.cashier:
        return CashierDashboard(user: user);
      case user_model.UserRole.manager:
        return ManagerDashboard(user: user);
      case user_model.UserRole.inventoryClerk:
        return InventoryClerkDashboard(user: user);
      case user_model.UserRole.deliveryReceiver:
        return DeliveryReceiverDashboard(user: user);
      case user_model.UserRole.salesPromoter:
        return SalesPromoterDashboard(user: user);
      default:
        return OwnerDashboard(user: user);
    }
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear Demo Data'),
        content: const Text(
          'This will delete:\n'
          '• All demo accounts\n'
          '• All sample products\n'
          '• All demo sales\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _clearDemoData();
            },
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _clearDemoData() async {
    setState(() => isClearing = true);

    try {
      final success = await demoService.clearAllDemoData();
      setState(() {
        statusMessage = success
            ? '✅ Demo data cleared successfully!'
            : '❌ Error clearing demo data';
        isClearing = false;
      });
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error: $e';
        isClearing = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
