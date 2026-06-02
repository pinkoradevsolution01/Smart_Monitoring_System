import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_config.dart';

class OtpService {
  static String get _sendUrl =>
      '${SupabaseConfig.supabaseFunctionsUrl}/send-otp';
  static String get _verifyUrl =>
      '${SupabaseConfig.supabaseFunctionsUrl}/verify-otp';

  static Future<bool> requestOtp(String email) async {
    try {
      final resp = await http.post(
        Uri.parse(_sendUrl),
        body: jsonEncode({'email': email}),
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
      );
      if (resp.statusCode == 200) return true;
      // Debug: print response body to help diagnose failures
      try {
        // ignore: avoid_print
        print('[OtpService] send-otp failed: ${resp.statusCode} ${resp.body}');
      } catch (_) {}
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[OtpService] requestOtp exception: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    final resp = await http.post(
      Uri.parse(_verifyUrl),
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      }),
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
      },
    );
    if (resp.statusCode == 200) return {'success': true};
    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'status': resp.statusCode, 'body': resp.body};
    }
  }
}
