import 'package:flutter/material.dart';
import '../../services/backend_api_service.dart';

/// Quick test screen to verify the Droplet backend API and MySQL connection.
class BackendConnectionTest extends StatefulWidget {
  const BackendConnectionTest({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<BackendConnectionTest> createState() => _BackendConnectionTestState();
}

class _BackendConnectionTestState extends State<BackendConnectionTest> {
  String _status = 'Ready to test...';
  bool _isTesting = false;
  Color _statusColor = Colors.grey;
  final List<({bool success, String message})> _testResults = [];
  late final ApiClient _api = widget.apiClient ?? ApiClient();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend API & Database Test'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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
                      final isError = !result.success;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isError ? Icons.cancel : Icons.check_circle,
                              color: isError ? Colors.red : Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.message,
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

    var phase = 'backend';
    try {
      // Test 1: Check the backend API itself.
      setState(() => _status = 'Checking backend API...');
      final health = await _api.getJson('health');
      if (health is! Map<String, dynamic> || health['status'] != 'ok') {
        throw Exception('Backend health check returned an invalid response');
      }
      _addResult(true, 'Backend API is reachable');
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      // Test 2: Verify the backend can query MySQL.
      phase = 'database';
      setState(() => _status = 'Checking MySQL database connection...');
      final database = await _api.getJson('health/db');
      if (database is! Map<String, dynamic> || database['status'] != 'ok') {
        throw Exception('Database health check returned an invalid response');
      }
      _addResult(true, 'MySQL database connection is healthy');
      if (database['database'] != null) {
        _addResult(true, 'Database: ${database['database']}');
      }
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      // Test 3: Developer-only operational status. This endpoint exposes
      // aggregate platform telemetry only; it never returns tenant records.
      phase = 'developer';
      setState(() => _status = 'Loading system health and sync status...');
      final operational = await _api.get('developer/system-health');
      if (!mounted) return;
      final data = operational['data'];
      if (data is! Map) {
        throw Exception('System health response was incomplete');
      }
      final backend = data['backend'] is Map
          ? data['backend'] as Map
          : const {};
      final sync = data['sync'] is Map ? data['sync'] as Map : const {};
      final email = data['email'] is Map ? data['email'] as Map : const {};
      final recentErrors = data['recentErrors'] is List
          ? data['recentErrors'] as List
          : const [];
      _addResult(true, 'API latency: ${backend['latencyMs'] ?? 'unknown'} ms');
      _addResult(
        true,
        'Last successful sync: ${sync['lastSyncAt'] ?? 'No sync recorded'}',
      );
      _addResult(
        (sync['failedLast24Hours'] as num? ?? 0) == 0,
        'Failed syncs (24h): ${sync['failedLast24Hours'] ?? 0}',
      );
      _addResult(
        email['configured'] == true,
        'Owner email delivery: ${email['configured'] == true ? 'configured' : 'not configured'} · sent ${email['sentLast24Hours'] ?? 0} · failed ${email['failedLast24Hours'] ?? 0}',
      );
      _addResult(
        recentErrors.isEmpty,
        'Recent operational errors: ${recentErrors.length}',
      );

      // Final result
      final failedTests = _testResults.where((r) => !r.success).length;
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
      if (!mounted) return;
      if (phase == 'developer' &&
          e is ApiException &&
          (e.statusCode == 401 || e.statusCode == 403)) {
        setState(() {
          _status =
              'Backend and database are healthy; Developer access is required.';
          _statusColor = Colors.orange;
        });
        _addResult(
          false,
          e.statusCode == 401
              ? 'Developer session is missing or expired. Sign in again as Developer.'
              : 'The current session is not authorized for Developer system health. Sign in as Developer.',
        );
        return;
      }
      setState(() {
        _status = phase == 'developer'
            ? 'System health could not be loaded.'
            : phase == 'database'
            ? 'Database health check failed.'
            : 'Backend connection check failed.';
        _statusColor = Colors.red;
      });
      _addResult(false, safeApiError(e));
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _addResult(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _testResults.add((success: success, message: message));
    });
  }
}
