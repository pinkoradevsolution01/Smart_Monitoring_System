import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../models/user.dart' as user_model;
import '../../models/pricing_package.dart';
import '../../services/demo_access_service.dart';
import '../../services/package_service.dart';
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
                      'Choose a role to preview the complete Premium feature set. The Premium package is enabled only in memory for this session. No account, package, product, sales, or other demonstration data is saved.',
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
    final packageService = GetIt.I<PackageService>();
    final premium = PricingPackage.packages.firstWhere(
      (package) => package.type == PackageType.premium,
    );
    packageService.enterDemoPackage(premium);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoadingScreen(
          destination: _DemoSessionFrame(child: _dashboardFor(user)),
        ),
      ),
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

/// Keeps a visible exit control over the demo session without changing the
/// system dashboards or persisting any demo state.
class _DemoSessionFrame extends StatelessWidget {
  final Widget child;

  const _DemoSessionFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          GetIt.I<PackageService>().exitDemoPackage();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton.extended(
                heroTag: 'exit-demo-session',
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                onPressed: () {
                  // DemoAccessScreen remains below the session, so this pops
                  // directly back to Developer Dashboard.
                  GetIt.I<PackageService>().exitDemoPackage();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Exit Demo'),
              ),
            ),
          ),
        ],
      ),
    );
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DemoAccessService.formatRoleForDisplay(role),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account['email']!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 112,
              child: ElevatedButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Preview'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
