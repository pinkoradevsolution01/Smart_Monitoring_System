import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart' as user_model;
import '../../services/developer_service.dart';
import '../../services/user_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/oauth_checker.dart';
import '../../utils/policy_dialogs.dart';
import 'package_selection_screen.dart';
import '../../services/package_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_sync_service.dart';
import '../owner/owner_dashboard.dart';

class OwnerRegistrationScreen extends StatefulWidget {
  const OwnerRegistrationScreen({super.key});

  @override
  State<OwnerRegistrationScreen> createState() =>
      _OwnerRegistrationScreenState();
}

class _OwnerRegistrationScreenState extends State<OwnerRegistrationScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _agreedToTerms = false;
  final GoogleAuthService _googleAuth = GoogleAuthService();
  late UserService _userService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _iconTapCount = 0; // Secret developer mode tap counter

  @override
  void initState() {
    super.initState();
    _userService = GetIt.I<UserService>();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to User Agreement and Privacy Policy to proceed',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Keep the existing owner list so a registered owner can sign in again
      // from this screen instead of being sent through registration.
      final existingOwners = _userService.getUsersByRoleIncludingInactive(
        user_model.UserRole.owner,
      );

      // Sign in with Google
      // Clear any cached Google account so the chooser appears instead of
      // silently reusing the last developer session on this device.
      await _googleAuth.signOut();
      await _googleAuth.clearSession();

      final googleUser = await _googleAuth.signInWithGoogle(
        profile: GoogleAuthProfile.owner,
      );

      if (googleUser == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Google sign-in was cancelled or the browser flow could not complete.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final devService = GetIt.I<DeveloperService>();
      await devService.refreshDeveloperAccount();
      final developerEmail = devService.account?.email ?? devService.username;
      if (developerEmail.isNotEmpty &&
          (googleUser['email'] as String).toLowerCase() ==
              developerEmail.toLowerCase()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This Google account is already reserved for the Developer dashboard. Use a different account for Owner setup.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final googleEmail = (googleUser['email'] as String).trim().toLowerCase();
      user_model.User? matchingOwner;
      for (final owner in existingOwners) {
        if (owner.email.trim().toLowerCase() == googleEmail) {
          matchingOwner = owner;
          break;
        }
      }

      if (matchingOwner != null) {
        if (!matchingOwner.isActive) {
          await _googleAuth.clearSession();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This owner account is inactive.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await _openRegisteredOwnerDashboard(matchingOwner);
        return;
      }

      if (existingOwners.isNotEmpty) {
        await _googleAuth.clearSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A different owner account is already registered on this device.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final api = ApiClient();

      // Persist the owner in MySQL first so the backend becomes the source of truth.
      final ownerResponse = await api.postJson(
        'auth/google/register-owner',
        body: {
          'id': googleUser['id'],
          'email': googleUser['email'],
          'fullName': googleUser['name'],
          'avatarUrl': googleUser['avatar_url'],
        },
      );

      if (ownerResponse is! Map<String, dynamic> ||
          ownerResponse['success'] != true ||
          ownerResponse['user'] is! Map) {
        throw Exception('Failed to register owner in backend');
      }

      final backendOwner = Map<String, dynamic>.from(
        ownerResponse['user'] as Map,
      );
      final backendOwnerId = backendOwner['id']?.toString() ?? '';
      final ownerAlreadyRegistered = ownerResponse['created'] == false;

      final businessResponse = await api.postJson(
        'business/init',
        body: {
          'businessName': googleUser['name'],
          'ownerEmail': googleUser['email'],
          'ownerId': backendOwnerId,
        },
      );

      if (businessResponse is! Map<String, dynamic> ||
          businessResponse['success'] != true ||
          businessResponse['businessId'] == null) {
        throw Exception('Failed to initialize business in backend');
      }

      final businessId = businessResponse['businessId'].toString();

      // Create owner user from Google account
      final owner = user_model.User(
        id: backendOwnerId.isNotEmpty
            ? backendOwnerId
            : googleUser['id'] as String,
        name:
            backendOwner['fullName'] as String? ?? googleUser['name'] as String,
        email: googleUser['email'] as String,
        password: '', // No password for OAuth users
        pin: null,
        role: user_model.UserRole.owner,
        businessId: businessId, // Link to business for multi-device data
        createdAt: DateTime.now(),
        isActive: true,
        authMethod: 'google', // Mark as Google OAuth authenticated
      );

      final success = await _userService.addUser(owner);

      // Store businessId and auth info in local storage
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('business_id', businessId);
        await prefs.setString('business_name', googleUser['name'] as String);
        await prefs.setBool('is_google_auth', true);
        await _googleAuth.storeSession();
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (ownerAlreadyRegistered) {
          await _openRegisteredOwnerDashboard(owner);
          return;
        }

        // New owners select a package after their account is created.
        final packageService = GetIt.I<PackageService>();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PackageSelectionScreen(
              packageService: packageService,
              currentUser: owner, // Pass the owner user
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email already in use'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // More detailed error message
      String errorMessage = 'Error creating owner account';
      if (e.toString().contains('OAuth')) {
        errorMessage = 'OAuth configuration error. Check setup in Supabase.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Check your internet connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorMessage\n\nDetails: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Setup',
            textColor: Colors.white,
            onPressed: () => OAuthChecker.showSetupDialog(context),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openRegisteredOwnerDashboard(user_model.User owner) async {
    final prefs = await SharedPreferences.getInstance();
    if (owner.businessId != null && owner.businessId!.isNotEmpty) {
      await prefs.setString('business_id', owner.businessId!);
    }
    await prefs.setBool('is_google_auth', true);
    await _googleAuth.storeSession();

    await GetIt.I<SupabaseSyncService>().initializeBusiness(
      businessName: owner.name,
      ownerEmail: owner.email,
      existingBusinessId: owner.businessId,
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OwnerDashboard(user: owner)),
      (route) => false,
    );
  }

  void _onIconTap() {
    setState(() {
      _iconTapCount++;
    });
    if (_iconTapCount >= 7) {
      _iconTapCount = 0; // Reset counter
      Navigator.pushNamed(context, '/developer-auth');
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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.purple.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 550),
                      padding: const EdgeInsets.all(40.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.blue.shade50.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          GestureDetector(
                            onTap: _onIconTap,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.7),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.admin_panel_settings,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Create Owner Account',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32,
                                  letterSpacing: -0.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sign in with Google to create your owner account',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Setup Check Button
                          OutlinedButton.icon(
                            onPressed: () =>
                                OAuthChecker.showSetupDialog(context),
                            icon: const Icon(Icons.info_outline, size: 20),
                            label: const Text(
                              'Check OAuth Setup Status',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // User Agreement Checkbox
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _agreedToTerms
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _agreedToTerms
                                    ? Colors.green.shade400
                                    : Colors.orange.shade400,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (_agreedToTerms
                                              ? Colors.green
                                              : Colors.orange)
                                          .withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Transform.scale(
                                  scale: 1.2,
                                  child: Checkbox(
                                    value: _agreedToTerms,
                                    onChanged: (value) {
                                      setState(
                                        () => _agreedToTerms = value ?? false,
                                      );
                                    },
                                    activeColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade800,
                                        height: 1.4,
                                      ),
                                      children: [
                                        const TextSpan(text: 'I agree to the '),
                                        TextSpan(
                                          text: 'User Agreement',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationThickness: 2,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              PolicyDialogs.showUserAgreement(
                                                context,
                                              );
                                            },
                                        ),
                                        const TextSpan(text: ' and '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationThickness: 2,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              PolicyDialogs.showPrivacyPolicy(
                                                context,
                                              );
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Google Sign In Button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: (_isLoading || !_agreedToTerms)
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.blue.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: (_isLoading || !_agreedToTerms)
                                  ? null
                                  : _signInWithGoogle,
                              icon: _isLoading
                                  ? const SizedBox.shrink()
                                  : Image.asset(
                                      'assets/google_logo.png',
                                      height: 28,
                                      width: 28,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.login,
                                              size: 28,
                                            );
                                          },
                                    ),
                              label: _isLoading
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Signing in...',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Sign in with Google',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                disabledBackgroundColor: Colors.grey.shade200,
                                disabledForegroundColor: Colors.grey.shade400,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: (_isLoading || !_agreedToTerms)
                                        ? Colors.grey.shade300
                                        : Colors.blue.shade200,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // Info Boxes
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.blue.shade100.withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.security,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Why Google Sign In?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '✓ Secure authentication via Google\n'
                                  '✓ No need to remember passwords\n'
                                  '✓ Multi-device sync automatically enabled\n'
                                  '✓ Access your system from any device',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade900,
                                    height: 1.8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.green.shade100.withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.shade300,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_sync,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your data will be securely synced across all your devices',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
