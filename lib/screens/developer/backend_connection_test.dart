import 'package:flutter/material.dart';
import '../../services/backend_api_service.dart';

/// Quick test screen to verify the Droplet backend API and MySQL connection.
class BackendConnectionTest extends StatefulWidget {
  const BackendConnectionTest({super.key});

  @override
  State<BackendConnectionTest> createState() => _BackendConnectionTestState();
}

class _BackendConnectionTestState extends State<BackendConnectionTest> {
  String _status = 'Ready to test...';
  bool _isTesting = false;
  Color _statusColor = Colors.grey;
  final List<String> _testResults = [];
  final ApiClient _api = ApiClient();

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
      // Test 1: Check the backend API itself.
      setState(() => _status = 'Checking backend API...');
      final health = await _api.getJson('health');
      if (health is! Map<String, dynamic> || health['status'] != 'ok') {
        throw Exception('Backend health check returned an invalid response');
      }
      _addResult(true, 'Backend API is reachable');
      await Future.delayed(const Duration(milliseconds: 300));

      // Test 2: Verify the backend can query MySQL.
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
