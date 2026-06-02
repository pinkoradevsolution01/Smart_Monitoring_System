import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/admin_account.dart';
import '../models/user.dart';
import 'user_service.dart';
import 'package:get_it/get_it.dart';

/// Service to manage admin account details.
/// Persists to SharedPreferences for persistent storage across app sessions.
class AdminService extends ChangeNotifier {
  static final AdminService _instance = AdminService._internal();

  factory AdminService() {
    return _instance;
  }

  AdminService._internal() {
    _initializeDefaults();
  }

  late AdminAccount _adminAccount;
  late String _generatedEmailOtp;
  late String _generatedSmsCode;
  static const String _adminAccountKey = 'admin_account';

  AdminAccount get adminAccount => _adminAccount;

  /// Initialize and load admin account from SharedPreferences if exists
  void _initializeDefaults() async {
    _generatedEmailOtp = '';
    _generatedSmsCode = '';

    // Try to load saved admin account from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedAccountJson = prefs.getString(_adminAccountKey);

    if (savedAccountJson != null && savedAccountJson.isNotEmpty) {
      try {
        // Load existing admin account
        final json = jsonDecode(savedAccountJson) as Map<String, dynamic>;
        _adminAccount = AdminAccount.fromMap(json);
        debugPrint(
          'Admin account loaded from SharedPreferences: ${_adminAccount.email}',
        );
      } catch (e) {
        debugPrint('Error loading admin account: $e');
        // If error, create empty account
        _adminAccount = AdminAccount(
          id: '',
          name: '',
          email: '',
          password: '',
          contactNumber: '',
          createdAt: DateTime.now(),
        );
      }
    } else {
      // No saved account, create empty account for first-time setup
      _adminAccount = AdminAccount(
        id: '',
        name: '',
        email: '',
        password: '',
        contactNumber: '',
        createdAt: DateTime.now(),
      );
      debugPrint('No saved admin account found. Ready for account creation.');
    }

    notifyListeners();
  }

  /// Save admin account to SharedPreferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _adminAccount.toMap();
      await prefs.setString(_adminAccountKey, jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving admin account: $e');
    }
  }

  /// Update admin account details
  Future<bool> updateAdminAccount(AdminAccount account) async {
    _adminAccount = account.copyWith(lastModified: DateTime.now());
    await _saveToPreferences();
    notifyListeners();
    try {
      // NOTE: Admin accounts should NOT be recorded as subscribers
      // Only Google-authenticated owner accounts are subscribers
      // ensure subscriber record reflects admin details
      // await SubscriberService().addSubscriberFromUser(
      //   id: _adminAccount.id,
      //   name: _adminAccount.name,
      //   email: _adminAccount.email,
      //   contact: _adminAccount.contactNumber,
      // );
    } catch (e) {
      debugPrint('Failed to sync admin to subscriber: $e');
    }
    return true;
  }

  /// Check if password matches any owner password
  /// Returns true if password conflicts with an owner's password
  Future<bool> isPasswordUsedByOwner(String password) async {
    try {
      final userService = GetIt.I.get<UserService>();
      final owners = userService.getUsersByRole(UserRole.owner);
      
      for (var owner in owners) {
        if (owner.password == password) {
          return true; // Password already used by an owner
        }
      }
      return false; // Password is unique, not used by any owner
    } catch (e) {
      debugPrint('Error checking password uniqueness: $e');
      return false; // If service not available, allow password
    }
  }

  /// Reset password (typically requires SMS verification to contact number)
  /// Returns false if password conflicts with owner passwords
  Future<bool> resetPassword(String newPassword) async {
    if (newPassword.length < 6) {
      return false;
    }
    
    // Check if password is same as any owner's password
    final conflictsWithOwner = await isPasswordUsedByOwner(newPassword);
    if (conflictsWithOwner) {
      debugPrint('Admin password cannot be same as owner password');
      return false;
    }
    
    _adminAccount = _adminAccount.copyWith(
      password: newPassword,
      lastModified: DateTime.now(),
    );
    await _saveToPreferences();
    notifyListeners();
    return true;
  }

  /// Verify contact number (simulated - in real app would send SMS)
  Future<bool> sendSmsCode(String phoneNumber) async {
    // Validate phone number (supports Philippine +63 format and others)
    if (phoneNumber.isEmpty) {
      return false;
    }

    // Validate basic phone format (should start with + and have digits)
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      return false;
    }

    // Generate a random 4-digit SMS code
    _generatedSmsCode = (1000 + DateTime.now().microsecond % 9000).toString();

    // Store the contact number
    _adminAccount = _adminAccount.copyWith(contactNumber: phoneNumber);
    notifyListeners();

    // In real app, send code via SMS using Twilio or similar service
    // For demo, just return success
    return true;
  }

  /// Verify SMS code (simulated)
  Future<bool> verifySmsCode(String code) async {
    // Verify the SMS code matches the generated one
    if (_generatedSmsCode.isEmpty) {
      return false;
    }

    // Check if entered code matches generated code
    if (code == _generatedSmsCode) {
      _generatedSmsCode = ''; // Clear after successful verification
      return true;
    }

    return false;
  }

  /// Send email OTP for password recovery
  Future<bool> sendEmailOtp(String email) async {
    // Verify email matches admin account
    if (email != _adminAccount.email) {
      return false;
    }

    // Generate a random 6-digit OTP for email
    _generatedEmailOtp = (100000 + DateTime.now().microsecond % 900000)
        .toString();

    // In real app, send OTP via email service (SendGrid, Gmail API, etc.)
    // For demo, just return success
    return true;
  }

  /// Verify email OTP
  Future<bool> verifyEmailOtp(String otp) async {
    if (_generatedEmailOtp.isEmpty) {
      return false;
    }

    // Check if entered OTP matches generated one
    if (otp == _generatedEmailOtp) {
      _generatedEmailOtp = ''; // Clear after successful verification
      return true;
    }

    return false;
  }

  /// Authenticate admin with email and password
  bool authenticate(String email, String password) {
    if (_adminAccount.email.isEmpty || _adminAccount.password.isEmpty) {
      return false;
    }
    return _adminAccount.email == email && _adminAccount.password == password;
  }

  /// Check if email belongs to admin account
  /// Uses local storage only (Firebase disabled for Windows)
  Future<bool> isAdminAsync(String email) async {
    // Check local admin account only
    if (_adminAccount.email.isEmpty) {
      return false;
    }
    return _adminAccount.email.toLowerCase() == email.toLowerCase();
  }

  /// Synchronous version - checks only local admin
  bool isAdmin(String email) {
    if (_adminAccount.email.isEmpty) {
      return false;
    }
    return _adminAccount.email.toLowerCase() == email.toLowerCase();
  }

  /// Authenticate with contact number and password
  bool authenticateWithContactNumber(String contactNumber, String password) {
    if (_adminAccount.contactNumber == null ||
        _adminAccount.contactNumber!.isEmpty ||
        _adminAccount.password.isEmpty) {
      return false;
    }
    return _adminAccount.contactNumber == contactNumber &&
        _adminAccount.password == password;
  }

  /// Check if admin account exists
  bool get hasAdminAccount {
    return _adminAccount.email.isNotEmpty && _adminAccount.password.isNotEmpty;
  }

  /// Create new admin account (first-time setup)
  Future<bool> createAdminAccount({
    required String name,
    required String email,
    required String password,
    required String contactNumber,
  }) async {
    // Validate inputs
    if (name.isEmpty ||
        email.isEmpty ||
        password.length < 6 ||
        contactNumber.isEmpty) {
      return false;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return false;
    }

    // Validate phone number format (should start with + and have digits)
    if (!contactNumber.startsWith('+') || contactNumber.length < 10) {
      return false;
    }

    // Check if password is same as any owner's password
    final conflictsWithOwner = await isPasswordUsedByOwner(password);
    if (conflictsWithOwner) {
      debugPrint('Admin password cannot be same as owner password');
      return false;
    }

    // Create new admin account
    _adminAccount = AdminAccount(
      id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      password: password,
      contactNumber: contactNumber,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
    );

    await _saveToPreferences();
    try {
      // NOTE: Admin accounts should NOT be recorded as subscribers
      // Only Google-authenticated owner accounts are subscribers
      // await SubscriberService().addSubscriberFromUser(
      //   id: _adminAccount.id,
      //   name: _adminAccount.name,
      //   email: _adminAccount.email,
      //   contact: _adminAccount.contactNumber,
      // );
    } catch (e) {
      debugPrint('Failed to save admin as subscriber: $e');
    }
    notifyListeners();
    return true;
  }

  /// Check if account creation is allowed (no existing admin)
  bool get canCreateAccount {
    return _adminAccount.email.isEmpty || _adminAccount.password.isEmpty;
  }

  /// Delete admin account and reset to allow new account creation
  Future<bool> deleteAdminAccount() async {
    try {
      // Reset account to empty state
      _adminAccount = AdminAccount(
        id: '',
        name: '',
        email: '',
        password: '',
        contactNumber: '',
        createdAt: DateTime.now(),
      );

      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_adminAccountKey);

      // Reset OTP codes
      _generatedEmailOtp = '';
      _generatedSmsCode = '';

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting admin account: $e');
      return false;
    }
  }
}
