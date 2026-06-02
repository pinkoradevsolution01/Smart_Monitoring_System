import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/license_service.dart';
import '../../services/package_service.dart';

/// Quick test screen to check and manipulate trial status
/// Access via Developer Dashboard or add a route
class LicenseTestScreen extends StatefulWidget {
  const LicenseTestScreen({super.key});

  @override
  State<LicenseTestScreen> createState() => _LicenseTestScreenState();
}

class _LicenseTestScreenState extends State<LicenseTestScreen> {
  String _status = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final licenseService = GetIt.I<LicenseService>();
    final prefs = await SharedPreferences.getInstance();

    final mode = prefs.getString('subscription_mode');
    final expiresStr = prefs.getString('trial_expires');
    final activationCode = prefs.getString('activation_code');
    final isActivated = prefs.getBool('activation_status') ?? false;

    DateTime? expires;
    if (expiresStr != null) {
      expires = DateTime.tryParse(expiresStr);
    }

    final now = DateTime.now();
    String statusText = '=== LICENSE STATUS ===\n\n';
    statusText += 'Subscription Mode: ${mode ?? 'Not Set'}\n';
    statusText += 'Trial Expires: ${expires?.toLocal() ?? 'N/A'}\n';
    statusText += 'Is Activated: $isActivated\n';
    statusText += 'Activation Code: ${activationCode ?? 'None'}\n\n';
    statusText += '=== SERVICE STATE ===\n\n';
    statusText += 'Is Locked: ${licenseService.isLocked}\n';
    statusText += 'Is Activated: ${licenseService.isActivated}\n\n';
    statusText += '=== TIME CHECK ===\n\n';
    statusText += 'Current Time: ${now.toLocal()}\n';

    if (expires != null) {
      final diff = expires.difference(now);
      if (diff.isNegative) {
        statusText += 'Status: EXPIRED ${diff.abs().inMinutes} minutes ago\n';
      } else {
        statusText += 'Status: Active (${diff.inMinutes} minutes remaining)\n';
      }
    }

    setState(() => _status = statusText);
  }

  Future<void> _expireNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'trial_expires',
      DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
    );

    // Force immediate license check
    final licenseService = GetIt.I<LicenseService>();
    await licenseService.forceCheck();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Trial expired! System will lock within 30 seconds or click "Force Check Now".',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );

    await _loadStatus();
  }

  Future<void> _forceCheckNow() async {
    final licenseService = GetIt.I<LicenseService>();
    await licenseService.forceCheck();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('License check completed!'),
        backgroundColor: Colors.blue,
      ),
    );

    await _loadStatus();
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('subscription_mode');
    await prefs.remove('trial_expires');
    await prefs.remove('trial_starts');
    await prefs.remove('subscription_package');
    await prefs.remove('activation_code');
    await prefs.remove('activation_status');
    await prefs.remove('activation_date');

    // Reset package service
    final packageService = GetIt.I<PackageService>();
    await packageService.resetSetup();

    // Refresh license service
    final licenseService = GetIt.I<LicenseService>();
    await licenseService.refreshStatus();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All trial/activation data cleared! Restart app.'),
        backgroundColor: Colors.green,
      ),
    );

    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Test Tools'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  _status,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _loadStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _expireNow,
              icon: const Icon(Icons.timer_off),
              label: const Text('Expire Trial NOW (Test)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _forceCheckNow,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Force Check Now (Trigger Lock)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _clearAllData,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear All Trial Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Click "Expire Trial NOW" to set expiry to past\n'
                      '2. Click "Force Check Now" to trigger immediate lock\n'
                      '3. System will auto-lock and navigate to locked screen\n'
                      '4. Or wait up to 30 seconds for auto-check\n\n'
                      'Valid Test Activation Codes:\n'
                      '• TEST1234567890ABCDEF\n'
                      '• DEV20240209TESTCODE1\n'
                      '• ABCDEFGHIJ0123456789\n\n'
                      'Use any of these codes to unlock.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
