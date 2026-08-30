import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../models/pricing_package.dart';
import '../../models/user.dart' as user_model;
import '../../services/demo_access_service.dart';
import '../../services/package_service.dart';
import '../cashier/cashier_dashboard.dart';
import '../delivery_receiver/delivery_receiver_dashboard.dart';
import '../inventory_clerk/inventory_clerk_dashboard.dart';
import '../manager/manager_dashboard.dart';
import '../owner/owner_dashboard.dart';
import '../sales_promoter/sales_promoter_dashboard.dart';
import '../shared/loading_screen.dart';

/// Client-facing demonstration access. Demo users and package overrides are
/// created in memory only and are never persisted or synchronized.
class DemoAccessScreen extends StatelessWidget {
  const DemoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DemoAccessService();
    final roles = service.getAvailableDemoRoles();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Demo Access Portal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF111936),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFFF4F6FB),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 1100
                ? 1060.0
                : double.infinity;
            final columns = constraints.maxWidth >= 760 ? 2 : 1;
            return Center(
              child: SizedBox(
                width: width,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  children: [
                    _HeroPanel(),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose a role to explore',
                              style: TextStyle(
                                color: Color(0xFF17213D),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Each preview opens with Premium features enabled.',
                              style: TextStyle(color: Color(0xFF667085)),
                            ),
                          ],
                        ),
                        _RoleCount(count: roles.length),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: roles.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 154,
                      ),
                      itemBuilder: (context, index) {
                        final role = roles[index];
                        return _DemoRoleCard(
                          role: role,
                          account: service.getDemoAccountByRole(role)!,
                          onLogin: () => _startDemo(context, service, role),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _startDemo(
    BuildContext context,
    DemoAccessService service,
    String role,
  ) {
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

class _HeroPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x223730A3),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 24,
        children: const [
          SizedBox(
            width: 590,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF67E8F9), size: 34),
                SizedBox(height: 16),
                Text(
                  'Client Demonstration Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Preview the complete Smart Monitoring System with Premium features. Choose a role below to experience the system from that user perspective.',
                  style: TextStyle(
                    color: Color(0xFFDDE7FF),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _SessionDetails(),
        ],
      ),
    );
  }
}

class _SessionDetails extends StatelessWidget {
  const _SessionDetails();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SESSION DETAILS',
            style: TextStyle(
              color: Color(0xFFBAE6FD),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 10),
          _HeroDetail(icon: Icons.workspace_premium, text: 'Premium features'),
          SizedBox(height: 8),
          _HeroDetail(icon: Icons.lock_outline, text: 'In-memory session'),
          SizedBox(height: 8),
          _HeroDetail(icon: Icons.storage, text: 'No demo data saved'),
        ],
      ),
    );
  }
}

class _HeroDetail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroDetail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFBAE6FD), size: 17),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _RoleCount extends StatelessWidget {
  final int count;

  const _RoleCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count roles available',
        style: const TextStyle(
          color: Color(0xFF3730A3),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DemoRoleCard extends StatefulWidget {
  final String role;
  final Map<String, String> account;
  final VoidCallback onLogin;

  const _DemoRoleCard({
    required this.role,
    required this.account,
    required this.onLogin,
  });

  @override
  State<_DemoRoleCard> createState() => _DemoRoleCardState();
}

class _DemoRoleCardState extends State<_DemoRoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(widget.role);
    return Card(
      elevation: _hovered ? 8 : 2,
      shadowColor: color.withValues(alpha: 0.2),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onLogin,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hovered ? color : const Color(0xFFE4E7EC),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_roleIcon(widget.role), color: color, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DemoAccessService.formatRoleForDisplay(widget.role),
                        style: const TextStyle(
                          color: Color(0xFF17213D),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _roleDescription(widget.role),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.login, size: 15, color: color),
                          const SizedBox(width: 5),
                          Text(
                            'Start preview',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icons.storefront;
      case 'cashier':
        return Icons.point_of_sale;
      case 'manager':
        return Icons.analytics_outlined;
      case 'inventoryClerk':
        return Icons.inventory_2_outlined;
      case 'salesPromoter':
        return Icons.campaign_outlined;
      case 'deliveryReceiver':
        return Icons.local_shipping_outlined;
      default:
        return Icons.person_outline;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return const Color(0xFF7C3AED);
      case 'cashier':
        return const Color(0xFF0891B2);
      case 'manager':
        return const Color(0xFF2563EB);
      case 'inventoryClerk':
        return const Color(0xFF059669);
      case 'salesPromoter':
        return const Color(0xFFDB2777);
      case 'deliveryReceiver':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF475467);
    }
  }

  String _roleDescription(String role) {
    switch (role) {
      case 'owner':
        return 'Business overview, reports, inventory and settings';
      case 'cashier':
        return 'Point of sale, transactions and customer service';
      case 'manager':
        return 'Team operations, analytics and business performance';
      case 'inventoryClerk':
        return 'Stock control, products and inventory movements';
      case 'salesPromoter':
        return 'Sales activity, customers and promotions';
      case 'deliveryReceiver':
        return 'Deliveries, receiving and order coordination';
      default:
        return 'Explore the system experience';
    }
  }
}

class _DemoSessionFrame extends StatelessWidget {
  final Widget child;

  const _DemoSessionFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) GetIt.I<PackageService>().exitDemoPackage();
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
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
                onPressed: () {
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
