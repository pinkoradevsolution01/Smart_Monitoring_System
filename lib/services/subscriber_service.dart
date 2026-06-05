import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import '../models/subscriber.dart';
import '../models/subscription_record.dart';
import '../models/user.dart';
import 'backend_api_service.dart';
import 'cloud_subscription_service.dart';
import 'admin_service.dart';
import 'user_service.dart';

class SubscriberService extends ChangeNotifier {
  static final SubscriberService _instance = SubscriberService._internal();
  factory SubscriberService() => _instance;
  SubscriberService._internal() {
    _initialize();
  }

  static const String _key = 'subscribers_data';
  final Map<String, Subscriber> _subs = {};
  final ApiClient _api = ApiClient();

  List<Subscriber> get subscribers => _subs.values.toList();

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> list = jsonDecode(saved);
        for (final item in list) {
          final s = Subscriber.fromMap(Map<String, dynamic>.from(item));
          _subs[s.id] = s;
        }
        
        // Perform cleanup: remove admin accounts from cached subscribers
        // This will happen after services are initialized
        Future.delayed(Duration(milliseconds: 100), () async {
          await _removeAdminAccountsFromCache();
        });
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading subscribers: $e');
    }
  }
  
  /// Remove admin accounts from cached subscribers
  /// Called after services are initialized
  Future<void> _removeAdminAccountsFromCache() async {
    try {
      // Get admin email to filter out  
      String? adminEmail;
      try {
        final adminService = GetIt.I.get<AdminService>();
        adminEmail = adminService.adminAccount.email.isNotEmpty
            ? adminService.adminAccount.email.toLowerCase()
            : null;
      } catch (e) {
        debugPrint('[SubscriberService] Could not get admin email: $e');
        return; // Services not ready yet, skip cleanup
      }
      
      // Get owner emails to filter
      final Set<String> ownerEmails = {};
      try {
        final userService = GetIt.I.get<UserService>();
        final owners = userService.getUsersByRole(UserRole.owner);
        for (var owner in owners) {
          ownerEmails.add(owner.email.toLowerCase());
        }
      } catch (e) {
        debugPrint('[SubscriberService] Could not get owner emails: $e');
        return; // Services not ready yet, skip cleanup
      }
      
      int removed = 0;
      final idsToRemove = <String>[];
      
      for (var entry in _subs.entries) {
        final emailLower = entry.value.email.toLowerCase();
        
        // Mark admin accounts for removal
        if (adminEmail != null && emailLower == adminEmail) {
          debugPrint('[SubscriberService] ⏭️  Removing cached admin subscriber: ${entry.value.email}');
          idsToRemove.add(entry.key);
          removed++;
        }
        // Remove non-owner accounts
        else if (ownerEmails.isNotEmpty && !ownerEmails.contains(emailLower)) {
          debugPrint('[SubscriberService] ⏭️  Removing cached non-owner subscriber: ${entry.value.email}');
          idsToRemove.add(entry.key);
          removed++;
        }
      }
      
      // Remove the identified subscribers
      for (var id in idsToRemove) {
        _subs.remove(id);
      }
      
      if (removed > 0) {
        await _save();
        notifyListeners();
        debugPrint('[SubscriberService] Removed $removed admin/non-owner account(s) from cache');
      }
    } catch (e) {
      debugPrint('[SubscriberService] Error removing admin accounts from cache: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _subs.values.map((s) => s.toMap()).toList();
      await prefs.setString(_key, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving subscribers: $e');
    }
  }

  Future<void> addSubscriber(Subscriber s) async {
    _subs[s.id] = s;
    await _save();
    notifyListeners();
  }

  Future<void> addSubscriberFromUser({
    required String id,
    required String name,
    required String email,
    String? contact,
  }) async {
    final s = Subscriber(
      id: id,
      name: name,
      email: email,
      contactNumber: contact,
      createdAt: DateTime.now(),
    );
    await addSubscriber(s);
  }

  Subscriber? getByEmail(String email) {
    try {
      return _subs.values.firstWhere(
        (s) => s.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Remove a subscriber by ID
  Future<void> removeSubscriber(String id) async {
    _subs.remove(id);
    await _save();
    notifyListeners();
  }

  /// Clear all subscribers
  Future<void> clearAllSubscribers() async {
    _subs.clear();
    await _save();
    notifyListeners();
  }

  /// Sync subscribers from all sources (local owners + cloud subscriptions)
  /// This consolidates subscribers from both local database and Supabase
  Future<int> syncFromAllSources() async {
    int newCount = 0;
    
    try {
      debugPrint('[SubscriberService] Starting sync from cloud subscriptions...');
      
      // ONLY sync from Supabase cloud - owners register via Google OAuth and are pushed to cloud
      // This prevents admin accounts from being recorded
      try {
        final cloudService = CloudSubscriptionService();
        
        // Fetch subscriptions if empty
        debugPrint('[SubscriberService] Cloud subscriptions before fetch: ${cloudService.subscriptions.length}');
        
        if (cloudService.subscriptions.isEmpty) {
          debugPrint('[SubscriberService] Fetching subscriptions from Supabase...');
          await cloudService.fetchSubscriptions();
          debugPrint('[SubscriberService] Cloud subscriptions after fetch: ${cloudService.subscriptions.length}');
        }
        
        if (cloudService.subscriptions.isEmpty) {
          debugPrint('[SubscriberService] ⚠️ No subscriptions found in cloud database, using local owners only');
        }
        
        // DON'T clear local owners - they should always be visible
        // Just add/update cloud subscriptions separately
        
        // Platform names that should be filtered out (not actual owner names)
        const platformNames = {
          'Windows', 'Android', 'iOS', 'macOS', 'Linux', 'Web',
          'windows', 'android', 'ios', 'macos', 'linux', 'web',
          'Unknown', 'Unknown Device', 'Unknown Owner',
        };
        
        // Group subscriptions by device_id to get unique subscribers
        final Map<String, SubscriptionRecord> uniqueDevices = {};
        for (var subscription in cloudService.subscriptions) {
          // Skip subscriptions with platform names as device_name (these are invalid/old records)
          if (subscription.deviceName != null && platformNames.contains(subscription.deviceName)) {
            debugPrint('[SubscriberService] ⚠️ Skipping subscription with platform name: ${subscription.deviceName}');
            continue;
          }
          
          // Only add if we don't already have this device
          if (!uniqueDevices.containsKey(subscription.deviceId)) {
            uniqueDevices[subscription.deviceId] = subscription;
          }
        }
        
        debugPrint('[SubscriberService] Processing ${uniqueDevices.length} unique devices from subscriptions');
        
        // Get admin email to filter out admin accounts from subscribers
        String? adminEmail;
        try {
          final adminService = GetIt.I.get<AdminService>();
          adminEmail = adminService.adminAccount.email.isNotEmpty
              ? adminService.adminAccount.email
              : null;
        } catch (e) {
          debugPrint('[SubscriberService] ⚠️ Could not get admin email: $e');
        }
        
        // Get all owner emails to only sync owners (not admins or other roles)
        final Set<String> ownerEmails = {};
        try {
          final userService = GetIt.I.get<UserService>();
          final owners = userService.getUsersByRole(UserRole.owner);
          for (var owner in owners) {
            ownerEmails.add(owner.email.toLowerCase());
          }
          debugPrint('[SubscriberService] Found ${ownerEmails.length} owner email(s): $ownerEmails');
        } catch (e) {
          debugPrint('[SubscriberService] ⚠️ Could not get owner emails: $e');
        }
        
        // Add each unique device as a subscriber (cloud subscriptions ONLY - owners only)
        for (var entry in uniqueDevices.entries) {
          final deviceId = entry.key;
          final subscription = entry.value;
          
          // device_name now contains business name from activation request
          final subscriberName = subscription.deviceName ?? 'Unknown Business';
          
          // Look up the actual customer email from activation_code_requests
          // using the activation code from the subscription
          String customerEmail = subscriberName; // Fallback to business name
          try {
            debugPrint('[SubscriberService] Looking up email for code: ${subscription.activationCode}');

            final emailResponse = await _api.getJson(
              'license/requests/by-code/${Uri.encodeComponent(subscription.activationCode)}',
            );

            if (emailResponse is Map<String, dynamic> &&
                emailResponse['request'] is Map) {
              final request = Map<String, dynamic>.from(emailResponse['request'] as Map);
              customerEmail = request['contact_email'] as String? ?? subscriberName;
              debugPrint('[SubscriberService] ✅ Found email for $subscriberName: $customerEmail');
            } else {
              debugPrint('[SubscriberService] ⚠️ No email request found for code: ${subscription.activationCode}');
            }
          } catch (e) {
            debugPrint('[SubscriberService] ❌ Error looking up email for $subscriberName: $e');
          }
          
          // Filter out admin accounts - only keep owner accounts
          final emailLower = customerEmail.toLowerCase();
          if (adminEmail != null && emailLower == adminEmail.toLowerCase()) {
            debugPrint('[SubscriberService] ⏭️  Skipping admin account: $customerEmail');
            continue;
          }
          
          // Only sync if they are an owner (or if we can't determine ownership, include them)
          if (ownerEmails.isNotEmpty && !ownerEmails.contains(emailLower)) {
            debugPrint('[SubscriberService] ⏭️  Skipping non-owner account: $customerEmail');
            continue;
          }
          
          final subscriber = Subscriber(
            id: deviceId,
            name: subscriberName,
            email: customerEmail,
            contactNumber: subscription.packageName,
            createdAt: subscription.activatedAt,
          );
          
          if (!_subs.containsKey(deviceId)) {
            newCount++;
            debugPrint('[SubscriberService] Added cloud subscriber: ${subscriber.name} (${subscriber.email})');
          }
          
          _subs[subscriber.id] = subscriber;
        }
        debugPrint('[SubscriberService] Synced ${uniqueDevices.length} cloud subscriptions');
      } catch (e) {
        debugPrint('[SubscriberService] ❌ Error syncing cloud subscriptions: $e');
      }
      
      // Save all changes (always save, whether new additions or updates)
      await _save();
      notifyListeners();
      
      // Debug: Check what we actually synced
      if (_subs.isEmpty) {
        debugPrint('[SubscriberService] ⚠️ WARNING: No subscribers found after sync');
      } else {
        debugPrint('[SubscriberService] ✅ Total subscribers after sync: ${_subs.length}');
        debugPrint('[SubscriberService] 📋 Subscriber List:');
        for (var sub in _subs.values) {
          debugPrint('[SubscriberService]   ☁️  CLOUD: ${sub.name} <${sub.email}> (Package: ${sub.contactNumber})');
        }
      }
      
      if (newCount > 0) {
        debugPrint('[SubscriberService] ✅ Sync complete. Added $newCount new subscriber${newCount == 1 ? '' : 's'}');
      } else {
        debugPrint('[SubscriberService] ✅ Sync complete. All cloud subscriptions loaded');
      }
      
      return newCount;
    } catch (e) {
      debugPrint('[SubscriberService] ❌ Error during sync: $e');
      rethrow;
    }
  }

  /// Get subscriber count by source
  Map<String, int> getSubscriberStats() {
    return {
      'total': _subs.length,
    };
  }
}
