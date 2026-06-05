import 'package:flutter/material.dart';
import '../services/backend_config.dart';

/// Utility to check auth configuration status
class OAuthChecker {
  static Future<Map<String, dynamic>> checkSetup() async {
    final results = <String, dynamic>{};

    try {
      results['backend_initialized'] = BackendConfig.useRestBackend;
      results['backend_url'] = BackendConfig.apiBaseUrl;
      results['google_provider_configured'] = BackendConfig.useRestBackend;
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
                    'Backend Initialized',
                    results['backend_initialized'] == true,
                  ),
                  if (results['backend_url'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        results['backend_url'],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    'Google Auth Enabled',
                    results['google_provider_configured'] == true,
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
                            '1. Configure Google OAuth credentials on the backend\n'
                            '2. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET\n'
                            '3. Start the Node.js backend before signing in\n\n'
                            '📖 See backend/README.md for setup steps',
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
