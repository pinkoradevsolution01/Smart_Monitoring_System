import 'package:flutter/material.dart';
import '../models/pricing_package.dart';

class PackageUpgradeDialog {
  static void show(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('Feature Locked')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$featureName is not available in your current package.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to a higher tier package to unlock this feature:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPackageOption(
              context,
              PricingPackage.packages[1],
            ), // Standard
            const SizedBox(height: 8),
            _buildPackageOption(context, PricingPackage.packages[2]), // Premium
            const SizedBox(height: 8),
            _buildPackageOption(
              context,
              PricingPackage.packages[3],
            ), // Enterprise
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contact support to upgrade your package'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  static Widget _buildPackageOption(
    BuildContext context,
    PricingPackage package,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  package.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            package.price,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
