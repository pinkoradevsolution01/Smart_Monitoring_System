import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'subscriber_service.dart';
import 'backend_api_service.dart';
import 'backend_config.dart';
import '../services/package_service.dart';
import '../models/pricing_package.dart';
import '../models/user.dart';
import 'supabase_sync_service.dart';

/// Service to manage user accounts (owners and cashiers).
/// Persists to SharedPreferences for persistent storage across app sessions.
class UserService extends ChangeNotifier {
  static final UserService _instance = UserService._internal();
  final ApiClient _api = ApiClient();

  factory UserService() {
    return _instance;
  }

  UserService._internal();

  final Map<String, User> _users = {};
  static const String _usersKey = 'users_data';
  // One-time migration for an owner record that existed only in old device
  // storage and was confirmed absent from the authoritative backend.
  static const String _legacyOwnerCleanupKey =
      'legacy_owner_cache_cleanup_20260910';
  static const String _legacyOwnerEmail = 'jbgubot26@gmail.com';
  bool _isInitialized = false;

  List<User> get users => _users.values.toList();

  List<User> get activeUsers => _users.values.where((u) => u.isActive).toList();

  /// Initialize the user service and load existing users
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _initializeDefaults();
    _isInitialized = true;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _users.clear();
    _isInitialized = false;
  }

  /// Initialize with default demo accounts
  Future<void> _initializeDefaults() async {
    // Try to load from SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_usersKey);

    if (savedData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(savedData);
        debugPrint(
          'UserService: Loading ${jsonList.length} users from SharedPreferences',
        );
        for (var userJson in jsonList) {
          final user = User.fromMap(userJson as Map<String, dynamic>);
          _users[user.id] = user;
          debugPrint(
            '  ✓ Loaded user: ${user.email} (${user.role}) - Active: ${user.isActive}',
          );
        }
        await _removeConfirmedStaleOwnerCache(prefs);
        debugPrint('UserService: Total users loaded: ${_users.length}');
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Error loading users: $e');
      }
    }

    // If no saved data or error, create only a default cashier account
    // Owner account must be created through the owner registration screen
    final cashier = User(
      id: 'cashier-1',
      name: 'Jane Cashier',
      email: 'cashier@store.com',
      password: 'cashier123',
      pin: '5678',
      role: UserRole.cashier,
      createdAt: DateTime.now(),
      isActive: true,
    );

    _users[cashier.id] = cashier;
    debugPrint(
      'UserService: No saved users found, created default cashier account',
    );

    // Save the default users
    await _saveToPreferences();
  }

  /// Save users to SharedPreferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> usersList = _users.values
          .map((user) => user.toMap())
          .toList();
      await prefs.setString(_usersKey, jsonEncode(usersList));
    } catch (e) {
      debugPrint('Error saving users: $e');
    }
  }

  /// Removes one confirmed stale, local-only owner record without touching
  /// backend data or any other locally stored business data.
  Future<void> _removeConfirmedStaleOwnerCache(
    SharedPreferences prefs,
  ) async {
    if (prefs.getBool(_legacyOwnerCleanupKey) == true) return;

    final staleUserIds = _users.entries
        .where(
          (entry) =>
              entry.value.role == UserRole.owner &&
              entry.value.email.trim().toLowerCase() == _legacyOwnerEmail,
        )
        .map((entry) => entry.key)
        .toList();

    for (final userId in staleUserIds) {
      _users.remove(userId);
    }
    if (staleUserIds.isNotEmpty) {
      await _saveToPreferences();
      debugPrint('UserService: Removed confirmed stale local owner cache.');
    }
    await prefs.setBool(_legacyOwnerCleanupKey, true);
  }

  SupabaseSyncService? _maybeSyncService() {
    try {
      return GetIt.I.isRegistered<SupabaseSyncService>()
          ? GetIt.I<SupabaseSyncService>()
          : null;
    } catch (_) {
      return null;
    }
  }

  void _queueCloudSync() {
    final sync = _maybeSyncService();
    if (sync != null && sync.isConfigured) {
      sync.queuePushAllData();
    }
  }

  String? _currentBusinessId() {
    try {
      return _maybeSyncService()?.businessId;
    } catch (_) {
      return null;
    }
  }

  /// Add a new user
  Future<bool> addUser(User user, {bool queueCloudSync = true}) async {
    // Check if email already exists
    if (_users.values.any((u) => u.email == user.email && u.id != user.id)) {
      return false;
    }
    _users[user.id] = user;
    await _saveToPreferences();

    // Only create a Subscriber entry for OWNER role authenticated via Google OAuth
    // Managers and other roles should NOT be recorded as subscribers
    if (user.role == UserRole.owner && user.authMethod == 'google') {
      try {
        // ensure SubscriberService singleton initialized
        final subSvc = SubscriberService();
        await subSvc.addSubscriberFromUser(
          id: user.id,
          name: user.name,
          email: user.email,
          contact: user.contactNumber,
        );
      } catch (e) {
        debugPrint('Failed to create subscriber for owner: $e');
      }
    }

    notifyListeners();
    if (queueCloudSync) {
      _queueCloudSync();
    }
    return true;
  }

  /// Update an existing user
  Future<bool> updateUser(User user, {bool queueCloudSync = true}) async {
    if (!_users.containsKey(user.id)) {
      return false;
    }
    // Check if new email is already used by another user
    if (_users.values.any((u) => u.email == user.email && u.id != user.id)) {
      return false;
    }
    _users[user.id] = user;
    await _saveToPreferences();
    notifyListeners();
    if (queueCloudSync) {
      _queueCloudSync();
    }
    return true;
  }

  /// Remove a user (soft delete via isActive flag)
  Future<bool> removeUser(String userId, {bool queueCloudSync = true}) async {
    if (!_users.containsKey(userId)) {
      return false;
    }
    final user = _users[userId]!;
    _users[userId] = user.copyWith(isActive: false);
    await _saveToPreferences();
    if (BackendConfig.useRestBackend) {
      final businessId = _currentBusinessId();
      if (businessId != null && businessId.isNotEmpty) {
        await _api.patchJson(
          'auth/users/${Uri.encodeComponent(userId)}',
          body: {'businessId': businessId, 'isActive': false},
        );
      }
    }
    notifyListeners();
    if (queueCloudSync) {
      _queueCloudSync();
    }
    return true;
  }

  /// Hard delete a user (completely remove)
  Future<bool> deleteUserPermanently(
    String userId, {
    bool queueCloudSync = true,
  }) async {
    if (!_users.containsKey(userId)) {
      return false;
    }
    if (BackendConfig.useRestBackend) {
      final businessId = _currentBusinessId();
      if (businessId != null && businessId.isNotEmpty) {
        await _api.deleteJson(
          'auth/users/${Uri.encodeComponent(userId)}',
          queryParameters: {'businessId': businessId},
        );
      }
    }
    _users.remove(userId);
    await _saveToPreferences();
    notifyListeners();
    if (queueCloudSync) {
      _queueCloudSync();
    }
    return true;
  }

  /// Removes an account from this device only.
  ///
  /// This is intentionally separate from [deleteUserPermanently]. It is used
  /// when a legacy account remains in SharedPreferences but no longer exists
  /// in the authoritative backend. It never sends a delete request or queues
  /// a cloud sync, so it cannot delete an unrelated server account.
  Future<bool> deleteLocalCachedUser(String userId) async {
    if (!_users.containsKey(userId)) {
      return false;
    }

    _users.remove(userId);
    await _saveToPreferences();
    notifyListeners();
    return true;
  }

  /// Get user by email
  User? getUserByEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      return _users.values.firstWhere(
        (u) => u.email.trim().toLowerCase() == normalizedEmail,
      );
    } catch (_) {
      return null;
    }
  }

  /// Authenticate user with email and password
  bool authenticate(String email, String password) {
    final user = getUserByEmail(email);
    return user != null && user.isActive && user.password == password;
  }

  /// Authenticate and return user object (for convenience)
  User? authenticateUser(String email, String password) {
    if (authenticate(email, password)) {
      return getUserByEmail(email);
    }
    return null;
  }

  /// Verify PIN (if set)
  bool verifyPin(String userId, String pin) {
    final user = _users[userId];
    return user != null && user.pin == pin;
  }

  /// Reactivate a soft-deleted user
  Future<bool> reactivateUser(
    String userId, {
    bool queueCloudSync = true,
  }) async {
    if (!_users.containsKey(userId)) {
      return false;
    }
    final user = _users[userId]!;
    _users[userId] = user.copyWith(isActive: true);
    await _saveToPreferences();
    notifyListeners();
    if (queueCloudSync) {
      _queueCloudSync();
    }
    return true;
  }

  /// Get users by role
  List<User> getUsersByRole(UserRole role) {
    return _users.values.where((u) => u.role == role && u.isActive).toList();
  }

  /// Get users by role, including inactive users
  List<User> getUsersByRoleIncludingInactive(UserRole role) {
    return _users.values.where((u) => u.role == role).toList();
  }

  /// Returns true if the given user should be treated as having owner-level privileges.
  /// Managers get owner-level privileges when the selected package is Premium or Enterprise.
  bool hasOwnerPrivileges(User user) {
    if (user.role == UserRole.owner) return true;
    if (user.role == UserRole.manager) {
      try {
        final pkgSvc = GetIt.I<PackageService>();
        final type = pkgSvc.selectedPackage?.type;
        return type == PackageType.premium || type == PackageType.enterprise;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Return active users who have owner-level privileges (owner + manager on premium/enterprise)
  List<User> getUsersWithOwnerPrivileges() {
    return _users.values
        .where((u) => u.isActive && hasOwnerPrivileges(u))
        .toList();
  }

  /// Delete user by email (hard delete)
  Future<bool> deleteUserByEmail(String email) async {
    try {
      final user = getUserByEmail(email);
      if (user != null) {
        return await deleteUserPermanently(user.id);
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting user by email: $e');
      return false;
    }
  }

  /// Clear all users from the system
  Future<void> clearAllUsers({bool queueCloudSync = true}) async {
    _users.clear();
    await _saveToPreferences();
    notifyListeners();
    if (queueCloudSync) {
      _queueCloudSync();
    }
  }
}
