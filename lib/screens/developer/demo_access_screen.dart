import 'package:flutter/material.dart';
import '../../models/user.dart' as user_model;
import '../../services/demo_access_service.dart';
import '../cashier/cashier_dashboard.dart';
import '../delivery_receiver/delivery_receiver_dashboard.dart';
import '../inventory_clerk/inventory_clerk_dashboard.dart';
import '../manager/manager_dashboard.dart';
import '../owner/owner_dashboard.dart';
import '../sales_promoter/sales_promoter_dashboard.dart';
import '../shared/loading_screen.dart';

/// Temporary demonstration access. No users, packages, or sample data are
/// created or persisted by this portal.
class DemoAccessScreen extends StatelessWidget {
  const DemoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demoService = DemoAccessService();
    final roles = demoService.getAvailableDemoRoles();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Access Portal'),
        backgroundColor: Colors.indigo[900],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo[900]!, Colors.indigo[800]!],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.indigo[700],
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client Demonstration Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Choose a role to preview the system. Demo accounts exist only in memory for this session. No account, package, product, sales, or other demonstration data is saved.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Demo password: demo123  •  Demo PIN: 1234',
                      style: TextStyle(color: Colors.cyan, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Login - Demo Roles',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...roles.map(
              (role) => _DemoRoleCard(
                role: role,
                account: demoService.getDemoAccountByRole(role)!,
                onLogin: () => _login(context, demoService, role),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _login(BuildContext context, DemoAccessService service, String role) {
    final user = service.createDemoUser(role);
    if (user == null) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoadingScreen(destination: _dashboardFor(user)),
      ),
      (route) => false,
    );
  }

  Widget _dashboardFor(user_model.User user) {
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
}

class _DemoRoleCard extends StatelessWidget {
  final String role;
  final Map<String, String> account;
  final VoidCallback onLogin;

  const _DemoRoleCard({
    required this.role,
    required this.account,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          DemoAccessService.formatRoleForDisplay(role),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          account['email']!,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: ElevatedButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login),
          label: const Text('Preview'),
        ),
      ),
    );
  }
}
