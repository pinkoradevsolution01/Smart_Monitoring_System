import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import '../models/subscriber.dart';
import '../models/subscription_record.dart';
import 'backend_config.dart';
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
      // Older versions stored local owner records here. Subscribers must now
      // come exclusively from the cloud, so discard that legacy cache.
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('Error clearing legacy subscriber cache: $e');
    }
  }

  /// Remove admin accounts from cached subscribers
  /// Called after services are initialized
  // ignore: unused_element
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

      int removed = 0;
      final idsToRemove = <String>[];

      for (var entry in _subs.entries) {
        final emailLower = entry.value.email.toLowerCase();

        // Mark admin accounts for removal
        if (adminEmail != null && emailLower == adminEmail) {
          debugPrint(
            '[SubscriberService] ⏭️  Removing cached admin subscriber: ${entry.value.email}',
          );
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
        debugPrint(
          '[SubscriberService] Removed $removed admin account(s) from cache',
        );
      }
    } catch (e) {
      debugPrint(
        '[SubscriberService] Error removing admin accounts from cache: $e',
      );
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
    // Local owner records are intentionally not shown in Subscribers.
    debugPrint(
      '[SubscriberService] Ignoring local subscriber record: ${s.email}',
    );
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

  SubscriptionRecord? _findMatchingSubscription(Subscriber subscriber) {
    try {
      final cloudService = CloudSubscriptionService();
      final targetEmail = subscriber.email.toLowerCase();
      final targetName = subscriber.name.toLowerCase();
      return cloudService.subscriptions.firstWhere((subscription) {
        return subscription.deviceId == subscriber.id ||
            (subscription.deviceName?.toLowerCase() == targetEmail) ||
            (subscription.deviceName?.toLowerCase() == targetName);
      });
    } catch (_) {
      return null;
    }
  }

  /// Purge a subscriber from local storage and the MySQL backend.
  Future<void> purgeSubscriberData(Subscriber subscriber) async {
    final userService = GetIt.I<UserService>();
    final localUser = userService.getUserByEmail(subscriber.email);
    final cloudService = CloudSubscriptionService();

    // Always refresh cloud subscriptions before resolving identifiers.
    try {
      await cloudService.refresh();
    } catch (_) {
      // Continue with local hints if cloud refresh fails.
    }

    final matchingSubscription = _findMatchingSubscription(subscriber);
    final normalizedEmail = subscriber.email.trim().toLowerCase();
    final normalizedName = subscriber.name.trim().toLowerCase();

    if (!BackendConfig.useRestBackend) {
      throw Exception('Backend deactivation is unavailable in offline mode.');
    }

    final queryParameters = <String, String>{};
    if (normalizedEmail.contains('@')) {
      queryParameters['ownerEmail'] = subscriber.email.trim();
    }

    if ((localUser?.businessId ?? '').isNotEmpty) {
      queryParameters['businessId'] = localUser!.businessId!;
    }

    if ((localUser?.id ?? '').isNotEmpty) {
      queryParameters['ownerId'] = localUser!.id;
    }

    // Use cloud subscription/device hints to target exact subscriber records.
    if ((matchingSubscription?.deviceId ?? '').isNotEmpty) {
      queryParameters['deviceId'] = matchingSubscription!.deviceId;
    } else if (subscriber.id.trim().isNotEmpty) {
      queryParameters['deviceId'] = subscriber.id.trim();
    }

    if ((matchingSubscription?.activationCode ?? '').isNotEmpty) {
      queryParameters['activationCode'] = matchingSubscription!.activationCode;
    }

    // Add a fallback match by scanning subscriptions when this subscriber was
    // resolved via business name/email mapping.
    final fallbackSubscription = cloudService.subscriptions
        .cast<SubscriptionRecord?>()
        .firstWhere((subscription) {
          if (subscription == null) return false;
          final deviceName = subscription.deviceName?.trim().toLowerCase();
          return deviceName == normalizedEmail || deviceName == normalizedName;
        }, orElse: () => null);

    if (fallbackSubscription != null) {
      queryParameters['deviceId'] = fallbackSubscription.deviceId;
      queryParameters['activationCode'] = fallbackSubscription.activationCode;
    }

    if (!queryParameters.containsKey('ownerEmail') &&
        !queryParameters.containsKey('ownerId') &&
        !queryParameters.containsKey('businessId') &&
        !queryParameters.containsKey('deviceId') &&
        !queryParameters.containsKey('activationCode')) {
      throw Exception(
        'Unable to resolve subscriber identity for deactivation. Try syncing first.',
      );
    }

    final result = await _api.deleteJson(
      'business/purge',
      queryParameters: queryParameters,
    );

    if (result is Map<String, dynamic> && result['success'] == false) {
      throw Exception(
        result['message']?.toString() ?? 'Failed to purge subscriber.',
      );
    }

    // Remove locally cached entry, then refresh from cloud to ensure list is accurate.
    _subs.remove(subscriber.id);
    await _save();
    notifyListeners();

    await syncFromAllSources();

    final stillActive = _subs.values.any(
      (s) =>
          s.status == 'active' &&
          (s.id == subscriber.id ||
              s.email.trim().toLowerCase() == normalizedEmail),
    );
    if (stillActive) {
      throw Exception(
        'Deactivation request sent but subscriber still exists in cloud records. Please sync again.',
      );
    }

    debugPrint(
      '[SubscriberService] Purged subscriber data for ${subscriber.email}',
    );
  }

  /// Clear all subscribers
  Future<void> clearAllSubscribers() async {
    _subs.clear();
    await _save();
    notifyListeners();
  }

  /// Sync subscribers from cloud subscriptions only.
  Future<int> syncFromAllSources() async {
    int newCount = 0;

    try {
      debugPrint(
        '[SubscriberService] Starting sync from cloud subscriptions...',
      );

      // Subscribers are sourced exclusively from the cloud.
      try {
        final cloudService = CloudSubscriptionService();
        // Do not retain local records or stale entries from a previous sync.
        _subs.clear();

        // Always refresh the cloud list so new activations show up immediately.
        debugPrint(
          '[SubscriberService] Refreshing subscriptions from backend...',
        );
        await cloudService.refresh();
        debugPrint(
          '[SubscriberService] Cloud subscriptions after refresh: ${cloudService.subscriptions.length}',
        );

        if (cloudService.subscriptions.isEmpty) {
          debugPrint(
            '[SubscriberService] ⚠️ No subscriptions found in cloud database',
          );
        }

        // Platform names that should be filtered out (not actual owner names)
        const platformNames = {
          'Windows',
          'Android',
          'iOS',
          'macOS',
          'Linux',
          'Web',
          'windows',
          'android',
          'ios',
          'macos',
          'linux',
          'web',
          'Unknown',
          'Unknown Device',
          'Unknown Owner',
        };

        // Group subscriptions by device_id to get unique subscribers
        final Map<String, SubscriptionRecord> uniqueDevices = {};
        for (var subscription in cloudService.subscriptions) {
          // Skip subscriptions with platform names as device_name (these are invalid/old records)
          if (subscription.deviceName != null &&
              platformNames.contains(subscription.deviceName)) {
            debugPrint(
              '[SubscriberService] ⚠️ Skipping subscription with platform name: ${subscription.deviceName}',
            );
            continue;
          }

          // Only add if we don't already have this device
          if (!uniqueDevices.containsKey(subscription.deviceId)) {
            uniqueDevices[subscription.deviceId] = subscription;
          }
        }

        debugPrint(
          '[SubscriberService] Processing ${uniqueDevices.length} unique devices from subscriptions',
        );

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

        // Add each unique device as a subscriber.
        // We keep all real cloud activations here so the dashboard reflects
        // actual customer subscriptions instead of only local owner accounts.
        for (var entry in uniqueDevices.entries) {
          final deviceId = entry.key;
          final subscription = entry.value;

          // device_name now contains business name from activation request
          final subscriberName = subscription.deviceName ?? 'Unknown Business';

          // Look up the actual customer email from activation_code_requests
          // using the activation code from the subscription
          String customerEmail = subscriberName; // Fallback to business name
          try {
            debugPrint(
              '[SubscriberService] Looking up email for code: ${subscription.activationCode}',
            );

            final emailResponse = await _api.getJson(
              'license/requests/by-code/${Uri.encodeComponent(subscription.activationCode)}',
            );

            if (emailResponse is Map<String, dynamic> &&
                emailResponse['request'] is Map) {
              final request = Map<String, dynamic>.from(
                emailResponse['request'] as Map,
              );
              customerEmail =
                  request['contact_email'] as String? ?? subscriberName;
              debugPrint(
                '[SubscriberService] ✅ Found email for $subscriberName: $customerEmail',
              );
            } else {
              debugPrint(
                '[SubscriberService] ⚠️ No email request found for code: ${subscription.activationCode}',
              );
            }
          } catch (e) {
            debugPrint(
              '[SubscriberService] ❌ Error looking up email for $subscriberName: $e',
            );
          }

          final emailLower = customerEmail.toLowerCase();
          if (adminEmail != null && emailLower == adminEmail.toLowerCase()) {
            debugPrint(
              '[SubscriberService] ⏭️  Skipping admin account: $customerEmail',
            );
            continue;
          }

          final subscriber = Subscriber(
            id: deviceId,
            name: subscriberName,
            email: customerEmail,
            contactNumber: subscription.packageName,
            createdAt: subscription.activatedAt,
            status: subscription.status,
          );

          if (!_subs.containsKey(deviceId)) {
            newCount++;
            debugPrint(
              '[SubscriberService] Added cloud subscriber: ${subscriber.name} (${subscriber.email})',
            );
          }

          _subs[subscriber.id] = subscriber;
        }
        debugPrint(
          '[SubscriberService] Synced ${uniqueDevices.length} cloud subscriptions',
        );
      } catch (e) {
        debugPrint(
          '[SubscriberService] ❌ Error syncing cloud subscriptions: $e',
        );
      }

      // Save all changes (always save, whether new additions or updates)
      await _save();
      notifyListeners();

      // Debug: Check what we actually synced
      if (_subs.isEmpty) {
        debugPrint(
          '[SubscriberService] ⚠️ WARNING: No subscribers found after sync',
        );
      } else {
        debugPrint(
          '[SubscriberService] ✅ Total subscribers after sync: ${_subs.length}',
        );
        debugPrint('[SubscriberService] 📋 Subscriber List:');
        for (var sub in _subs.values) {
          debugPrint(
            '[SubscriberService]   ☁️  CLOUD: ${sub.name} <${sub.email}> (Package: ${sub.contactNumber})',
          );
        }
      }

      if (newCount > 0) {
        debugPrint(
          '[SubscriberService] ✅ Sync complete. Added $newCount new subscriber${newCount == 1 ? '' : 's'}',
        );
      } else {
        debugPrint(
          '[SubscriberService] ✅ Sync complete. All cloud subscriptions loaded',
        );
      }

      return newCount;
    } catch (e) {
      debugPrint('[SubscriberService] ❌ Error during sync: $e');
      rethrow;
    }
  }

  /// Get subscriber count by source
  Map<String, int> getSubscriberStats() {
    return {'total': _subs.length};
  }
}
