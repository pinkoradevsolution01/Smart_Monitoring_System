import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../services/license_service.dart';

/// Screen for developer/admin to revoke activation codes
/// Useful for handling Terms of Service violations, code sharing, fraud, or refunds
class CodeRevocationScreen extends StatefulWidget {
  const CodeRevocationScreen({super.key});

  @override
  State<CodeRevocationScreen> createState() => _CodeRevocationScreenState();
}

class _CodeRevocationScreenState extends State<CodeRevocationScreen> {
  final _licenseService = GetIt.I<LicenseService>();
  List<Map<String, dynamic>> _usedCodes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsedCodes();
  }

  Future<void> _loadUsedCodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final codes = await _licenseService.getUsedActivationCodes();
      setState(() {
        _usedCodes = codes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading codes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeCode(String code) async {
    // Show reason dialog
    final reason = await _showReasonDialog();
    if (reason == null || reason.isEmpty) {
      return; // User cancelled
    }

    // Confirm revocation
    final confirmed = await _showConfirmDialog(code, reason);
    if (!confirmed) {
      return;
    }

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    // Revoke the code
    final result = await _licenseService.revokeActivationCode(code, reason);

    // Hide loading
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show result
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Reload codes if revocation was successful
    if (result.success) {
      await _loadUsedCodes();
    }
  }

  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you revoking this code?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Terms of Service violation, fraud, refund',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _showConfirmDialog(String code, String reason) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Revocation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️ This action cannot be undone!\n'),
            Text('Code: $code'),
            Text('Reason: $reason'),
            const SizedBox(height: 12),
            const Text(
              'This will:\n'
              '• Mark the code as revoked\n'
              '• Cancel any active subscriptions\n'
              '• Prevent future use of this code',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke Code'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚫 Code Revocation'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadUsedCodes,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUsedCodes,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_usedCodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'No used activation codes found',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'All codes are either unused or already revoked',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _usedCodes.length,
            itemBuilder: (context, index) => _buildCodeCard(_usedCodes[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[850],
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_usedCodes.length} used code(s) • Tap to revoke',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(Map<String, dynamic> codeData) {
    final code = codeData['code'] ?? 'N/A';
    final packageName = codeData['package_name'] ?? 'Unknown';
    final deviceName = codeData['device_name'] ?? 'Unknown Device';
    final usedAt = codeData['used_at'] != null
        ? DateTime.parse(codeData['used_at'])
        : null;
    final subscriptionStatus = codeData['subscription_status'] ?? 'unknown';
    final expiresAt = codeData['subscription_expires_at'] != null
        ? DateTime.parse(codeData['subscription_expires_at'])
        : null;

    // Determine status color
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (subscriptionStatus) {
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Active';
        break;
      case 'expired':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        statusText = 'Expired';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _revokeCode(code),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Code and Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Package Info
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    packageName,
                    style: const TextStyle(color: Colors.amber, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.devices, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deviceName,
                      style: const TextStyle(color: Colors.blue, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dates
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    usedAt != null
                        ? 'Used: ${DateFormat('MMM dd, yyyy').format(usedAt.toLocal())}'
                        : 'Used: Unknown',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.event_available,
                      size: 14,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Expires: ${DateFormat('MMM dd, yyyy').format(expiresAt.toLocal())}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Action hint
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.delete_forever, size: 16, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    'Tap to revoke',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
