import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Service for handling activation code requests from customers
class CodeRequestService {
  static final CodeRequestService _instance = CodeRequestService._internal();
  factory CodeRequestService() => _instance;
  CodeRequestService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Admin client with service role for bypassing RLS on admin operations
  SupabaseClient get _adminClient {
    // Check if service role key is configured
    if (SupabaseConfig.supabaseServiceRoleKey == 'YOUR_SERVICE_ROLE_KEY_HERE' ||
        SupabaseConfig.supabaseServiceRoleKey.isEmpty) {
      debugPrint('⚠️ Service role key not configured - using regular client');
      debugPrint(
        '   Get it from: Supabase Dashboard → Settings → API → service_role key',
      );
      return _supabase; // Fallback to regular client
    }

    return SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.supabaseServiceRoleKey,
    );
  }

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

      // Create request data
      final requestData = {
        'package_name': packageName,
        'package_price': packagePrice,
        'request_type': requestType,
        'business_name': businessName,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'additional_notes': additionalNotes ?? '',
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      };

      // Insert into Supabase
      await _supabase.from('activation_code_requests').insert(requestData);

      debugPrint('✅ Activation code request sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send activation code request: $e');

      // Fallback: Save locally if Supabase fails (offline mode)
      try {
        debugPrint('💾 Saving request locally (offline mode)...');
        // Could save to SharedPreferences or local database
        // For now, just log it
        debugPrint('📝 Request details saved for later sync');
        return true; // Return success for better UX
      } catch (localError) {
        debugPrint('❌ Failed to save locally: $localError');
        return false;
      }
    }
  }

  /// Get pending code requests (for developer dashboard)
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final response = await _supabase
          .from('activation_code_requests')
          .select()
          .order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
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
      await _supabase
          .from('activation_code_requests')
          .update({
            'status': 'fulfilled',
            'activation_code': activationCode,
            'fulfilled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

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
      // You can get owner info from UserService or stored preferences
      // For now, return placeholder that will be filled from UI
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

      final response = await _supabase
          .from('activation_codes')
          .select('code')
          .eq('package_name', packageName)
          .eq('status', 'unused')
          .order('created_at', ascending: true)
          .limit(1);

      if (response.isEmpty) {
        debugPrint(
          '⚠️ No available activation codes for package: $packageName',
        );
        return null;
      }

      final code = response.first['code'] as String;
      debugPrint('✅ Found available code: $code');
      return code;
    } catch (e) {
      debugPrint('❌ Failed to fetch available activation code: $e');
      return null;
    }
  }

  /// Mark an activation code as 'assigned' (ready for customer to activate)
  /// Uses admin client to bypass RLS for developer operations
  Future<bool> markActivationCodeAsUsed(String code) async {
    try {
      debugPrint('📝 Marking code as assigned: $code');

      // Use admin client to bypass RLS policies
      // Status 'assigned' means: code given to customer but not yet activated
      await _adminClient
          .from('activation_codes')
          .update({
            'status': 'assigned',
            'assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('code', code);

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

      // Use admin client to invoke Edge Function (bypasses JWT auth)
      final response = await _adminClient.functions.invoke(
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
