import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_api_service.dart';

/// Service for handling activation code requests from customers
class CodeRequestService {
  static final CodeRequestService _instance = CodeRequestService._internal();
  factory CodeRequestService() => _instance;
  CodeRequestService._internal();

  final ApiClient _api = ApiClient();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Submit activation code request to developer
  /// Returns true if request was successfully sent
  Future<bool> requestActivationCode({
    required String packageName,
    required String packagePrice,
    required String requestType, // 'monthly' or 'trial'
    required String businessName,
    required String contactEmail,
    required String contactPhone,
    String? additionalNotes,
  }) async {
    try {
      debugPrint('📤 Sending activation code request...');
      debugPrint('   Package: $packageName ($packagePrice)');
      debugPrint('   Type: $requestType');
      debugPrint('   Business: $businessName');
      debugPrint('   Contact: $contactEmail');

      final requestData = {
        'business_name': businessName,
        'package_name': packageName,
        'package_price': packagePrice,
        'request_type': requestType,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'additional_notes': additionalNotes ?? '',
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      };

      final response = await _api.postJson('license/requests', body: requestData);
      if (response is Map<String, dynamic> && response['success'] == false) {
        throw Exception(response['message']?.toString() ?? 'Request failed');
      }

      debugPrint('✅ Activation code request sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send activation code request: $e');
      return false;
    }
  }

  /// Get pending code requests (for developer dashboard)
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final response = await _api.getJson(
        'license/requests',
        queryParameters: {'status': 'pending'},
      );

      if (response is Map<String, dynamic> && response['requests'] is List) {
        return List<Map<String, dynamic>>.from(response['requests'] as List);
      }

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }

      return [];
    } catch (e) {
      debugPrint('❌ Failed to fetch pending requests: $e');
      return [];
    }
  }

  /// Mark request as fulfilled
  Future<bool> markRequestFulfilled(
    String requestId,
    String activationCode,
  ) async {
    try {
      await _api.patchJson(
        'license/requests/$requestId',
        body: {
          'status': 'fulfilled',
          'activation_code': activationCode,
          'fulfilled_at': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('✅ Request marked as fulfilled');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update request status: $e');
      return false;
    }
  }

  /// Get owner information for the request
  Future<Map<String, String>> getOwnerInfo() async {
    try {
      return {'businessName': '', 'contactEmail': '', 'contactPhone': ''};
    } catch (e) {
      debugPrint('❌ Failed to get owner info: $e');
      return {'businessName': '', 'contactEmail': '', 'contactPhone': ''};
    }
  }

  /// Get the latest available activation code for a specific package
  /// Returns the code if found, null if no codes available
  Future<String?> getAvailableActivationCode(String packageName) async {
    try {
      debugPrint('🔍 Searching for available code for package: $packageName');

      final response = await _api.getJson(
        'license/codes/available',
        queryParameters: {'packageName': packageName},
      );

      final codes = response is Map<String, dynamic> && response['codes'] is List
          ? List<Map<String, dynamic>>.from(response['codes'] as List)
          : const <Map<String, dynamic>>[];

      if (codes.isEmpty) {
        debugPrint('⚠️ No available activation codes for package: $packageName');
        return null;
      }

      final code = codes.first['code'] as String?;
      debugPrint('✅ Found available code: $code');
      return code;
    } catch (e) {
      debugPrint('❌ Failed to fetch available activation code: $e');
      return null;
    }
  }

  /// Mark an activation code as 'assigned' (ready for customer to activate)
  Future<bool> markActivationCodeAsUsed(String code) async {
    try {
      debugPrint('📝 Marking code as assigned: $code');
      await _api.postJson('license/codes/$code/assign');
      debugPrint('✅ Code marked as assigned (ready for customer activation)');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to mark code as assigned: $e');
      return false;
    }
  }

  /// Send activation code email to customer
  /// Returns true if email sent successfully, false otherwise
  /// Note: Request is still fulfilled even if email fails
  Future<bool> sendActivationEmail({
    required String customerEmail,
    required String businessName,
    required String packageName,
    required String activationCode,
  }) async {
    try {
      debugPrint('📧 Sending activation email to: $customerEmail');

      final response = await _supabase.functions.invoke(
        'send-activation-code',
        body: {
          'email': customerEmail,
          'code': activationCode,
          'business_name': businessName,
          'package_name': packageName,
        },
      );

      if (response.status == 200) {
        debugPrint('✅ Activation email sent successfully');
        return true;
      } else {
        debugPrint('⚠️ Email response status: ${response.status}');
        debugPrint('   Response: ${response.data}');
        return false;
      }
    } on FunctionException catch (fe) {
      if (fe.status == 404) {
        debugPrint('⚠️ Email function not deployed yet');
        debugPrint(
          '   To enable emails, run: supabase functions deploy send-activation-code',
        );
        debugPrint('   See: CUSTOMER_ACTIVATION_EMAIL_SETUP.md');
      } else {
        debugPrint('❌ Email function error (${fe.status}): ${fe.details}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to send activation email: $e');
      return false;
    }
  }
}
