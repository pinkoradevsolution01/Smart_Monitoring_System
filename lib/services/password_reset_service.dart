import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../models/user.dart' as user_model;
import 'supabase_config.dart';
import 'user_service.dart';

/// Service for handling password reset functionality for owner accounts
/// Sends reset emails via Supabase Edge Functions with Gmail SMTP
class PasswordResetService {
  static String get _sendResetUrl =>
      '${SupabaseConfig.supabaseFunctionsUrl}/send-password-reset';
  static String get _verifyResetUrl =>
      '${SupabaseConfig.supabaseFunctionsUrl}/verify-password-reset';

  /// Send password reset email to owner
  /// Returns the reset token on success, or null on failure
  static Future<String?> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('[PasswordReset] Sending reset email to: $email');

      final resp = await http
          .post(
            Uri.parse(_sendResetUrl),
            body: jsonEncode({'email': email}),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timeout - please check your internet connection',
              );
            },
          );

      debugPrint('[PasswordReset] Response status: ${resp.statusCode}');
      debugPrint('[PasswordReset] Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final success = data['success'] == true;
        final token = data['token'] as String?;

        if (success && token != null) {
          debugPrint('[PasswordReset] ✅ Reset email sent successfully');
          return token;
        } else {
          debugPrint('[PasswordReset] ❌ Unexpected response format');
          return null;
        }
      } else {
        // Try to parse error message
        try {
          final errorData = jsonDecode(resp.body) as Map<String, dynamic>;
          final errorMsg =
              errorData['error'] ?? errorData['message'] ?? 'Unknown error';
          debugPrint('[PasswordReset] ❌ Server error: $errorMsg');
        } catch (_) {
          debugPrint('[PasswordReset] ❌ Server error: ${resp.statusCode}');
        }
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('[PasswordReset] ❌ Exception: $e');
      debugPrint('[PasswordReset] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Verify reset token and update password in local database
  /// Returns true on success, false on failure
  static Future<Map<String, dynamic>> verifyTokenAndResetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      debugPrint('[PasswordReset] Verifying token and resetting password...');

      // First, verify the token with the Edge Function
      final resp = await http
          .post(
            Uri.parse(_verifyResetUrl),
            body: jsonEncode({'token': token, 'newPassword': newPassword}),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Request timeout - please check your internet connection',
              );
            },
          );

      debugPrint('[PasswordReset] Verify response status: ${resp.statusCode}');
      debugPrint('[PasswordReset] Verify response body: ${resp.body}');

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final success = data['success'] == true;

      if (!success) {
        final errorMsg =
            data['error'] ?? data['message'] ?? 'Token verification failed';
        debugPrint('[PasswordReset] ❌ Verification failed: $errorMsg');
        return {'success': false, 'error': errorMsg};
      }

      // Token is valid, get the email
      final email = data['email'] as String?;
      if (email == null) {
        return {'success': false, 'error': 'Invalid response from server'};
      }

      debugPrint('[PasswordReset] ✅ Token verified for email: $email');

      // Now update the password in the local database
      final userService = GetIt.I.get<UserService>();
      final owners = userService.getUsersByRole(user_model.UserRole.owner);
      final owner = owners.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('Owner account not found'),
      );

      // Update the password
      final updatedOwner = user_model.User(
        id: owner.id,
        name: owner.name,
        email: owner.email,
        password: newPassword, // In production, hash this password
        pin: owner.pin,
        role: owner.role,
        businessId: owner.businessId,
        createdAt: owner.createdAt,
        isActive: owner.isActive,
      );

      await userService.updateUser(updatedOwner);

      debugPrint('[PasswordReset] ✅ Password updated successfully in database');

      return {
        'success': true,
        'email': email,
        'message': 'Password reset successfully',
      };
    } catch (e, stackTrace) {
      debugPrint('[PasswordReset] ❌ Exception: $e');
      debugPrint('[PasswordReset] Stack trace: $stackTrace');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Quick method to check if an email belongs to an owner
  static Future<bool> isOwnerEmail(String email) async {
    try {
      final userService = GetIt.I.get<UserService>();
      final owners = userService.getUsersByRole(user_model.UserRole.owner);
      return owners.any((u) => u.email.toLowerCase() == email.toLowerCase());
    } catch (e) {
      debugPrint('[PasswordReset] Error checking owner email: $e');
      return false;
    }
  }
}
