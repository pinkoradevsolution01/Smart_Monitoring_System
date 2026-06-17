import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/user.dart' as user_model;
import '../../utils/app_localizations.dart';
import '../../utils/locale_controller.dart';
import '../../services/user_service.dart';
import '../../services/admin_service.dart';
import '../admin/admin_dashboard.dart';
import '../../services/business_info_service.dart';
import '../../widgets/ai_help_button.dart';
import '../../services/password_reset_service.dart';
import '../owner/owner_dashboard.dart';
import '../cashier/cashier_dashboard.dart';
import '../manager/manager_dashboard.dart';
import '../inventory_clerk/inventory_clerk_dashboard.dart';
import '../delivery_receiver/delivery_receiver_dashboard.dart';
import '../sales_promoter/sales_promoter_dashboard.dart';
import '../shared/settings_screen.dart';
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
  bool _obscure = true;

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

  void _showForgotDialog() {
    showDialog(context: context, builder: (_) => const _ForgotPasswordDialog());
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
    final inputStyle = const TextStyle(fontSize: 16, color: Colors.black87);
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white.withAlpha((0.9 * 255).round()),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => showAIHelpDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(28),
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
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      child: Text(AppLocalizations.t('login')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _showForgotDialog,
                      child: Text(AppLocalizations.t('forgot_password')),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/developer-auth',
                        ),
                        child: const Text('Developer Sign In'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '© 2026 Smart Monitoring System',
                        style: TextStyle(color: Colors.grey[600]),
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

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('valid_email_required'))),
      );
      return;
    }

    // Check if email belongs to an owner
    final isOwner = await PasswordResetService.isOwnerEmail(email);
    if (!isOwner) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('owner_email_required'))),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      // Send password reset email via Edge Function
      final token = await PasswordResetService.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _isSending = false);
      
      if (token != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('password_reset_email_sent')),
            duration: const Duration(seconds: 5),
          ),
        );
        // Show the token verification dialog
        await _showTokenVerificationDialog(token);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reset email. Please check your internet connection and try again.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Password reset send failed: $e\n$st');
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showTokenVerificationDialog(String expectedToken) async {
    final tokenController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            var loading = false;

            Future<void> submit() async {
              final token = tokenController.text.trim();
              final np = newPassController.text;
              final cp = confirmPassController.text;
              
              if (token.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter the reset token from your email'),
                  ),
                );
                return;
              }
              
              if (np.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.t('password_too_short')),
                  ),
                );
                return;
              }
              
              if (np != cp) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.t('passwords_do_not_match')),
                  ),
                );
                return;
              }

              setDialogState(() => loading = true);
              try {
                // Verify token and reset password
                final result = await PasswordResetService.verifyTokenAndResetPassword(
                  token: token,
                  newPassword: np,
                );
                
                final success = result['success'] == true;
                
                if (!mounted) return;
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.t('password_changed_success'),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Navigator.pop(ctx);
                } else {
                  final errorMsg = result['error'] ?? AppLocalizations.t('action_failed');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg.toString()),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              } finally {
                if (mounted) {
                  setDialogState(() => loading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('🔐 Enter Reset Token'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check your email for the password reset token. It should arrive within a few minutes.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Reset Token',
                        hintText: 'Paste token from email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPassController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t('new_password'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t('confirm_password'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '⚠️ Token is valid for 1 hour',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppLocalizations.t('reset_password_button')),
                ),
              ],
            );
          },
        );
      },
    );

    tokenController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.t('reset_owner_password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: AppLocalizations.t('email_gmail'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.t('cancel')),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _send,
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Request Access Tokens'),
        ),
      ],
    );
  }
}
