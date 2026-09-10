enum PackageType { basic, standard, premium, enterprise }

class PricingPackage {
  final PackageType type;
  final String name;
  final String price;
  final String oneTimePrice;
  final String saasPrice;
  final String period;
  final String description;
  final List<String> features;
  final bool recommended;
  final int maxUsers;
  final int maxProducts;
  final bool hasInventory;
  final bool hasCCTV;
  final bool hasReports;
  final bool hasCloudSync;
  final bool hasSupplierManagement;
  final bool hasEWallet;
  final bool hasMultiDevice;
  final bool hasAdvancedAnalytics;
  final bool hasPrioritySupport;
  final bool hasAIHelp;
  final bool hasExpenseTracking;
  final bool hasBirReports;
  final String? oldPrice;

  const PricingPackage({
    required this.type,
    required this.name,
    required this.price,
    this.oneTimePrice = '',
    this.saasPrice = '',
    required this.period,
    required this.description,
    required this.features,
    this.recommended = false,
    required this.maxUsers,
    required this.maxProducts,
    required this.hasInventory,
    required this.hasCCTV,
    required this.hasReports,
    required this.hasCloudSync,
    required this.hasSupplierManagement,
    required this.hasEWallet,
    required this.hasMultiDevice,
    required this.hasAdvancedAnalytics,
    required this.hasPrioritySupport,
    required this.hasAIHelp,
    required this.hasExpenseTracking,
    required this.hasBirReports,
    this.oldPrice,
  });

  static const List<PricingPackage> packages = [
    PricingPackage(
      type: PackageType.basic,
      name: 'Basic',
      price: '₱299',
      oneTimePrice: '₱19,999',
      saasPrice: '₱299',
      oldPrice: '₱2,999',
      period: '/month',
      description:
          'Perfect for small businesses getting started (For Delivery supported)',
      features: [
        'Smart POS Terminal (Mobile, Web, Windows)',
        '2 User Accounts',
        'Up to 100 Products',
        'Basic Inventory Management',
        'Sales Reports',
        'Local Storage Only',
        'Backup & Restore (Local)',
        'Export/Import Backups',
        'E-Wallet Integration',
        'Email Support',
        'AI Help Assistance',
        'For Delivery Management',
      ],
      maxUsers: 2,
      maxProducts: 100,
      hasInventory: true,
      hasCCTV: false,
      hasReports: true,
      hasCloudSync: false,
      hasSupplierManagement: false,
      hasEWallet: true,
      hasMultiDevice: false,
      hasAdvancedAnalytics: false,
      hasPrioritySupport: false,
      hasAIHelp: true,
      hasExpenseTracking: false,
      hasBirReports: false,
    ),
    PricingPackage(
      type: PackageType.standard,
      name: 'Standard',
      price: '₱499',
      oneTimePrice: '₱34,999',
      saasPrice: '₱499',
      oldPrice: '₱5,999',
      period: '/month',
      features: [
        'Smart POS Terminal (Mobile, Web, Windows)',
        '5 User Accounts',
        'Up to 500 Products',
        'Advanced Inventory',
        'Sales & Financial Reports',
        'Expense Tracking & Profit Analysis',
        'BIR-ready Z-Reading, eSales & VAT Summaries',
        'Attendance Management',
        'Cloud Sync',
        'Supplier Management',
        'E-Wallet Integration',
        'Priority Email Support',
        'AI Help Assistance',
        'For Delivery Management',
      ],
      description: 'Best for growing retail stores (For Delivery supported)',
      recommended: true,
      maxUsers: 5,
      maxProducts: 500,
      hasInventory: true,
      hasCCTV: false,
      hasReports: true,
      hasCloudSync: true,
      hasSupplierManagement: true,
      hasEWallet: true,
      hasMultiDevice: true,
      hasAdvancedAnalytics: false,
      hasPrioritySupport: false,
      hasAIHelp: true,
      hasExpenseTracking: true,
      hasBirReports: true,
    ),
    PricingPackage(
      type: PackageType.premium,
      name: 'Premium',
      price: '₱899',
      oneTimePrice: '₱59,999',
      saasPrice: '₱899',
      oldPrice: '₱9,999',
      period: '/month',
      features: [
        'Smart POS Terminal (Mobile, Web, Windows)',
        '10 User Accounts',
        'Unlimited Products',
        'Full Inventory Suite',
        'CCTV Integration (4 cameras)',
        'Advanced Analytics',
        'Expense Tracking & Profit Analysis',
        'BIR-ready Z-Reading, eSales & VAT Summaries',
        'Attendance Management',
        'Multi-Device Sync',
        'All Integrations',
        '24/7 Phone Support',
        'AI Help Assistance',
        'For Delivery Management',
      ],
      description:
          'Complete solution with CCTV monitoring (For Delivery supported)',
      maxUsers: 10,
      maxProducts: -1, // unlimited
      hasInventory: true,
      hasCCTV: true,
      hasReports: true,
      hasCloudSync: true,
      hasSupplierManagement: true,
      hasEWallet: true,
      hasMultiDevice: true,
      hasAdvancedAnalytics: true,
      hasPrioritySupport: true,
      hasAIHelp: true,
      hasExpenseTracking: true,
      hasBirReports: true,
    ),
    PricingPackage(
      type: PackageType.enterprise,
      name: 'Enterprise',
      price: 'Custom',
      period: '',
      description: 'Tailored for large retail chains',
      features: [
        'Smart POS Terminal (Mobile, Web, Windows)',
        'Unlimited Users',
        'Unlimited Products',
        'Enterprise Inventory',
        'CCTV Integration (Unlimited)',
        'Custom Analytics Dashboard',
        'Expense Tracking & Profit Analysis',
        'BIR-ready Z-Reading, eSales & VAT Summaries',
        'Multi-Branch Support',
        'API Access',
        'Dedicated Account Manager',
        'On-Site Training',
        'Custom Integrations',
      ],
      maxUsers: -1, // unlimited
      maxProducts: -1, // unlimited
      hasInventory: true,
      hasCCTV: true,
      hasReports: true,
      hasCloudSync: true,
      hasSupplierManagement: true,
      hasEWallet: true,
      hasMultiDevice: true,
      hasAdvancedAnalytics: true,
      hasPrioritySupport: true,
      hasAIHelp: true,
      hasExpenseTracking: true,
      hasBirReports: true,
    ),
  ];

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'name': name,
      'price': price,
      'oldPrice': oldPrice,
      'period': period,
      'maxUsers': maxUsers,
      'maxProducts': maxProducts,
      'hasInventory': hasInventory,
      'hasCCTV': hasCCTV,
      'hasReports': hasReports,
      'hasCloudSync': hasCloudSync,
      'hasSupplierManagement': hasSupplierManagement,
      'hasEWallet': hasEWallet,
      'hasMultiDevice': hasMultiDevice,
      'hasAdvancedAnalytics': hasAdvancedAnalytics,
      'hasPrioritySupport': hasPrioritySupport,
      'hasAIHelp': hasAIHelp,
      'hasExpenseTracking': hasExpenseTracking,
      'hasBirReports': hasBirReports,
    };
  }

  factory PricingPackage.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    final type = PackageType.values.firstWhere(
      (e) => e.toString() == typeStr,
      orElse: () => PackageType.basic,
    );

    return packages.firstWhere((pkg) => pkg.type == type);
  }
}
