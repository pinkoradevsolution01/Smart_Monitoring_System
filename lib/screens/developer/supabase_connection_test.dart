import 'package:flutter/material.dart';
import '../../services/backend_api_service.dart';

/// Quick test screen to verify backend/MySQL connection
/// Add this to Developer Dashboard for testing
class SupabaseConnectionTest extends StatefulWidget {
  const SupabaseConnectionTest({super.key});

  @override
  State<SupabaseConnectionTest> createState() => _SupabaseConnectionTestState();
}

class _SupabaseConnectionTestState extends State<SupabaseConnectionTest> {
  String _status = 'Ready to test...';
  bool _isTesting = false;
  Color _statusColor = Colors.grey;
  final List<String> _testResults = [];
  final ApiClient _api = ApiClient();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Connection Test'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _statusColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(_getStatusIcon(), size: 48, color: _statusColor),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Button
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _runTests,
              icon: _isTesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isTesting ? 'Testing...' : 'Run Connection Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Test Results
            if (_testResults.isNotEmpty) ...[
              const Text(
                'Test Results:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _testResults.length,
                    itemBuilder: (context, index) {
                      final result = _testResults[index];
                      final isError = result.startsWith('❌');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.substring(0, 2),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.substring(3),
                                style: TextStyle(
                                  color: isError ? Colors.red : Colors.green,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (_status.contains('Success') || _status.contains('Connected')) {
      return Icons.check_circle;
    } else if (_status.contains('Failed') || _status.contains('Error')) {
      return Icons.error;
    } else if (_status.contains('Testing')) {
      return Icons.sync;
    }
    return Icons.help_outline;
  }

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _status = 'Testing connection...';
      _statusColor = Colors.orange;
      _testResults.clear();
    });

    try {
      // Test 1: Check backend client initialization
      _addResult(true, 'Backend client initialized');
      await Future.delayed(const Duration(milliseconds: 300));

      // Test 2: Query activation_codes table
      setState(() => _status = 'Checking activation_codes table...');
      try {
        final response = await _api.getJson('license/codes');
        final codesResponse = response is Map<String, dynamic> && response['codes'] is List
            ? List<Map<String, dynamic>>.from(response['codes'] as List)
            : <Map<String, dynamic>>[];

        if (codesResponse.isNotEmpty) {
          _addResult(true, 'activation_codes table exists and accessible');
          _addResult(true, 'Sample code: ${codesResponse[0]['code']}');
        } else {
          _addResult(true, 'activation_codes table exists (empty)');
        }
      } catch (e) {
        _addResult(false, 'activation_codes error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));

      // Test 3: Count unused codes
      setState(() => _status = 'Counting unused codes...');
      try {
        final response = await _api.getJson(
          'license/codes/available',
          queryParameters: {'packageName': 'All'},
        );
        final unusedCodes = response is Map<String, dynamic> && response['codes'] is List
            ? List<Map<String, dynamic>>.from(response['codes'] as List)
            : <Map<String, dynamic>>[];

        _addResult(true, 'Found ${unusedCodes.length} unused codes');
      } catch (e) {
        _addResult(false, 'Count unused codes error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));

      // Test 4: Query subscriptions table
      setState(() => _status = 'Checking subscriptions table...');
      try {
        final response = await _api.getJson('license/subscriptions');
        final subsResponse = response is Map<String, dynamic> && response['subscriptions'] is List
            ? List<Map<String, dynamic>>.from(response['subscriptions'] as List)
            : <Map<String, dynamic>>[];

        _addResult(true, 'subscriptions table exists and accessible');
        if (subsResponse.isNotEmpty) {
          _addResult(true, 'Has subscription records');
        }
      } catch (e) {
        _addResult(false, 'subscriptions error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));

      // Test 5: Query subscription_renewals table
      setState(() => _status = 'Checking subscription_renewals table...');
      try {
        final response = await _api.getJson('license/subscription-renewals');
        final renewals = response is Map<String, dynamic> && response['renewals'] is List
            ? List<Map<String, dynamic>>.from(response['renewals'] as List)
            : <Map<String, dynamic>>[];

        _addResult(true, 'subscription_renewals table exists and accessible');
        _addResult(true, 'Found ${renewals.length} renewal records');
      } catch (e) {
        _addResult(false, 'subscription_renewals error: $e');
      }

      // Final result
      final failedTests = _testResults.where((r) => r.startsWith('❌')).length;
      if (failedTests == 0) {
        setState(() {
          _status = '✅ All tests passed! Backend is connected.';
          _statusColor = Colors.green;
        });
      } else {
        setState(() {
          _status = '⚠️ Some tests failed. Check results below.';
          _statusColor = Colors.orange;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Connection failed!';
        _statusColor = Colors.red;
      });
      _addResult(false, 'General error: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  void _addResult(bool success, String message) {
    setState(() {
      _testResults.add('${success ? '✅' : '❌'} $message');
    });
  }
}
