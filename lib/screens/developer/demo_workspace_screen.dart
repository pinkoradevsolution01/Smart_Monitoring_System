import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../services/demo_session_service.dart';
import '../../services/package_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_design_system.dart';

/// A safe preview workspace. It uses [DemoSessionService] only and never
/// routes a demonstration user into production business modules.
class DemoWorkspaceScreen extends StatelessWidget {
  final String role;

  const DemoWorkspaceScreen({super.key, required this.role});

  String get _roleName {
    switch (role) {
      case 'inventoryClerk':
        return 'Inventory Clerk';
      case 'salesPromoter':
        return 'Sales Promoter';
      case 'deliveryReceiver':
        return 'Delivery Receiver';
      default:
        return '${role[0].toUpperCase()}${role.substring(1)}';
    }
  }

  void _endDemo(BuildContext context, {bool returnToDeveloper = false}) {
    final session = DemoSessionService.instance;
    session.end();
    GetIt.I<PackageService>().exitDemoPackage();
    final sync = GetIt.I<SupabaseSyncService>();
    if (sync.isConfigured) sync.startAutoSync();

    if (returnToDeveloper) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/developer-dashboard', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = DemoSessionService.instance;
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _endDemo(context);
      },
      child: AnimatedBuilder(
        animation: demo,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text('Demo Preview: $_roleName'),
            actions: [
              TextButton.icon(
                onPressed: () => _endDemo(context, returnToDeveloper: true),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Exit Demo'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Safe Client Demonstration Mode\nAll products, sales, and stock changes below are temporary demo data. Nothing is saved or synchronized.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 640 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    childAspectRatio: columns == 1 ? 3.1 : 1.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      AppMetricCard(
                        label: 'Demo sales',
                        value: '${demo.completedSales}',
                        icon: Icons.receipt_long_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        detail: 'In-memory transactions only',
                      ),
                      AppMetricCard(
                        label: 'Demo revenue',
                        value: AppCurrency.peso(demo.demoRevenue),
                        icon: Icons.payments_outlined,
                        color: AppColors.successGreen,
                        detail: 'Never sent to the backend',
                      ),
                      AppMetricCard(
                        label: 'Stock alerts',
                        value: '${demo.products.where((item) => item.stock <= 7).length}',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.warningOrange,
                        detail: 'Sample inventory only',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Sample operations',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: demo.products
                      .map(
                        (product) => ListTile(
                          leading: Icon(
                            product.stock == 0
                                ? Icons.block_outlined
                                : Icons.inventory_2_outlined,
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            product.stock == 0
                                ? 'Out of stock'
                                : product.stock <= 7
                                ? 'Low stock: ${product.stock}'
                                : 'In stock: ${product.stock}',
                          ),
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Text(
                                AppCurrency.peso(product.price),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              IconButton(
                                tooltip: 'Simulate restock',
                                onPressed: () => demo.restock(product.id),
                                icon: const Icon(Icons.add_box_outlined),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: demo.simulateSale,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('Simulate demo sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
