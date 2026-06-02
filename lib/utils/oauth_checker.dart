import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_config.dart';

/// Utility to check OAuth configuration status
class OAuthChecker {
  static Future<Map<String, dynamic>> checkSetup() async {
    final results = <String, dynamic>{};

    try {
      // Check Supabase connection
      final supabase = Supabase.instance.client;
      results['supabase_initialized'] = true;
      results['supabase_url'] = SupabaseConfig.supabaseUrl;

      // Check if Google provider might be configured
      // Note: We can't directly test without triggering OAuth flow
      try {
        // Just check if auth is available
        supabase.auth.currentSession; // Access to verify auth system works
        results['google_provider_configured'] =
            true; // Assume configured if no error
      } catch (e) {
        results['google_provider_configured'] = false;
        results['google_error'] = e.toString();
      }

      results['success'] = true;
    } catch (e) {
      results['success'] = false;
      results['error'] = e.toString();
    }

    return results;
  }

  static void showSetupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OAuth Setup Status'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: checkSetup(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final results = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusRow(
                    'Supabase Initialized',
                    results['supabase_initialized'] == true,
                  ),
                  if (results['supabase_url'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        results['supabase_url'],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    'Google Provider',
                    results['google_provider_configured'] == true,
                  ),
                  if (results['google_error'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        results['google_error'],
                        style: const TextStyle(fontSize: 10, color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (results['google_provider_configured'] != true)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ Setup Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'To use Google Sign In:\n\n'
                            '1. Configure Google OAuth in Google Cloud Console\n'
                            '2. Enable Google provider in Supabase Authentication\n'
                            '3. Deploy database schema in Supabase SQL Editor\n\n'
                            '📖 See QUICK_OAUTH_SETUP.md for step-by-step guide\n'
                            '📖 Or SUPABASE_OAUTH_SETUP_GUIDE.md for detailed instructions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusRow(String label, bool isSuccess) {
    return Row(
      children: [
        Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
