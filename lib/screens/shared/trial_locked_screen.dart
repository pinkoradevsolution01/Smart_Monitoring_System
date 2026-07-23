import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/package_service.dart';
import '../../services/license_service.dart';
import 'activation_code_request_dialog.dart';

class TrialLockedScreen extends StatefulWidget {
  const TrialLockedScreen({super.key});

  @override
  State<TrialLockedScreen> createState() => _TrialLockedScreenState();
}

class _TrialLockedScreenState extends State<TrialLockedScreen> {
  final _activationCodeController = TextEditingController();
  String? _packageName;
  DateTime? _expiredAt;
  DateTime? _subscriptionExpiredAt;
  bool _isActivating = false;
  bool _hasRequestedFreshCode = false;
  final _showActivationForm = true; // Show by default - payment required!
  bool _isSubscriptionExpiry =
      false; // Track if lock is due to subscription expiry

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseService = GetIt.I<LicenseService>();

    final pkg = prefs.getString('subscription_package');
    final trialExp = prefs.getString('trial_expires');
    final subExp = prefs.getString('subscription_expires');

    // Check which type of expiry we're dealing with
    final isSubExpired = licenseService.isSubscriptionExpired();

    if (!mounted) return;
    setState(() {
      _packageName = pkg ?? 'Selected Package';
      _expiredAt = trialExp != null ? DateTime.tryParse(trialExp) : null;
      _subscriptionExpiredAt = subExp != null
          ? DateTime.tryParse(subExp)
          : null;
      _isSubscriptionExpiry =
          isSubExpired; // True if subscription expired (monthly rental)
    });
  }

  Future<void> _activateWithCode() async {
    if (!_hasRequestedFreshCode) {
      _showMessage(
        'Request a new activation code before activating.',
        isError: true,
      );
      return;
    }
    final code = _activationCodeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showMessage('Please enter an activation code', isError: true);
      return;
    }

    setState(() => _isActivating = true);

    try {
      final licenseService = GetIt.I<LicenseService>();
      final result = await licenseService.activate(code);

      if (!mounted) return;

      if (result.success) {
        _showMessage('Activation successful! Redirecting...', isError: false);

        // Wait a moment then navigate to login
        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _showMessage(result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Activation error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _goToPurchase() async {
    // Navigate to package selection so user can choose a paid package
    Navigator.of(context).pushReplacementNamed('/package-selection');
  }

  Future<void> _contactSupport() async {
    // Show contact information dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Sales Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To purchase an activation code or extend your trial:'),
            SizedBox(height: 16),
            Text(
              '📧 Email: jaybe.gubot01@gmail.com',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '📞 Phone: +1-XXX-XXX-XXXX',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '🌐 Web: www.smartstore.com/purchase',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestActivationCode() async {
    final packageService = GetIt.I<PackageService>();
    final package = packageService.selectedPackage;
    final requestSent = await showActivationCodeRequestDialog(
      context: context,
      packageName: package?.name ?? _packageName ?? 'Selected Package',
      packagePrice: package?.price ?? '',
      requestType: 'monthly',
    );
    if (requestSent && mounted) {
      setState(() => _hasRequestedFreshCode = true);
      _showMessage(
        'Request submitted. Enter the new activation code when you receive it.',
        isError: false,
      );
    }
  }

  // Developer access now uses the centralized Developer Auth route.
  void _onLockIconTap() {
    // Navigate users to explicit auth screen instead of revealing hidden bypass.
    Navigator.pushNamed(context, '/developer-auth');
  }

  @override
  Widget build(BuildContext context) {
    final packageService = GetIt.I<PackageService>();
    final selectedName =
        _packageName ?? packageService.selectedPackage?.name ?? 'Your Package';

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Locked - Payment Required'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Payment Required Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _onLockIconTap,
                        child: Icon(
                          Icons.lock_clock,
                          size: 64,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '🚫 SYSTEM LOCKED 🚫',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSubscriptionExpiry
                            ? 'Monthly Subscription Expired'
                            : 'Free Trial Expired',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'PAYMENT SETTLEMENT REQUIRED',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isSubscriptionExpiry
                            ? 'Your monthly subscription has expired. All system features are disabled until you renew with a new activation code.'
                            : 'All system features are disabled until you settle payment and activate your subscription.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isSubscriptionExpiry
                      ? 'To renew your monthly subscription and restore access, enter a new activation code obtained after payment.'
                      : 'To unlock the system and restore access, you must enter a valid activation code obtained after payment.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (_expiredAt != null && !_isSubscriptionExpiry) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Trial Expired: ${_expiredAt!.toLocal().toString().split(".")[0].split(" ").last}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                if (_subscriptionExpiredAt != null &&
                    _isSubscriptionExpiry) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Subscription Expired: ${_subscriptionExpiredAt!.toLocal().toString().split(".")[0].split(" ").last}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 32),

                // Activation Form
                if (_showActivationForm) ...[
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.vpn_key, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'Enter Activation Code',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Activation code is provided after payment settlement',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _requestActivationCode,
                              icon: const Icon(Icons.email_outlined),
                              label: const Text('Request New Activation Code'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _activationCodeController,
                            decoration: InputDecoration(
                              labelText: 'Activation Code',
                              hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX',
                              prefixIcon: const Icon(Icons.vpn_key),
                              border: const OutlineInputBorder(),
                              helperText:
                                  'Enter the 20+ character code from your purchase',
                            ),
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Z0-9-]'),
                              ),
                            ],
                            onSubmitted: (_) => _activateWithCode(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isActivating || !_hasRequestedFreshCode
                                  ? null
                                  : _activateWithCode,
                              icon: _isActivating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.check_circle),
                              label: Text(
                                _isActivating
                                    ? 'Activating...'
                                    : _hasRequestedFreshCode
                                    ? 'Activate Now'
                                    : 'Request a code first',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: _contactSupport,
                                icon: const Icon(Icons.support_agent),
                                label: const Text('Contact Support'),
                              ),
                              TextButton.icon(
                                onPressed: _goToPurchase,
                                icon: const Icon(Icons.shopping_cart),
                                label: const Text('Go to Packages'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Information Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'How to Settle Payment and Unlock',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Contact sales support or purchase a subscription package\n'
                        '2. Complete payment settlement for your chosen plan\n'
                        '3. Receive your activation code via email\n'
                        '4. Enter the code above to restore full system access\n'
                        '5. All your data will remain safe and accessible',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Contact Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contact_support,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sales Support',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '📧 jaybe.gubot01@gmail.com',
                        style: TextStyle(fontSize: 13),
                      ),
                      const Text(
                        '📞 +1-XXX-XXX-XXXX',
                        style: TextStyle(fontSize: 13),
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
}
