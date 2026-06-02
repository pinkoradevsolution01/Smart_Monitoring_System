import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';
import '../utils/device_fingerprint.dart';
import 'supabase_config.dart';
import 'user_service.dart';
import '../models/user.dart';

/// Service to manage app licensing, trial expiry, and activation
class LicenseService extends ChangeNotifier {
  static const String _activationCodeKey = 'activation_code';
  static const String _activationStatusKey = 'activation_status';
  static const String _activationDateKey = 'activation_date';
  static const String _subscriptionModeKey = 'subscription_mode';
  static const String _trialExpiresKey = 'trial_expires';
  static const String _subscriptionExpiresKey =
      'subscription_expires'; // Monthly rental expiry
  static const String _usedCodesKey =
      'used_activation_codes'; // One-time code tracking (legacy - now uses Supabase)
  static const String _deviceIdKey = 'device_id'; // Store device ID locally

  // Supabase client (initialized in main.dart)
  SupabaseClient get _supabase => Supabase.instance.client;

  String? _deviceId; // Cached device ID

  bool _isActivated = false;
  bool _isLocked = false;
  DateTime? _trialExpires;
  DateTime? _subscriptionExpires; // Monthly rental expiry
  String? _activationCode;
  String? _subscriptionMode;
  Timer? _periodicCheckTimer;

  bool get isActivated => _isActivated;
  bool get isLocked => _isLocked;
  DateTime? get trialExpires => _trialExpires;
  DateTime? get subscriptionExpires =>
      _subscriptionExpires; // Monthly rental expiry
  String? get activationCode => _activationCode;
  String? get subscriptionMode => _subscriptionMode;

  /// Initialize the service and check current license status
  Future<void> initialize() async {
    // Initialize device fingerprint
    _deviceId = await DeviceFingerprint.getDeviceId();
    debugPrint('LicenseService: Device ID: $_deviceId');

    // Save device ID to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, _deviceId!);

    await _loadStatus();
    await _checkLicenseStatus();

    // Start periodic license check (production interval)
    _periodicCheckTimer = Timer.periodic(
      const Duration(minutes: 5), // Check every 5 minutes in production
      (_) => _checkLicenseStatus(),
    );

    debugPrint('LicenseService: Initialized with periodic checks every 5m');
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  /// Load current activation and trial status from preferences
  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _activationCode = prefs.getString(_activationCodeKey);
      _isActivated = prefs.getBool(_activationStatusKey) ?? false;
      _subscriptionMode = prefs.getString(_subscriptionModeKey);

      final expiresStr = prefs.getString(_trialExpiresKey);
      if (expiresStr != null) {
        _trialExpires = DateTime.tryParse(expiresStr);
      }

      final subscriptionExpiresStr = prefs.getString(_subscriptionExpiresKey);
      if (subscriptionExpiresStr != null) {
        _subscriptionExpires = DateTime.tryParse(subscriptionExpiresStr);
      }

      debugPrint(
        'LicenseService: Loaded status - activated: $_isActivated, mode: $_subscriptionMode, trial expires: $_trialExpires, subscription expires: $_subscriptionExpires',
      );
    } catch (e) {
      debugPrint('LicenseService: Error loading status: $e');
    }
  }

  /// Check if the app should be locked based on trial expiry or activation status
  Future<void> _checkLicenseStatus() async {
    // CRITICAL: Always reload from SharedPreferences to catch trial activations
    await _loadStatus();

    // Store previous lock state to detect changes
    final wasLocked = _isLocked;

    // MONTHLY RENTAL: Check if subscription has expired
    if (_subscriptionExpires != null &&
        DateTime.now().isAfter(_subscriptionExpires!)) {
      _isLocked = true;
      if (!wasLocked) {
        debugPrint(
          '🔴 LicenseService: SUBSCRIPTION EXPIRED on ${_subscriptionExpires!.toLocal()} - Monthly renewal required!',
        );
      }
      if (wasLocked != _isLocked) {
        notifyListeners();
      }
      return;
    }

    // If activated with valid code AND subscription not expired, unlock
    if (_isActivated &&
        _activationCode != null &&
        _activationCode!.isNotEmpty) {
      // Check if subscription is still valid
      if (_subscriptionExpires == null ||
          DateTime.now().isBefore(_subscriptionExpires!)) {
        _isLocked = false;
        if (wasLocked != _isLocked) {
          final remaining = _subscriptionExpires
              ?.difference(DateTime.now())
              .inDays;
          debugPrint(
            'LicenseService: Unlocked via activation code${remaining != null ? ' - $remaining days remaining' : ''}',
          );
          notifyListeners();
        }
        return;
      }
    }

    // Check if in free trial mode
    if (_subscriptionMode == 'free_trial') {
      if (_trialExpires != null && DateTime.now().isAfter(_trialExpires!)) {
        // Trial has expired - lock the app
        _isLocked = true;
        if (!wasLocked) {
          // State changed from unlocked to locked - this is critical!
          debugPrint(
            '🔴 LicenseService: Trial JUST EXPIRED on ${_trialExpires!.toLocal()} - LOCKING NOW!',
          );
        }
      } else {
        _isLocked = false;
        if (_trialExpires != null) {
          final remaining = _trialExpires!.difference(DateTime.now());
          debugPrint(
            'LicenseService: Trial active - ${remaining.inSeconds} seconds remaining until ${_trialExpires!.toLocal()}',
          );
        }
      }
    } else if (_subscriptionMode == 'paid' ||
        _subscriptionMode == 'activated') {
      // Paid or activated mode - not locked
      _isLocked = false;
    } else {
      // No subscription mode set - not locked (allow initial setup)
      _isLocked = false;
      debugPrint('LicenseService: No subscription mode set - allowing setup');
    }

    // Always notify if lock state changed
    if (wasLocked != _isLocked) {
      debugPrint(
        '🚨 LicenseService: Lock state changed from $wasLocked to $_isLocked - notifying listeners!',
      );
      notifyListeners();
    }
  }

  /// Activate the app with an activation code using Supabase
  /// Returns true if activation was successful
  Future<ActivationResult> activate(String code) async {
    if (code.isEmpty) {
      return ActivationResult(
        success: false,
        message: 'Activation code cannot be empty',
      );
    }

    try {
      // Check if Supabase is configured
      if (!SupabaseConfig.isConfigured) {
        debugPrint(
          '⚠️ LicenseService: Supabase not configured - using offline mode',
        );
        final offlineResult = await _validateOffline(code);
        if (offlineResult.success) {
          await _saveActivation(code, offlineResult.packageName ?? 'Standard');
        }
        return offlineResult;
      }

      // Use Supabase validation (recommended for production)
      debugPrint('LicenseService: Validating code via Supabase...');
      final supabaseResult = await _validateWithSupabase(code);

      if (supabaseResult.success) {
        await _saveActivation(code, supabaseResult.packageName ?? 'Standard');
      }

      return supabaseResult;
    } catch (e) {
      debugPrint('LicenseService: Activation error: $e');

      // If Supabase fails, try offline validation as fallback
      final offlineResult = await _validateOffline(code);
      if (offlineResult.success) {
        await _saveActivation(code, offlineResult.packageName ?? 'Standard');
      }
      return offlineResult;
    }
  }

  /// Validate activation code with Supabase (server-side enforcement)
  Future<ActivationResult> _validateWithSupabase(String code) async {
    try {
      debugPrint('LicenseService: Checking code in Supabase database...');

      // Check if code exists and is unused
      final response = await _supabase
          .from('activation_codes')
          .select('code, package_name, status, device_id, created_at')
          .eq('code', code)
          .maybeSingle();

      if (response == null) {
        debugPrint('LicenseService: Code not found in database');
        return ActivationResult(
          success: false,
          message: 'Invalid activation code',
        );
      }

      final status = response['status'] as String?;
      // Unused codes are lifetime valid — no expiry check on creation date.
      // The 30-day subscription clock only starts from the moment of activation.

      // SECURITY: Each code is strictly one-time use.
      // Once marked 'used', no device (including the same device) can reuse it.
      if (status == 'used') {
        debugPrint('LicenseService: Code already used — one-time use only');
        return ActivationResult(
          success: false,
          message: 'This activation code has already been used. Each code can only be activated once.',
        );
      }

      if (status == 'revoked') {
        debugPrint('LicenseService: Code has been revoked');
        return ActivationResult(
          success: false,
          message: 'This activation code has been revoked',
        );
      }

      // Valid statuses: 'unused' or 'assigned' (assigned by developer, ready for activation)
      if (status != 'unused' && status != 'assigned' && status != 'used') {
        debugPrint('LicenseService: Invalid code status: $status');
        return ActivationResult(
          success: false,
          message: 'Invalid activation code status',
        );
      }

      // Get device info and owner's actual name
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();
      final platformName = deviceInfo['platform'] ?? 'Unknown';
      
      // Get the business name from activation_code_requests
      // (This was provided by the developer when they fulfilled the request)
      String businessName = 'Unknown Business';
      try {
        // Look up the activation code request to get the business name
        final requestResponse = await _supabase
            .from('activation_code_requests')
            .select('business_name')
            .eq('activation_code', code)
            .maybeSingle();
        
        if (requestResponse != null) {
          businessName = requestResponse['business_name'] as String? ?? 'Unknown Business';
          debugPrint('LicenseService: Found business name from request: $businessName');
        } else {
          // Fallback: Try to get owner name from local UserService
          if (GetIt.I.isRegistered<UserService>()) {
            final userService = GetIt.I.get<UserService>();
            final owners = userService.getUsersByRole(UserRole.owner);
            if (owners.isNotEmpty) {
              businessName = owners.first.name;
              debugPrint('LicenseService: Using owner name from local UserService: $businessName');
            }
          }
        }
      } catch (e) {
        debugPrint('LicenseService: Error getting business name: $e');
        // Final fallback: try to get from UserService
        try {
          if (GetIt.I.isRegistered<UserService>()) {
            final userService = GetIt.I.get<UserService>();
            final owners = userService.getUsersByRole(UserRole.owner);
            if (owners.isNotEmpty) {
              businessName = owners.first.name;
            }
          }
        } catch (_) {
          // Use default
        }
      }

      debugPrint('LicenseService: Activating code for business: $businessName (platform: $platformName)');

      // Mark code as used and link to device
      // Store business name (not platform) as device_name for dashboard display
      await _supabase
          .from('activation_codes')
          .update({
            'status': 'used',
            'device_id': _deviceId,
            'device_name': businessName,
            'used_at': DateTime.now().toIso8601String(),
          })
          .eq('code', code);

      debugPrint('LicenseService: Code marked as used in database');

      // Create subscription record
      final subscriptionExpires = DateTime.now().add(
        const Duration(days: 30), // PRODUCTION: 30 days monthly rental
      );

      // Insert subscription with business name (from the activation request)
      await _supabase.from('subscriptions').insert({
        'device_id': _deviceId,
        'activation_code': code,
        'package_name': response['package_name'],
        'device_name': businessName,  // Use business name from activation request
        'activated_at': DateTime.now().toIso8601String(),
        'expires_at': subscriptionExpires.toIso8601String(),
        'status': 'active',
      });

      debugPrint(
        'LicenseService: Subscription created - expires ${subscriptionExpires.toLocal()}',
      );

      return ActivationResult(
        success: true,
        message:
            'Activated successfully with ${response['package_name']} package',
        packageName: response['package_name'],
      );
    } on PostgrestException catch (e) {
      debugPrint('LicenseService: Database error: ${e.message}');
      return ActivationResult(
        success: false,
        message: 'Database error: ${e.message}',
      );
    } catch (e) {
      debugPrint('LicenseService: Supabase validation error: $e');
      rethrow; // Let caller handle offline fallback
    }
  }

  /// Validate activation code offline using a simple algorithm
  /// This is a fallback for when Supabase validation fails or is unavailable
  Future<ActivationResult> _validateOffline(String code) async {
    // Check if code was already used (one-time use enforcement)
    final prefs = await SharedPreferences.getInstance();
    final usedCodes = prefs.getStringList(_usedCodesKey) ?? [];

    if (usedCodes.contains(code)) {
      debugPrint('LicenseService: Code already used - $code');
      return ActivationResult(
        success: false,
        message: 'This activation code has already been used',
      );
    }

    // Development test codes (hardcoded for testing - reusable)
    const testCodes = [
      'TEST1234567890ABCDEF', // Simple test code
      'DEV20240209TESTCODE1', // Development code
      'ABCDEFGHIJ0123456789', // Another test code
    ];

    if (testCodes.contains(code)) {
      debugPrint('LicenseService: Test code accepted (dev mode - reusable)');
      return ActivationResult(
        success: true,
        message: 'Activated with test code (development)',
        packageName: 'Standard',
      );
    }

    // Basic format check: should be uppercase alphanumeric, 20+ chars
    final validFormat = RegExp(r'^[A-Z0-9]{20,}$');
    if (!validFormat.hasMatch(code)) {
      return ActivationResult(
        success: false,
        message: 'Invalid code format (must be 20+ uppercase alphanumeric)',
      );
    }

    // Simple checksum validation (example: sum of char codes divisible by 7)
    int sum = 0;
    for (int i = 0; i < code.length; i++) {
      sum += code.codeUnitAt(i);
    }

    if (sum % 7 == 0) {
      // Valid code - mark as used to prevent reuse
      usedCodes.add(code);
      await prefs.setStringList(_usedCodesKey, usedCodes);
      debugPrint('LicenseService: Code marked as used - $code');

      return ActivationResult(
        success: true,
        message: 'Activated offline (verification pending)',
        packageName: 'Standard', // Default to Standard for offline
      );
    }

    return ActivationResult(
      success: false,
      message: 'Invalid activation code (checksum failed)',
    );
  }

  /// Save successful activation to preferences
  Future<void> _saveActivation(String code, String packageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // MONTHLY RENTAL: Set subscription expiry to 1 month from now
      final subscriptionExpires = now.add(
        const Duration(days: 30), // PRODUCTION: 30 days monthly rental
      );

      await prefs.setString(_activationCodeKey, code);
      await prefs.setBool(_activationStatusKey, true);
      await prefs.setString(_subscriptionModeKey, 'activated');
      await prefs.setString(_activationDateKey, now.toIso8601String());
      await prefs.setString(
        _subscriptionExpiresKey,
        subscriptionExpires.toIso8601String(),
      );

      _activationCode = code;
      _isActivated = true;
      _isLocked = false;
      _subscriptionMode = 'activated';
      _subscriptionExpires = subscriptionExpires;

      notifyListeners();

      debugPrint(
        'LicenseService: Activation saved - $packageName package - expires ${subscriptionExpires.toLocal()} (30-day subscription)',
      );
    } catch (e) {
      debugPrint('LicenseService: Error saving activation: $e');
      rethrow;
    }
  }

  /// Deactivate the app (for testing or admin purposes)
  Future<void> deactivate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activationCodeKey);
      await prefs.remove(_activationStatusKey);
      await prefs.remove(_activationDateKey);
      await prefs.remove(_subscriptionExpiresKey);

      _activationCode = null;
      _isActivated = false;
      _isLocked = true;
      _subscriptionExpires = null;

      notifyListeners();

      debugPrint('LicenseService: Deactivated successfully');
    } catch (e) {
      debugPrint('LicenseService: Error during deactivation: $e');
    }
  }

  /// Refresh license status (useful after restoring from backup or reinstall)
  Future<void> refreshStatus() async {
    await _loadStatus();
    await _checkLicenseStatus();
  }

  /// Force immediate license check (useful for testing trial expiry)
  Future<void> forceCheck() async {
    debugPrint('LicenseService: Force checking license status...');
    await _checkLicenseStatus();
  }

  /// Get days remaining in trial (returns null if not in trial or trial expired)
  int? getDaysRemainingInTrial() {
    if (_subscriptionMode != 'free_trial' || _trialExpires == null) {
      return null;
    }

    final now = DateTime.now();
    if (now.isAfter(_trialExpires!)) {
      return 0;
    }

    return _trialExpires!.difference(now).inDays;
  }

  /// Get minutes remaining in trial
  int? getMinutesRemainingInTrial() {
    if (_subscriptionMode != 'free_trial' || _trialExpires == null) {
      return null;
    }

    final now = DateTime.now();
    if (now.isAfter(_trialExpires!)) {
      return 0;
    }

    return _trialExpires!.difference(now).inMinutes;
  }

  /// Check if trial is about to expire (within 3 days)
  bool isTrialExpiringSoon() {
    final days = getDaysRemainingInTrial();
    return days != null && days > 0 && days <= 3;
  }

  /// Get days remaining in subscription (monthly rental)
  int? getDaysRemainingInSubscription() {
    if (_subscriptionExpires == null) {
      return null;
    }

    final now = DateTime.now();
    if (now.isAfter(_subscriptionExpires!)) {
      return 0;
    }

    return _subscriptionExpires!.difference(now).inDays;
  }

  /// Get minutes remaining in subscription (useful for testing 3-minute subscriptions)
  int? getMinutesRemainingInSubscription() {
    if (_subscriptionExpires == null) {
      return null;
    }

    final now = DateTime.now();
    if (now.isAfter(_subscriptionExpires!)) {
      return 0;
    }

    return _subscriptionExpires!.difference(now).inMinutes;
  }

  /// Check if subscription is about to expire (within 3 days)
  bool isSubscriptionExpiringSoon() {
    final days = getDaysRemainingInSubscription();
    return days != null && days > 0 && days <= 3;
  }

  /// Check if lock is due to subscription expiry (not trial expiry)
  bool isSubscriptionExpired() {
    return _subscriptionExpires != null &&
        DateTime.now().isAfter(_subscriptionExpires!);
  }

  /// Check if lock is due to trial expiry (not subscription expiry)
  bool isTrialExpired() {
    return _subscriptionMode == 'free_trial' &&
        _trialExpires != null &&
        DateTime.now().isAfter(_trialExpires!);
  }

  /// Fetch all used activation codes from Supabase (admin/developer only)
  /// Returns a list of maps with code details and associated subscription info
  Future<List<Map<String, dynamic>>> getUsedActivationCodes() async {
    try {
      if (!SupabaseConfig.isConfigured) {
        debugPrint('LicenseService: Supabase not configured');
        return [];
      }

      debugPrint('LicenseService: Fetching used activation codes...');

      // Fetch all used codes with subscription info
      final response = await _supabase
          .from('activation_codes')
          .select('code, package_name, status, device_id, device_name, used_at')
          .eq('status', 'used')
          .order('used_at', ascending: false);

      debugPrint(
        'LicenseService: Fetched ${response.length} used activation codes',
      );

      // For each code, get subscription status
      final results = <Map<String, dynamic>>[];
      for (final code in response) {
        final subscription = await _supabase
            .from('subscriptions')
            .select('status, expires_at, activated_at')
            .eq('activation_code', code['code'])
            .maybeSingle();

        results.add({
          ...code,
          'subscription_status': subscription?['status'],
          'subscription_expires_at': subscription?['expires_at'],
          'subscription_activated_at': subscription?['activated_at'],
        });
      }

      return results;
    } on PostgrestException catch (e) {
      debugPrint('LicenseService: Database error fetching codes: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('LicenseService: Error fetching used codes: $e');
      return [];
    }
  }

  /// Revoke an activation code and cancel its subscription (admin/developer only)
  /// This marks the code as 'revoked' and cancels any active subscription
  Future<RevokeResult> revokeActivationCode(String code, String reason) async {
    try {
      if (!SupabaseConfig.isConfigured) {
        debugPrint('LicenseService: Supabase not configured');
        return RevokeResult(success: false, message: 'Supabase not configured');
      }

      debugPrint('LicenseService: Revoking activation code: $code');

      // Check if code exists
      final codeCheck = await _supabase
          .from('activation_codes')
          .select('code, status')
          .eq('code', code)
          .maybeSingle();

      if (codeCheck == null) {
        return RevokeResult(success: false, message: 'Code not found');
      }

      if (codeCheck['status'] == 'revoked') {
        return RevokeResult(success: false, message: 'Code is already revoked');
      }

      // Revoke the code
      await _supabase
          .from('activation_codes')
          .update({'status': 'revoked', 'notes': 'Revoked: $reason'})
          .eq('code', code);

      debugPrint('LicenseService: Code marked as revoked in database');

      // Cancel associated subscription
      final subscriptionUpdate = await _supabase
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'notes': 'Cancelled: Code revoked - $reason',
          })
          .eq('activation_code', code)
          .select();

      if (subscriptionUpdate.isNotEmpty) {
        debugPrint(
          'LicenseService: Cancelled ${subscriptionUpdate.length} subscription(s)',
        );
      } else {
        debugPrint(
          'LicenseService: No active subscriptions found for this code',
        );
      }

      return RevokeResult(
        success: true,
        message: 'Code revoked and subscription cancelled',
        subscriptionsCancelled: subscriptionUpdate.length,
      );
    } on PostgrestException catch (e) {
      debugPrint('LicenseService: Database error revoking code: ${e.message}');
      return RevokeResult(
        success: false,
        message: 'Database error: ${e.message}',
      );
    } catch (e) {
      debugPrint('LicenseService: Error revoking code: $e');
      return RevokeResult(success: false, message: 'Error: $e');
    }
  }
}

/// Result of an activation attempt
class ActivationResult {
  final bool success;
  final String message;
  final String? packageName;

  ActivationResult({
    required this.success,
    required this.message,
    this.packageName,
  });
}

/// Result of a code revocation attempt
class RevokeResult {
  final bool success;
  final String message;
  final int? subscriptionsCancelled;

  RevokeResult({
    required this.success,
    required this.message,
    this.subscriptionsCancelled,
  });
}
