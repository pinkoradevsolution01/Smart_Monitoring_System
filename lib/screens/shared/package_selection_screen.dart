import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:get_it/get_it.dart';
import '../../models/pricing_package.dart';
import '../../models/user.dart';
import '../../services/package_service.dart';
import '../../services/license_service.dart';
import '../../services/user_service.dart';
import '../../services/code_request_service.dart';
import '../../services/supabase_sync_service.dart';
import '../owner/owner_dashboard.dart';
import '../cashier/cashier_dashboard.dart';

class PackageSelectionScreen extends StatefulWidget {
  final PackageService packageService;
  final User? currentUser; // Optional: User who is selecting package

  const PackageSelectionScreen({
    super.key, 
    required this.packageService,
    this.currentUser,
  });

  @override
  State<PackageSelectionScreen> createState() => _PackageSelectionScreenState();
}

class _PackageSelectionScreenState extends State<PackageSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  PricingPackage? _hoveredPackage;
  bool _hasUsedTrial = false; // Track if trial was already used
  int? _subscriptionDiscount;
  int _iconTapCount = 0; // Secret developer mode tap counter
  final Map<PackageType, Map<String, dynamic>> _packageOverrides = {};

  @override
  void initState() {
    super.initState();
    _checkTrialUsage(); // Check if trial was used
    _loadPackageOverrides();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  Future<void> _loadPackageOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pkg in PricingPackage.packages) {
      final key = 'pkg_override_${pkg.type.toString().split('.').last}';
      final raw = prefs.getString(key);
      if (raw != null) {
        try {
          final map = json.decode(raw) as Map<String, dynamic>;
          _packageOverrides[pkg.type] = map;
        } catch (e) {
          debugPrint('Failed to load package override for $key: $e');
        }
      }
    }
    if (mounted) setState(() {});
  }

  PricingPackage _applyOverrides(PricingPackage pkg) {
    final o = _packageOverrides[pkg.type];
    if (o == null) return pkg;

    return PricingPackage(
      type: pkg.type,
      name: (o['name'] as String?)?.isNotEmpty == true
          ? o['name'] as String
          : pkg.name,
      price: (o['price'] as String?)?.isNotEmpty == true
          ? o['price'] as String
          : pkg.price,
      oldPrice: (o['oldPrice'] as String?)?.isNotEmpty == true
          ? o['oldPrice'] as String
          : pkg.oldPrice,
      period: (o['period'] as String?)?.isNotEmpty == true
          ? o['period'] as String
          : pkg.period,
      description: (o['description'] as String?)?.isNotEmpty == true
          ? o['description'] as String
          : pkg.description,
      features: pkg.features,
      recommended: pkg.recommended,
      maxUsers: pkg.maxUsers,
      maxProducts: pkg.maxProducts,
      hasInventory: pkg.hasInventory,
      hasCCTV: pkg.hasCCTV,
      hasReports: pkg.hasReports,
      hasCloudSync: pkg.hasCloudSync,
      hasSupplierManagement: pkg.hasSupplierManagement,
      hasEWallet: pkg.hasEWallet,
      hasMultiDevice: pkg.hasMultiDevice,
      hasAdvancedAnalytics: pkg.hasAdvancedAnalytics,
      hasPrioritySupport: pkg.hasPrioritySupport,
      hasAIHelp: pkg.hasAIHelp,
    );
  }

  Future<void> _checkTrialUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final trialExpires = prefs.getString('trial_expires');
    final subscriptionExpires = prefs.getString('subscription_expires');
    final hasActivated = prefs.getBool('activation_status') ?? false;
    final subscriptionMode = prefs.getString('subscription_mode');

    // Only load discount if user has paid activation (not free trial)
    // Free trial users should NOT see discounted prices
    if (subscriptionMode != 'free_trial' && hasActivated) {
      _subscriptionDiscount = prefs.getInt('subscription_discount');
    }

    // Hide free trial if:
    // 1. User already used free trial (trial_expires exists), OR
    // 2. User has activated subscription (subscription_expires exists), OR
    // 3. User has activation status set
    if (trialExpires != null || subscriptionExpires != null || hasActivated) {
      setState(() => _hasUsedTrial = true);
    } else {
      // still update discount state if present
      if (_subscriptionDiscount != null) setState(() {});
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 60),
                  // Package Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 1200) {
                        // Desktop: multiple columns
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: PricingPackage.packages
                              .map(
                                (pkg) => Flexible(
                                  child: _buildPackageCard(
                                    _applyOverrides(pkg),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      } else if (constraints.maxWidth > 800) {
                        // Tablet: 2 columns
                        return Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          alignment: WrapAlignment.center,
                          children: PricingPackage.packages
                              .map(
                                (pkg) => SizedBox(
                                  width: (constraints.maxWidth - 60) / 2,
                                  child: _buildPackageCard(
                                    _applyOverrides(pkg),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      } else {
                        // Mobile: 1 column
                        return Column(
                          children: PricingPackage.packages
                              .map(
                                (pkg) =>
                                    _buildPackageCard(_applyOverrides(pkg)),
                              )
                              .toList(),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                  _buildFooter(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: _onIconTap,
          child: Icon(Icons.store, size: 64, color: Colors.blue.shade700),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to Smart Monitoring System',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Choose the perfect plan for your business',
          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _onIconTap() {
    setState(() {
      _iconTapCount++;
    });
    if (_iconTapCount >= 7) {
      _iconTapCount = 0; // Reset counter
      // Route to centralized developer auth instead of showing hidden dialog
      Navigator.pushNamed(context, '/developer-auth');
    }
  }



  Widget _buildPackageCard(PricingPackage package) {
    final isHovered = _hoveredPackage == package;
    final isRecommended = package.recommended;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredPackage = package),
      onExit: (_) => setState(() => _hoveredPackage = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        child: Card(
          elevation: isHovered ? 16 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isRecommended
                  ? Colors.blue
                  : (isHovered ? Colors.blue.shade200 : Colors.transparent),
              width: isRecommended ? 3 : 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: isRecommended
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue.shade50, Colors.white],
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Recommended badge
                if (isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(17),
                        topRight: Radius.circular(17),
                      ),
                    ),
                    child: const Text(
                      '⭐ MOST POPULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Package name
                      Text(
                        package.name,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Description
                      Text(
                        package.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Price (show discounted price only after activation)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  // Only show discount if user has activated (stored discount exists)
                                  if (_subscriptionDiscount != null &&
                                      package.type != PackageType.enterprise &&
                                      package.price.contains(RegExp(r'\d'))) {
                                    final priceStr = package.price.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    );
                                    final original =
                                        int.tryParse(priceStr) ?? 0;
                                    final discounted =
                                        (original - _subscriptionDiscount!)
                                            .clamp(0, original);
                                    // Format with thousand separator
                                    final formattedDiscount = discounted
                                        .toString()
                                        .replaceAllMapped(
                                          RegExp(
                                            r'(\d{1,3})(?=(\d{3})+(?!\d))',
                                          ),
                                          (Match m) => '${m[1]},',
                                        );
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '₱$formattedDiscount',
                                          style: TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6.0,
                                          ),
                                          child: Text(
                                            package.price,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // Default: show original package price with oldPrice if available
                                  if (package.oldPrice != null &&
                                      package.type != PackageType.enterprise) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          package.price,
                                          style: TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6.0,
                                          ),
                                          child: Text(
                                            package.oldPrice!,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // Fallback: show only price
                                  return Text(
                                    package.price,
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (package.period.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                left: 8.0,
                              ),
                              child: Text(
                                package.period,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Features
                      ...package.features.map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Select button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _selectPackage(package),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRecommended
                                ? Colors.blue
                                : Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isHovered ? 8 : 2,
                          ),
                          child: Text(
                            package.type == PackageType.enterprise
                                ? 'Contact Sales'
                                : 'Get Started - Monthly',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Monthly rental notice
                      if (package.type != PackageType.enterprise) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Monthly rental - Activation code required',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      // Free trial option - ONLY show if trial never used before
                      if (package.type != PackageType.enterprise &&
                          !_hasUsedTrial) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => _startFreeTrial(package),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blue.shade700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Start Free Trial',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Free 3-minute trial (TEST MODE)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ] else if (package.type != PackageType.enterprise &&
                          _hasUsedTrial) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Free trial not available. Click "Get Started" for monthly rental.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'All plans are monthly rental - Renew with activation code each month',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          'Need help? Contact us at support@smartmonitor.com',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Future<void> _selectPackage(PricingPackage package) async {
    if (package.type == PackageType.enterprise) {
      // Show contact dialog for enterprise
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enterprise Plan'),
          content: const Text(
            'For Enterprise plans, please contact our sales team at:\n\n'
            'Email: jaybe.gubot01@gmail.com\n'
            'Phone: +63 123 456 7890\n\n'
            'Our team will help you create a custom solution for your business.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    // CRITICAL: ALL packages require activation code for monthly rental
    // "Get Started" = Pay monthly with activation code
    await _activateWithCode(package);
  }

  Future<void> _activateWithCode(PricingPackage package) async {
    // Step 1: Show activation code input dialog
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActivationCodeDialog(
        package: package,
        onRequestCode: () => _showRequestCodeDialog(
          package,
          requestType: 'monthly',
        ),
      ),
    );

    // User cancelled
    if (code == null || !mounted) return;

    // Step 2: Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'Validating activation code...',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Step 3: Try to activate
    try {
      final licenseService = GetIt.I<LicenseService>();
      final activationResult = await licenseService.activate(code);

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (activationResult.success) {
        // Save package selection
        await widget.packageService.selectPackage(package);

        // Apply monthly discount: -200 pesos per month
        try {
          final prefs = await SharedPreferences.getInstance();
          // Parse numeric value from package.price like '₱1,999'
          final priceStr = package.price.replaceAll(RegExp(r'[^0-9]'), '');
          if (priceStr.isNotEmpty) {
            final original = int.tryParse(priceStr) ?? 0;
            final discount = 200; // fixed monthly discount
            final discounted = (original - discount) > 0
                ? (original - discount)
                : 0;
            // Format with thousand separators
            final formattedDiscounted = discounted.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
            final formattedOriginal = original.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
            // Save discount and computed price for later use in settings or receipts
            await prefs.setInt('subscription_discount', discount);
            await prefs.setInt('subscription_price', discounted);
            await prefs.setInt('subscription_original_price', original);
            // Human-readable display with thousand separators
            await prefs.setString(
              'subscription_price_display',
              '₱$formattedDiscounted',
            );
            await prefs.setString(
              'subscription_original_price_display',
              '₱$formattedOriginal',
            );
          }
        } catch (e) {
          debugPrint('Failed to save subscription discount: $e');
        }

        // Step 4: Show success confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Text('Activation Successful!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${package.name} has been activated successfully!',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Monthly Rental Subscription',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Valid for: 1 month (TEST MODE: 3 minutes)\nRenewal required monthly',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You now have access to:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...package.features
                          .take(5)
                          .map(
                            (feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Colors.green.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Renewal reminder will be sent before expiry',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  debugPrint('✅ User clicked button - closing dialog with confirmation');
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Continue to Dashboard'),
              ),
            ],
          ),
        );

        if (confirmed == true && mounted) {
          debugPrint('🎯 Activation confirmed - initializing business sync and navigating to dashboard');
          
          // Initialize business in Supabase for cloud sync if owner is registered
          try {
            User? user = widget.currentUser;
            
            // If no currentUser, try to fetch owner from database first
            if (user == null) {
              final userService = GetIt.I<UserService>();
              final owners = userService.getUsersByRole(UserRole.owner);
              if (owners.isNotEmpty) {
                user = owners.first;
              }
            }
            
            // Initialize business for cloud sync
            if (user != null && user.role == UserRole.owner) {
              final supabaseSyncService = GetIt.I<SupabaseSyncService>();
              await supabaseSyncService.initializeBusiness(
                businessName: user.name,
                ownerEmail: user.email,
                existingBusinessId: user.businessId,
              );
              debugPrint('✅ Business initialized in Supabase for cloud sync');
            }
          } catch (e) {
            debugPrint('⚠️ Warning: Could not initialize business in Supabase: $e');
            // App continues - does not block dashboard navigation
          }
          
          // Navigate based on whether user is logged in or exists in database
          User? user = widget.currentUser;
          debugPrint('📋 widget.currentUser: ${user?.email ?? "null"}');
          
          // If no currentUser, try to fetch owner from database
          if (user == null) {
            debugPrint('❌ No currentUser, fetching from database...');
            final userService = GetIt.I<UserService>();
            final owners = userService.getUsersByRole(UserRole.owner);
            debugPrint('🔍 Found ${owners.length} owner(s) in database');
            if (owners.isNotEmpty) {
              user = owners.first;
              debugPrint('✅ Using owner from database: ${user.email}');
            }
          } else {
            debugPrint('✅ Using currentUser from parameter: ${user.email}');
          }
          
          if (user != null) {
            debugPrint('🚀 Navigating to ${user.role} dashboard for ${user.email}');
            // User exists (either from parameter or database), navigate to dashboard
            Widget dashboard;
            
            switch (user.role) {
              case UserRole.owner:
                debugPrint('📍 Creating OwnerDashboard with showManageAccount=true');
                dashboard = OwnerDashboard(
                  user: user,
                  showManageAccount: true,
                );
                break;
              case UserRole.cashier:
                dashboard = CashierDashboard(user: user);
                break;
              default:
                // Fallback to login if role is unexpected
                debugPrint('⚠️ Unexpected role: ${user.role}');
                Navigator.pushReplacementNamed(context, '/login');
                return;
            }
            
            debugPrint('✅ Pushing replacement route to dashboard');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => dashboard),
            );
            debugPrint('✅ Navigation completed');
          } else {
            debugPrint('⚠️ No user found - going to login');
            // No user found in database or parameter, go to login screen
            Navigator.pushReplacementNamed(context, '/login');
          }
        } else {
          debugPrint('⚠️ Confirmation was not true or not mounted. confirmed=$confirmed, mounted=$mounted');
        }
      } else {
        // Show error dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700),
                const SizedBox(width: 12),
                const Text('Activation Failed'),
              ],
            ),
            content: Text(
              activationResult.message,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade700),
              const SizedBox(width: 12),
              const Text('Error'),
            ],
          ),
          content: Text(
            'An error occurred: $e',
            style: const TextStyle(fontSize: 14),
          ),
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

  Future<void> _startFreeTrial(PricingPackage package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start Free Trial - ${package.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start a free 3-minute trial for this plan? (TEST MODE)',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Need longer access?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Request an activation code from the developer for full monthly access.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context, false);
              _showRequestCodeDialog(package, requestType: 'trial_upgrade');
            },
            icon: const Icon(Icons.email),
            label: const Text('Request Code'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Trial'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Activate offline free trial: save to SharedPreferences and select package locally
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final expires = now.add(
        const Duration(minutes: 3),
      ); // TEST MODE: 3 minutes

      // CRITICAL: Clear any previous activation status - free trial should NOT be activated
      await prefs.remove('activation_status');
      await prefs.remove('activation_code');
      await prefs.remove('activation_date');
      await prefs.remove(
        'subscription_expires',
      ); // Clear subscription expiry for fresh trial

      // CRITICAL: Remove any discount data - free trial does NOT get monthly discount
      await prefs.remove('subscription_discount');
      await prefs.remove('subscription_price');
      await prefs.remove('subscription_original_price');
      await prefs.remove('subscription_price_display');
      await prefs.remove('subscription_original_price_display');

      // Set free trial data
      await prefs.setString('subscription_mode', 'free_trial');
      await prefs.setString('subscription_package', package.name);
      await prefs.setString('trial_starts', now.toIso8601String());
      await prefs.setString('trial_expires', expires.toIso8601String());

      // Select package locally so user gets access immediately
      await widget.packageService.selectPackage(package);

      // Show confirmation with auto-navigation after user acknowledges
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Trial Activated'),
            content: Text(
              'Your free 3-minute trial (TEST MODE) for the ${package.name} plan is active until ${expires.toLocal().toString().split(".")[0].split(" ").last}\n\n'
              'Click Continue to start using the system.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }

      // Navigate to login screen so trial lock can activate
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  /// Show dialog to request activation code from developer
  Future<void> _showRequestCodeDialog(
    PricingPackage package, {
    required String requestType,
  }) async {
    final requestData = await showDialog<_RequestCodeFormData>(
      context: context,
      builder: (_) => _RequestCodeDialog(
        package: package,
      ),
    );

    if (requestData != null && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text('Sending request to developer...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Submit request
      final codeRequestService = CodeRequestService();
      final success = await codeRequestService.requestActivationCode(
        packageName: package.name,
        packagePrice: package.price,
        requestType: requestType,
        businessName: requestData.businessName,
        contactEmail: requestData.contactEmail,
        contactPhone: requestData.contactPhone,
        additionalNotes: requestData.additionalNotes,
      );

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show result
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Text(success ? 'Request Sent!' : 'Request Failed'),
            ],
          ),
          content: Text(
            success
                ? 'Your activation code request has been sent to the developer.\n\n'
                      'You will receive the activation code via email at:\n${requestData.contactEmail}\n\n'
                      'Please check your email within 24 hours.'
                : 'Failed to send request. Please check your internet connection and try again, or contact support directly.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: success ? Colors.green : Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

class _ActivationCodeDialog extends StatefulWidget {
  final PricingPackage package;
  final Future<void> Function() onRequestCode;

  const _ActivationCodeDialog({
    required this.package,
    required this.onRequestCode,
  });

  @override
  State<_ActivationCodeDialog> createState() => _ActivationCodeDialogState();
}

class _ActivationCodeDialogState extends State<_ActivationCodeDialog> {
  late final TextEditingController _activationCodeController;

  @override
  void initState() {
    super.initState();
    _activationCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.vpn_key, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text('Activate ${widget.package.name}')),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Payment Settlement Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monthly Rental System:\n'
                      '1. Complete payment for this month\n'
                      '2. Developer will send activation code\n'
                      '3. Enter code below (valid 1 month)\n'
                      '4. Renew monthly with new code',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _activationCodeController,
                decoration: InputDecoration(
                  labelText: 'Monthly Activation Code',
                  hintText: 'Enter code from developer',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: const OutlineInputBorder(),
                  helperText: 'Contact jaybe.gubot01@gmail.com for code',
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                ],
                autofocus: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.of(context).pop(null);
            await widget.onRequestCode();
          },
          icon: const Icon(Icons.email),
          label: const Text('Request Code'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
        ),
        ElevatedButton(
          onPressed: () {
            final inputCode = _activationCodeController.text.trim();
            if (inputCode.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter activation code'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.of(context).pop(inputCode);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Activate'),
        ),
      ],
    );
  }
}

class _RequestCodeFormData {
  final String businessName;
  final String contactEmail;
  final String contactPhone;
  final String additionalNotes;

  const _RequestCodeFormData({
    required this.businessName,
    required this.contactEmail,
    required this.contactPhone,
    required this.additionalNotes,
  });
}

class _RequestCodeDialog extends StatefulWidget {
  final PricingPackage package;

  const _RequestCodeDialog({required this.package});

  @override
  State<_RequestCodeDialog> createState() => _RequestCodeDialogState();
}

class _RequestCodeDialogState extends State<_RequestCodeDialog> {
  late final TextEditingController _businessNameController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _contactEmailController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_businessNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your business name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_contactEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your contact email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_contactPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your contact phone'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _RequestCodeFormData(
        businessName: _businessNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        additionalNotes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.mail_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          const Expanded(child: Text('Request Activation Code')),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Request Process',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1. Fill in your business details below\n'
                      '2. Developer will review your request\n'
                      '3. Receive activation code via email\n'
                      '4. Enter code to activate your plan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Package: ${widget.package.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Price: ${widget.package.price}/month',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name *',
                  hintText: 'Enter your business name',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contactEmailController,
                decoration: const InputDecoration(
                  labelText: 'Contact Email *',
                  hintText: 'your@email.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone *',
                  hintText: '+63 XXX XXX XXXX',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Any special requirements or questions',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send),
          label: const Text('Submit Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
