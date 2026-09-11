import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/user.dart' as user_model;
import '../../utils/app_localizations.dart';
import '../../utils/locale_controller.dart';
import '../../services/user_service.dart';
import '../../services/admin_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/backend_config.dart';
import '../../services/google_auth_service.dart';
import '../../services/supabase_sync_service.dart';
import '../admin/admin_dashboard.dart';
import '../../services/business_info_service.dart';
import '../../services/package_service.dart';
import '../../services/demo_session_service.dart';
import '../../utils/responsive_utils.dart';
import '../owner/owner_dashboard.dart';
import '../cashier/cashier_dashboard.dart';
import '../manager/manager_dashboard.dart';
import '../inventory_clerk/inventory_clerk_dashboard.dart';
import '../delivery_receiver/delivery_receiver_dashboard.dart';
import '../sales_promoter/sales_promoter_dashboard.dart';
import '../shared/loading_screen.dart';
import 'package:smart_monitoring_system/widgets/header_clock.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final ApiClient _api = ApiClient();
  bool _obscure = true;
  bool _isGoogleOwnerSigningIn = false;
  int _devTapCount = 0;

  final UserService _userService = GetIt.I.get<UserService>();
  final BusinessInfoService _businessInfo = GetIt.I.get<BusinessInfoService>();
  // Developer access is now centralized in /developer-auth.

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.t('invalid'))));
      return;
    }

    // First check AdminService — admin accounts are stored separately
    try {
      final adminSvc = GetIt.I.get<AdminService>();
      if (adminSvc.authenticate(email, password)) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoadingScreen(
              destination: const AdminDashboard(),
              iconData: Icons.admin_panel_settings,
            ),
          ),
        );
        return;
      }
    } catch (_) {}

    final ok = _userService.authenticate(email, password);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.t('invalid'))));
      return;
    }

    final user = _userService.getUserByEmail(email);
    if (user == null) return;

    if (!mounted) return;

    Widget target = CashierDashboard(user: user);
    switch (user.role) {
      case user_model.UserRole.owner:
        target = OwnerDashboard(user: user);
        break;
      case user_model.UserRole.manager:
        target = ManagerDashboard(user: user);
        break;
      case user_model.UserRole.inventoryClerk:
        target = InventoryClerkDashboard(user: user);
        break;
      case user_model.UserRole.deliveryReceiver:
        target = DeliveryReceiverDashboard(user: user);
        break;
      case user_model.UserRole.salesPromoter:
        target = SalesPromoterDashboard(user: user);
        break;
      case user_model.UserRole.cashier:
      default:
        target = CashierDashboard(user: user);
        break;
    }

    if (user.role == user_model.UserRole.owner) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoadingScreen(destination: target, role: user.role),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => target));
    }
  }

  Future<void> _signInWithGoogleAsOwner() async {
    final packageService = GetIt.I<PackageService>();
    if (packageService.isDemoPackageActive ||
        DemoSessionService.instance.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in is unavailable during Client Demonstration Mode.'),
        ),
      );
      return;
    }
    if (_isGoogleOwnerSigningIn) return;
    setState(() => _isGoogleOwnerSigningIn = true);

    try {
      final googleAuth = GoogleAuthService();
      final googleUser = await googleAuth.signInWithGoogle(
        profile: GoogleAuthProfile.owner,
      );
      if (googleUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in was cancelled or could not finish.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final email = googleUser['email']?.toString().trim().toLowerCase() ?? '';
      final owner = _userService.getUserByEmail(email);
      if (owner == null || owner.role != user_model.UserRole.owner) {
        await googleAuth.clearSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Use the Google account registered as this business owner.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!owner.isActive) {
        await googleAuth.clearSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This owner account is inactive.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await GetIt.I<SupabaseSyncService>().initializeBusiness(
        businessName: owner.name,
        ownerEmail: owner.email,
        existingBusinessId: owner.businessId,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              LoadingScreen(destination: OwnerDashboard(user: owner)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Owner Google sign-in could not initialize sync: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleOwnerSigningIn = false);
    }
  }

  Future<String?> _promptOwnerEmail() async {
    final controller = TextEditingController(text: _email.text.trim());
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Recover Owner PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Registered owner email',
            hintText: 'owner@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final email = controller.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid owner email'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, email);
            },
            child: Text(AppLocalizations.t('continue')),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptResetToken(String email) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Reset Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A secure reset token was sent to $email'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              maxLength: 64,
              decoration: const InputDecoration(
                labelText: 'Reset token',
                hintText: 'Paste the token from your email',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final token = controller.text.trim();
              if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter the complete 64-character reset token',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, token);
            },
            child: Text(AppLocalizations.t('verify')),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptNewPin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Set New PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New 4-digit PIN',
                hintText: '1234',
              ),
            ),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                hintText: '1234',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (!RegExp(r'^\d{4}$').hasMatch(pin) || pin != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PINs must match and be 4 digits'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, pin);
            },
            child: Text(AppLocalizations.t('save_changes')),
          ),
        ],
      ),
    );
  }

  Future<void> _recoverOwnerPin() async {
    final email = await _promptOwnerEmail();
    if (email == null || email.isEmpty) return;

    final owner = _userService.getUserByEmail(email);
    if (owner == null || owner.role != user_model.UserRole.owner) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No owner account found for that email')),
      );
      return;
    }

    if (!BackendConfig.useRestBackend) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A backend connection is required to reset the Owner PIN.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    dynamic request;
    try {
      request = await _api.postJson(
        'auth/owner-pin-reset/request',
        body: {'email': email},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset token: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (request is! Map<String, dynamic> || request['success'] != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request is Map<String, dynamic>
                ? (request['message']?.toString() ??
                      'Failed to send reset token.')
                : 'Failed to send reset token.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Reset token sent to $email')));

    final token = await _promptResetToken(email);
    if (token == null || token.isEmpty) return;

    final newPin = await _promptNewPin();
    if (newPin == null || newPin.isEmpty) return;

    dynamic verification;
    try {
      verification = await _api.postJson(
        'auth/owner-pin-reset/verify',
        body: {'email': email, 'token': token, 'newPin': newPin},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PIN reset failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (verification is! Map<String, dynamic> ||
        verification['success'] != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verification is Map<String, dynamic>
                ? (verification['message']?.toString() ??
                      'Reset token verification failed')
                : 'Reset token verification failed',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updatedOwner = owner.copyWith(pin: newPin);
    final success = await _userService.updateUser(updatedOwner);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Owner PIN has been reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN reset failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _storeIcon(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primary.withAlpha((0.1 * 255).round()),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.store,
        size: 64,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final packageService = GetIt.I<PackageService>();
    final isClientDemoMode =
        packageService.isDemoPackageActive || DemoSessionService.instance.isActive;
    final inputStyle = const TextStyle(fontSize: 16, color: Colors.black87);
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white.withAlpha((0.9 * 255).round()),
      contentPadding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.isMobile(context) ? 12 : 14,
        horizontal: 12,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: LocaleController.locale,
          builder: (context, value, child) =>
              Text(AppLocalizations.t('welcome')),
        ),
        actions: [
          if (packageService.isDemoPackageActive)
            IconButton(
              tooltip: 'Exit Demo',
              icon: const Icon(Icons.exit_to_app),
              onPressed: () {
                DemoSessionService.instance.end();
                packageService.exitDemoPackage();
                final sync = GetIt.I<SupabaseSyncService>();
                if (sync.isConfigured) sync.startAutoSync();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/developer-dashboard',
                  (route) => false,
                );
              },
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            ResponsiveUtils.responsivePadding(width).left,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width < 600 ? double.infinity : 480,
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              child: Padding(
                padding: EdgeInsets.all(
                  ResponsiveUtils.isMobile(context) ? 20 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _storeIcon(context)),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _businessInfo.businessInfo?.storeName ??
                            AppLocalizations.t('store_name'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Live clock (shared widget)
                    const Center(child: HeaderClock()),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      style: inputStyle,
                      keyboardType: TextInputType.emailAddress,
                      decoration: fieldDecoration.copyWith(
                        labelText: AppLocalizations.t('email'),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style: inputStyle,
                      decoration: fieldDecoration.copyWith(
                        labelText: AppLocalizations.t('password'),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _login,
                      child: Text(AppLocalizations.t('login')),
                    ),
                    if (!isClientDemoMode) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isGoogleOwnerSigningIn
                            ? null
                            : _signInWithGoogleAsOwner,
                        icon: _isGoogleOwnerSigningIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.account_circle_outlined),
                        label: Text(
                          _isGoogleOwnerSigningIn
                              ? 'Signing in with Google...'
                              : 'Continue with Google (Owner)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Owner PIN helpers
                    Center(
                      child: TextButton(
                        onPressed: _recoverOwnerPin,
                        child: Text('Forgot Pin Code? Owner only'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Show PIN entry dialog
                          final pinController = TextEditingController();
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Owner Portal - Enter PIN'),
                              content: TextField(
                                controller: pinController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                  hintText: '4-digit PIN',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(AppLocalizations.t('cancel')),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx, true);
                                  },
                                  child: Text(AppLocalizations.t('continue')),
                                ),
                              ],
                            ),
                          );

                          if (result != true) return;
                          final entered = pinController.text.trim();
                          if (entered.length != 4) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please enter a 4-digit PIN'),
                              ),
                            );
                            return;
                          }

                          // Find owner users and verify PIN
                          final owners = _userService.getUsersByRole(
                            user_model.UserRole.owner,
                          );
                          if (owners.isEmpty) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('No owner account configured'),
                              ),
                            );
                            return;
                          }

                          user_model.User? matched;
                          for (final o in owners) {
                            var valid = _userService.verifyPin(o.id, entered);
                            if (BackendConfig.useRestBackend) {
                              try {
                                final response = await _api.postJson(
                                  'auth/owner-pin/verify',
                                  body: {'email': o.email, 'pin': entered},
                                );
                                valid =
                                    response is Map<String, dynamic> &&
                                    response['success'] == true;
                              } catch (_) {
                                valid = false;
                              }
                            }
                            if (valid) {
                              matched = o;
                              break;
                            }
                          }

                          if (matched == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invalid PIN')),
                            );
                            return;
                          }

                          if (!mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => LoadingScreen(
                                destination: OwnerDashboard(user: matched!),
                                iconData: Icons.lock,
                              ),
                            ),
                          );
                        },
                        child: const Text('Owner Portal'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _devTapCount++);
                          if (_devTapCount >= 5) {
                            // Silent developer access trigger (no UI feedback to clients)
                            Navigator.pushNamed(context, '/developer-auth');
                            _devTapCount = 0;
                          }
                        },
                        child: Text(
                          '© 2026 Smart Monitoring System',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Clock functionality moved to shared HeaderClock widget.
}
