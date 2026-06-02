import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';

// sqflite_common_ffi provides a desktop-friendly sqlite implementation.
// Add `sqflite_common_ffi` to your pubspec.yaml when targeting desktop.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/shared/package_selection_screen.dart';
import 'screens/shared/owner_registration_screen.dart';
import 'screens/shared/developer_auth_screen.dart';
import 'screens/developer/subscribers_screen.dart';
import 'app_router.dart';
import 'theme.dart';
import 'utils/locale_controller.dart';
import 'utils/theme_controller.dart';
import 'utils/motion_controller.dart';
import 'services/pos_service.dart';
import 'services/cctv_service.dart';
import 'services/cctv_config.dart';
import 'services/user_service.dart';
import 'services/admin_service.dart';
import 'services/developer_service.dart';
import 'services/ai_help_service.dart';
import 'services/business_info_service.dart';
import 'services/package_service.dart';
import 'services/subscriber_service.dart';
import 'services/shared_api_service.dart';
import 'services/license_service.dart';
import 'services/supabase_config.dart';
import 'services/supabase_sync_service.dart';
import 'screens/shared/trial_locked_screen.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (for license activation and cross-device sync)
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Supabase initialization failed: $e');
      debugPrint('   App will use offline mode for license validation');
    }
  } else {
    debugPrint('⚠️ Supabase not configured - using offline license validation');
    debugPrint(
      '   To enable cloud sync, update lib/services/supabase_config.dart',
    );
  }

  // Firebase disabled for Windows builds - app runs fully offline
  debugPrint('ℹ️ Running in offline mode (Firebase disabled)');

  // Register and initialize POSService before app starts
  // Initialize sqflite FFI database factory on desktop platforms so
  // `sqflite` APIs (openDatabase, getDatabasesPath, etc.) work correctly.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize persisted theme selection
  await ThemeController.init();
  await MotionController.init();

  // Initialize Business Info Service
  final businessInfoService = BusinessInfoService();
  await businessInfoService.initialize();
  GetIt.I.registerSingleton<BusinessInfoService>(businessInfoService);

  final posService = POSService();
  await posService.initialize();
  GetIt.I.registerSingleton<POSService>(posService);

  // Initialize UserService for managing user accounts
  final userService = UserService();
  await userService.initialize();
  GetIt.I.registerSingleton<UserService>(userService);

  // Initialize AdminService for managing admin account
  final adminService = AdminService();
  GetIt.I.registerSingleton<AdminService>(adminService);

  // Initialize DeveloperService for managing developer account credentials
  final developerService = DeveloperService();
  GetIt.I.registerSingleton<DeveloperService>(developerService);

  // Initialize AI Help Service
  final aiHelpService = AIHelpService();
  GetIt.I.registerSingleton<AIHelpService>(aiHelpService);

  // Initialize License Service (must be before PackageService)
  final licenseService = LicenseService();
  await licenseService.initialize();
  GetIt.I.registerSingleton<LicenseService>(licenseService);

  // Initialize Supabase Sync Service for cloud data sync
  final supabaseSyncService = SupabaseSyncService();
  GetIt.I.registerSingleton<SupabaseSyncService>(supabaseSyncService);
  debugPrint('✅ SupabaseSyncService registered');

  // Initialize Package Service
  final packageService = PackageService();
  await packageService.initialize();
  GetIt.I.registerSingleton<PackageService>(packageService);

  // Initialize Shared API Service (fetches a single shared data object)
  final sharedApiService = SharedApiService();
  await sharedApiService.initialize();
  GetIt.I.registerSingleton<SharedApiService>(sharedApiService);

  // Initialize Subscriber Service and register singleton
  final subscriberService = SubscriberService();
  GetIt.I.registerSingleton<SubscriberService>(subscriberService);

  // Initialize CCTV Service with default demo camera
  final cctvService = CCTVService.instance;
  cctvService.configure(
    cameraUrl: CCTVConfig.defaultCameraUrl,
    recordingsDirectory: CCTVConfig.defaultRecordingsDir,
  );
  // Optional: Test connection on startup (can be slow, so commented out)
  // await cctvService.testConnection();

  // Optional: Seed sample products on first run (uncomment to use)
  // Uncomment the line below and run once to populate demo products
  // await SeedService.seedSampleProducts();

  runApp(const SmartStoreApp());
}

class SmartStoreApp extends StatefulWidget {
  const SmartStoreApp({super.key});

  @override
  State<SmartStoreApp> createState() => _SmartStoreAppState();
}

class _SmartStoreAppState extends State<SmartStoreApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Listen for license changes and auto-lock when trial expires
    _setupLicenseListener();
    // Initialize deep-link listener (Supabase reset links -> app)
    _initDeepLinkListener();
  }

  StreamSubscription? _sub;
  final _appLinks = AppLinks();

  void _initDeepLinkListener() {
    // app_links supports all platforms (Android, iOS, Web, Windows, macOS, Linux)
    // Handle initial link if app was opened via deep link
    () async {
      try {
        final initialUri = await _appLinks.getInitialAppLink();
        if (initialUri != null) {
          _handleIncomingUri(initialUri);
        }
      } catch (e) {
        debugPrint('Deep link initialUri error: $e');
      }
    }();

    // Listen for subsequent incoming links
    try {
      _sub = _appLinks.uriLinkStream.listen(
        (uri) {
          _handleIncomingUri(uri);
        },
        onError: (err) {
          debugPrint('Deep link stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize deep link stream: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleIncomingUri(Uri uri) async {
    debugPrint('Deep link received: $uri');

    // Supabase may return token params in query or fragment
    final params = <String, String>{};
    params.addAll(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      final frag = uri.fragment.replaceFirst('#', '');
      final fragParams = Uri.splitQueryString(frag);
      params.addAll(fragParams);
    }

    // If this looks like a recovery/reset link, try to establish a session
    final code = params['code'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'] ?? params['refreshToken'];
    final token = params['token'];

    try {
      if (code != null) {
        // Exchange authorization code for session (works for OAuth/code flows)
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      } else if (refreshToken != null) {
        await Supabase.instance.client.auth.setSession(refreshToken);
      } else if (accessToken != null) {
        // Some callbacks only include access token in fragment; set session using exchange code if possible
        try {
          await Supabase.instance.client.auth.setSession(accessToken);
        } catch (e) {
          debugPrint('setSession with access token failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Supabase session setup from deep link failed: $e');
    }

    // If the link contains a recovery token or session, prompt for new password
    if (token != null ||
        accessToken != null ||
        refreshToken != null ||
        code != null) {
      final ctx =
          _navigatorKey.currentState?.overlay?.context ??
          _navigatorKey.currentContext;
      if (ctx == null) return;

      // Show a dialog to let user set a new password in-app
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dCtx) {
          final newPassCtrl = TextEditingController();
          final confirmCtrl = TextEditingController();
          bool loading = false;
          return StatefulBuilder(
            builder: (dCtx, setState) {
              return AlertDialog(
                title: const Text('Reset Password'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Set a new password for your account.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(dCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            final np = newPassCtrl.text.trim();
                            final cp = confirmCtrl.text.trim();
                            if (np.length < 6 || np != cp) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Passwords must match and be at least 6 characters',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() => loading = true);
                            try {
                              final auth =
                                  Supabase.instance.client.auth as dynamic;
                              // Try available update methods dynamically to support different SDKs
                              try {
                                await auth.updateUser({'password': np});
                              } catch (_) {
                                try {
                                  await auth.update({'password': np});
                                } catch (e) {
                                  debugPrint('update password failed: $e');
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to update password',
                                      ),
                                    ),
                                  );
                                }
                              }
                              Navigator.pop(dCtx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password updated successfully',
                                  ),
                                ),
                              );
                            } catch (e) {
                              debugPrint(
                                'Password reset via deep link failed: $e',
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            } finally {
                              setState(() => loading = false);
                            }
                          },
                    child: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Set Password'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  void _setupLicenseListener() {
    final licenseService = GetIt.I<LicenseService>();
    licenseService.addListener(() {
      debugPrint(
        '🔔 License listener triggered - isLocked: ${licenseService.isLocked}',
      );

      // If license becomes locked while app is running, navigate to locked screen
      if (licenseService.isLocked) {
        final currentContext = _navigatorKey.currentContext;
        if (currentContext == null) {
          debugPrint('⚠️ Cannot show lock dialog - context is null');
          return;
        }

        // Check if we're already on the locked screen or showing expiration dialog
        final currentRoute = ModalRoute.of(currentContext);
        final routeName = currentRoute?.settings.name;
        debugPrint('📍 Current route: $routeName');

        if (routeName == '/trial-locked' ||
            routeName == '/trial-expired-dialog') {
          debugPrint('✅ Already on locked screen or showing dialog - skipping');
          return; // Already on locked screen or dialog shown, don't navigate again
        }

        // Check widget type as fallback
        if (currentContext.widget is TrialLockedScreen) {
          debugPrint('✅ Already on TrialLockedScreen widget - skipping');
          return;
        }

        debugPrint('🚨 SHOWING EXPIRATION DIALOG NOW!');

        // Show non-dismissible expiration dialog
        showDialog(
          context: currentContext,
          barrierDismissible: false, // Cannot dismiss by tapping outside
          builder: (dialogContext) => PopScope(
            canPop: false, // Prevent back button from closing dialog
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.red.shade700, size: 32),
                  const SizedBox(width: 12),
                  const Text(
                    'Trial Expired',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your free trial period has ended.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The system is now locked and all features are disabled.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'To continue using the system, you need to:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Settle payment for your subscription'),
                        Text('• Enter your activation code'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Contact support if you need assistance with activation.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Close dialog first
                      Navigator.of(dialogContext).pop();

                      // Then force navigation to locked screen
                      _navigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const TrialLockedScreen(),
                          settings: const RouteSettings(name: '/trial-locked'),
                        ),
                        (route) => false, // Remove all previous routes
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Enter Activation Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).then((_) {
          // Fallback: If dialog is somehow dismissed, still force lock screen
          if (licenseService.isLocked) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const TrialLockedScreen(),
                settings: const RouteSettings(name: '/trial-locked'),
              ),
              (route) => false,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeController.themeKey,
      builder: (context, themeKey, _) {
        // Also listen to custom color changes
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeController.customColor,
          builder: (context, customColor, _) {
            final primary = ThemeController.getMaterialColor(themeKey);
            final theme = AppTheme.forPrimary(primary);

            return ValueListenableBuilder<Locale>(
              valueListenable: LocaleController.locale,
              builder: (context, locale, _) {
                return MaterialApp(
                  navigatorKey: _navigatorKey,
                  title: 'Smart Store Monitoring System',
                  debugShowCheckedModeBanner: false,
                  theme: theme,
                  locale: locale,
                  home: const SplashScreen(),
                  routes: {
                    ...AppRouter.routes,
                    '/developer-auth': (context) => const DeveloperAuthScreen(),
                    '/owner-registration': (context) =>
                        const OwnerRegistrationScreen(),
                    '/subscribers': (context) => const SubscribersScreen(),
                    '/package-selection': (context) => PackageSelectionScreen(
                      packageService: GetIt.I<PackageService>(),
                    ),
                  },
                  builder: (context, child) {
                    // Add global overflow protection
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                          MediaQuery.of(
                            context,
                          ).textScaler.scale(1.0).clamp(0.8, 1.3),
                        ),
                      ),
                      child: child ?? const SizedBox(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
