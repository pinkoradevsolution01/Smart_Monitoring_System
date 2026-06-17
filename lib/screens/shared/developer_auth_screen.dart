import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';

import '../../services/developer_service.dart';
import '../../services/admin_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/backend_config.dart';
import '../../utils/oauth_checker.dart';
import '../../models/admin_account.dart';

class DeveloperAuthScreen extends StatefulWidget {
  const DeveloperAuthScreen({super.key});

  static const String _devAuthKey = 'developer_authenticated';

  static Future<bool> isDeveloperAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_devAuthKey) ?? false;
  }

  static Future<void> clearAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_devAuthKey);
  }

  @override
  State<DeveloperAuthScreen> createState() => _DeveloperAuthScreenState();
}

class _DeveloperAuthScreenState extends State<DeveloperAuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final GoogleAuthService _googleAuth = GoogleAuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _showFounderSetup = false;

  // Default developer credentials
  static const String _defaultUsername = 'developer';
  static const String _defaultPassword = 'dev123';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter both username and password');
      return;
    }

    setState(() => _isLoading = true);

    // Simulate authentication delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Check credentials
    final devService = GetIt.I.get<DeveloperService>();
    final storedPw = devService.password;
    final hasRegisteredDev = storedPw.isNotEmpty;
    final storedOk = devService.authenticate(username, password);
    final fallbackOk = (username.toLowerCase() == _defaultUsername && password == _defaultPassword) ||
      (username.toLowerCase() == 'admin' && password == 'admin123');

    // If a registered developer account exists, require it. Only allow demo defaults when
    // there is no registered developer password stored.
    final allowed = hasRegisteredDev ? storedOk : (storedOk || fallbackOk);

    if (allowed) {
      // Save authentication status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(DeveloperAuthScreen._devAuthKey, true);

      if (mounted) {
        setState(() => _isLoading = false);
            Navigator.pushReplacementNamed(context, '/developer-dashboard');
      }
    } else {
      setState(() => _isLoading = false);
      _showError('Invalid username or password');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Quick founder setup without Google OAuth
  Future<void> _quickFounderSetup() async {
    setState(() => _isLoading = true);

    try {
      // Create founder admin account
      final adminService = GetIt.I<AdminService>();
      final founder = AdminAccount(
        id: 'founder-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Founder',
        email: 'founder@smartmonitor.com',
        password: 'founder2026',
        contactNumber: '',
        createdAt: DateTime.now(),
      );

      await adminService.updateAdminAccount(founder);

      // Save authentication status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(DeveloperAuthScreen._devAuthKey, true);

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccess('Founder account created successfully!');

        // Navigate to developer dashboard
        Navigator.pushReplacementNamed(context, '/developer-dashboard');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Setup failed: ${e.toString()}');
    }
  }

  /// Sign in with Gmail via backend-backed Google OAuth
  /// NOTE: Google OAuth requires additional setup for Windows desktop:
  /// Google Sign In for Developer/Founder Account
  Future<void> _signInWithGoogle() async {
    if (!BackendConfig.useRestBackend) {
      _showError(
        'Backend not configured. Please start the Node.js backend first.',
      );
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      // Ensure any existing session is cleared so the browser
      // shows an account chooser instead of reusing an already-authenticated owner.
      await _googleAuth.signOut();
      await _googleAuth.clearSession();

      // Use GoogleAuthService for sign in
      final googleUser = await _googleAuth.signInWithGoogle();

      if (googleUser == null) {
        final setupStatus = await OAuthChecker.checkSetup();
        final missingClientId =
            setupStatus['google_web_client_id_configured'] != true;
        setState(() => _isGoogleLoading = false);
        _showError(
          missingClientId
              ? 'Google sign-in is not fully configured yet. Build the app with --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com.'
              : 'Google sign-in cancelled or failed',
        );
        return;
      }

      final userEmail = googleUser['email'] as String;
      final userName = googleUser['name'] as String;
      final userId = googleUser['id'] as String;
      final userPicture = googleUser['avatar_url'] as String?;

      debugPrint('OK: Gmail sign-in successful: $userEmail');

      // Prevent using the Owner/Admin account as the Developer account.
      final adminService = GetIt.I.get<AdminService>();
      final isOwnerEmail = adminService.hasAdminAccount && adminService.isAdmin(userEmail);
      if (isOwnerEmail) {
        await _googleAuth.signOut();
        setState(() => _isGoogleLoading = false);
        _showError('This Google account is registered as Owner; please use a different Google account for Developer sign-in.');
        return;
      }

      // Save developer account with Gmail data (do NOT overwrite owner/admin)
      await _saveGmailDeveloperAccount(userId, userName, userEmail, userPicture);

      // Save authentication status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(DeveloperAuthScreen._devAuthKey, true);
      await _googleAuth.storeSession();

      if (mounted) {
        setState(() => _isGoogleLoading = false);
        _showSuccess('Welcome, $userName!');

        // Navigate to developer dashboard
        Navigator.pushReplacementNamed(context, '/developer-dashboard');
      }
    } catch (e) {
      setState(() => _isGoogleLoading = false);
      _showError('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Save Gmail account as developer account (do NOT modify admin/owner)
  Future<void> _saveGmailDeveloperAccount(
    String userId,
    String name,
    String email,
    String? pictureUrl,
  ) async {
    try {
      // Store developer identity separately so owner/admin account isn't overwritten
      final devService = GetIt.I<DeveloperService>();

      // Use email as username and store the oauth userId as a non-empty password
      // (DeveloperService requires a password field for legacy flows).
      await devService.updateDeveloperAccount(username: email, password: userId);
      debugPrint('OK: Developer account saved: $email');
    } catch (e) {
      debugPrint('Error saving developer account: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.grey[800]!, Colors.grey[900]!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Developer Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.code,
                          size: 64,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Developer Authentication',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Secure access required for system setup',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Username Field
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Colors.blue,
                          ),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _authenticate(),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Colors.blue,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _authenticate(),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'AUTHENTICATE',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider with "OR"
                      if (BackendConfig.useRestBackend) ...[
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[600])),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[600])),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Sign in with Google Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isGoogleLoading
                                ? null
                                : _signInWithGoogle,
                            icon: _isGoogleLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black87,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    'https://www.google.com/favicon.ico',
                                    width: 20,
                                    height: 20,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.login, size: 20),
                                  ),
                            label: Text(
                              _isGoogleLoading
                                  ? 'CONNECTING...'
                                  : 'SIGN IN WITH GOOGLE',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Gmail Auth Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified_user,
                                color: Colors.green[300],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🏢 FOUNDER/DEVELOPER: Sign in with your Gmail account for secure access',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[300],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Founder Setup Button
                      TextButton.icon(
                        onPressed: () {
                          setState(
                            () => _showFounderSetup = !_showFounderSetup,
                          );
                        },
                        icon: const Icon(Icons.person_add),
                        label: Text(
                          _showFounderSetup
                              ? 'Hide Founder Setup'
                              : '👑 Register as Founder (No Google Required)',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Founder Setup Form
                      if (_showFounderSetup) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber[300],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Founder Quick Setup',
                                      style: TextStyle(
                                        color: Colors.amber[300],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Click the button below to register as the system founder with secure credentials.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _quickFounderSetup(),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Register as Founder'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
