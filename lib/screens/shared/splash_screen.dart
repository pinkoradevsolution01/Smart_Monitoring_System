import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'trial_locked_screen.dart';
import 'owner_registration_screen.dart';
import 'package_selection_screen.dart';
import '../owner/owner_dashboard.dart';
import '../../utils/motion_controller.dart';
import '../../services/package_service.dart';
import '../../services/license_service.dart';
import '../../services/user_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../models/user.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;
  late final Animation<double> _dot1;
  late final Animation<double> _dot2;
  late final Animation<double> _dot3;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _rotation = Tween(
      begin: 0.0,
      end: math.pi * 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _dot1 = Tween(begin: 0.6, end: 1.15).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );
    _dot2 = Tween(begin: 0.6, end: 1.15).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.85, curve: Curves.easeInOut),
      ),
    );
    _dot3 = Tween(begin: 0.6, end: 1.15).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.95, curve: Curves.easeInOut),
      ),
    );

    _fadeIn = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    if (MotionController.reduceMotion.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigateToNextScreen();
      });
    } else {
      _ctrl.forward().whenComplete(() {
        if (!mounted) return;
        _navigateToNextScreen();
      });
    }
  }

  Future<void> _navigateToNextScreen() async {
    final packageService = GetIt.I<PackageService>();
    final licenseService = GetIt.I<LicenseService>();
    final userService = GetIt.I<UserService>();

    // Debug: Log all users in the system
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('SplashScreen: Checking app state...');
    debugPrint('Total users in system: ${userService.users.length}');
    for (final user in userService.users) {
      debugPrint('  • ${user.email} (${user.role}) - Active: ${user.isActive}');
    }

    // FIRST PRIORITY: Check if owner account exists (including inactive ones)
    // Owner registration must happen before any other setup
    final ownerAccounts = userService.getUsersByRoleIncludingInactive(UserRole.owner);
    debugPrint(
      '🔍 Checking owner accounts: Found ${ownerAccounts.length} owner(s)',
    );
    if (ownerAccounts.isNotEmpty) {
      debugPrint(
        '👤 Owner accounts: ${ownerAccounts.map((u) => '${u.email} (${u.isActive ? "Active" : "Inactive"})').join(", ")}',
      );
    }

    if (ownerAccounts.isEmpty) {
      // No owner account, navigate to owner registration
      debugPrint('✅ No owner found - Navigating to Owner Registration Screen');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OwnerRegistrationScreen()),
      );
      return;
    }

    // SECOND PRIORITY: Check if the app is locked due to expired trial or lack of activation
    if (licenseService.isLocked) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TrialLockedScreen()),
      );
      return;
    }

    // Check if setup is complete AND a package is selected
    if (packageService.setupComplete && packageService.hasPackage) {
      // Owner exists and package is selected
      if (ownerAccounts.isNotEmpty) {
        final owner = ownerAccounts.first;
        
        // Initialize business context immediately, then let cloud restore run
        // in the background so the app can open without waiting for a full sync.
        try {
          final supabaseSyncService = GetIt.I<SupabaseSyncService>();
          
          // Initialize business context for this owner
          await supabaseSyncService.initializeBusiness(
            businessName: owner.name,
            ownerEmail: owner.email,
            existingBusinessId: owner.businessId,
          );
          debugPrint('✅ Business context initialized for cloud sync');

          // Fire-and-forget restore. We keep this off the critical path so the
          // first screen becomes interactive sooner.
          unawaited(_restoreCloudDataInBackground(supabaseSyncService));
        } catch (e) {
          debugPrint('⚠️ Warning: Could not initialize business context: $e');
          // App continues - user can still access dashboard but may not sync to cloud
        }
        
        // If owner has set a password, they can login
        // Otherwise, go directly to dashboard for password setup
        if (owner.password.isNotEmpty) {
          // Owner has password, go to login screen
          debugPrint('👤 Owner has password - going to login');
          Navigator.of(context).pushReplacementNamed('/login');
        } else {
          // Owner has no password yet (fresh Google OAuth), go directly to dashboard
          debugPrint('🔐 Owner has no password - going to dashboard for setup');
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OwnerDashboard(
                user: owner,
                showManageAccount: true,
              ),
            ),
          );
        }
      } else {
        // No owner found, go to login (shouldn't happen)
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      // Navigate to package selection, passing the owner user if found
      final owner = ownerAccounts.isNotEmpty ? ownerAccounts.first : null;
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PackageSelectionScreen(
            packageService: packageService,
            currentUser: owner,
          ),
        ),
      );
    }
  }

  Future<void> _restoreCloudDataInBackground(
    SupabaseSyncService supabaseSyncService,
  ) async {
    try {
      final synced = await supabaseSyncService.pullAllData();
      if (synced) {
        final stats = supabaseSyncService.getSyncSummary();
        debugPrint('✅ Data synced from cloud: $stats');
      }
    } catch (e) {
      debugPrint('ℹ️ Auto-sync on login: $e (data will be synced on demand)');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final alt = primary.withAlpha((0.8 * 255).round());

    return Scaffold(
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          // animated background colors
          final t = MotionController.reduceMotion.value
              ? 0.5
              : Curves.easeInOut.transform(_ctrl.value);
          final c1 = _lerpColor(primary, Colors.deepPurple, (t * 0.7));
          final c2 = _lerpColor(
            alt,
            Colors.indigo,
            (0.6 + t * 0.4).clamp(0.0, 1.0),
          );

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.8 + t * 1.6, -1),
                end: Alignment(0.8 - t * 1.6, 1),
                colors: [c1, c2],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // rotating store icon with subtle scale pulse
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final scale = MotionController.reduceMotion.value
                        ? 1.0
                        : 0.9 + 0.15 * math.sin(_ctrl.value * math.pi * 2);
                    final angle = MotionController.reduceMotion.value
                        ? 0.0
                        : _rotation.value;
                    return Transform.rotate(
                      angle: angle,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.12 * 255).round()),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(
                                  (0.12 * 255).round(),
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 250,
                            height: 250,
                            child: Center(
                              child: Image.asset(
                                'sms_logo1.png',
                                width: 240,
                                height: 240,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Fade in "Smart Store Monitoring System" text
                FadeTransition(
                  opacity: _fadeIn,
                  child: const Text(
                    'Smart Store Monitoring System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 28),

                // bouncing dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(scale: _dot1, child: _buildDot()),
                    const SizedBox(width: 10),
                    ScaleTransition(scale: _dot2, child: _buildDot()),
                    const SizedBox(width: 10),
                    ScaleTransition(scale: _dot3, child: _buildDot()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
