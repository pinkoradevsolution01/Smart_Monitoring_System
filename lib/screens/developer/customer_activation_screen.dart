import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/backend_api_service.dart';

class CustomerActivationScreen extends StatefulWidget {
  const CustomerActivationScreen({super.key});

  @override
  State<CustomerActivationScreen> createState() =>
      _CustomerActivationScreenState();
}

class _CustomerActivationScreenState extends State<CustomerActivationScreen> {
  List<Map<String, dynamic>> _unusedCodes = [];
  bool _isLoading = true;
  String _selectedPackage = 'All';
  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadUnusedCodes();
  }

  Future<void> _loadUnusedCodes() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.getJson(
        'license/codes/available',
        queryParameters: {
          'packageName': _selectedPackage,
        },
      );

      final codes = response is Map<String, dynamic> && response['codes'] is List
          ? List<Map<String, dynamic>>.from(response['codes'] as List)
          : <Map<String, dynamic>>[];

      setState(() {
        _unusedCodes = codes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading codes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyCodeForCustomer(String code, String packageName) {
    // Format message for customer
    final message =
        '''
    🎉 Smart POS Activation Code

    Package: $packageName
    Code: $code

    ⚠️ IMPORTANT: The 24-hour timer starts once this code is emailed to the subscriber.
    Enter it as soon as the customer is ready to activate.

    How to activate:
    1. Install Smart POS app
    2. Open app (will show "Payment Required")
    3. Tap "Enter Activation Code"
    4. Paste this code: $code
    5. Enjoy your 30-day subscription!

    ⏰ Code valid: 24 hours after email delivery
    📅 Subscription: 30 days after activation
    📱 Valid for: 1 device only
    Support: [Your Contact Info]
    ''';

    Clipboard.setData(ClipboardData(text: message));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '✅ Activation message copied!\nSend to customer via Messenger/Viber/SMS',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Color _getPackageColor(String package) {
    switch (package) {
      case 'Basic':
        return Colors.blue;
      case 'Standard':
        return Colors.orange;
      case 'Premium':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPackagePrice(String package) {
    switch (package) {
      case 'Basic':
        return '₱1,799/mo';
      case 'Standard':
        return '₱3,799/mo';
      case 'Premium':
        return '₱6,799/mo';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Activation Codes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUnusedCodes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⚠️ These codes do not start a 24-hour countdown until they are emailed.\nTap any code to copy → Send to customer.\nCustomer gets 24 hours after email delivery to activate.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          // Package filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'Package: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedPackage,
                  items: ['All', 'Basic', 'Standard', 'Premium']
                      .map(
                        (pkg) => DropdownMenuItem(value: pkg, child: Text(pkg)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPackage = value);
                      _loadUnusedCodes();
                    }
                  },
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_unusedCodes.length} available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Codes list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _unusedCodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No unused codes available',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate codes in Activation Code Generator',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _unusedCodes.length,
                    itemBuilder: (context, index) {
                      final codeData = _unusedCodes[index];
                      final packageName = codeData['package_name'] as String;
                      final code = codeData['code'] as String;
                      final packageColor = _getPackageColor(packageName);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _copyCodeForCustomer(code, packageName),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Package indicator
                                Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: packageColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Code details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: packageColor.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              packageName,
                                              style: TextStyle(
                                                color: packageColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _getPackagePrice(packageName),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SelectableText(
                                        code,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Created: ${_formatDate(codeData['created_at'])}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildExpiryIndicator(
                                        codeData['email_sent_at']?.toString(),
                                        codeData['expires_at']?.toString(),
                                      ),
                                    ],
                                  ),
                                ),

                                // Copy icon
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: packageColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.content_copy,
                                    color: packageColor,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildExpiryIndicator(String? emailSentAt, String? expiresAt) {
    if (expiresAt == null) {
      if (emailSentAt == null) {
        return Row(
          children: [
            Icon(Icons.schedule, size: 12, color: Colors.blueGrey[400]),
            const SizedBox(width: 4),
            Text(
              'No expiry until emailed',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      }

      return const SizedBox.shrink();
    }

    try {
      final expiry = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final remaining = expiry.difference(now);

      Color statusColor;
      String statusText;
      IconData statusIcon;

      if (remaining.inSeconds <= 0) {
        statusColor = Colors.red;
        statusText = '⚠️ EXPIRED';
        statusIcon = Icons.error;
      } else if (remaining.inMinutes <= 10) {
        final mins = remaining.inMinutes;
        statusColor = Colors.orange;
        statusText = '⏰ Expires in $mins min';
        statusIcon = Icons.warning;
      } else if (remaining.inHours >= 1) {
        final hours = remaining.inHours;
        statusColor = Colors.green;
        statusText = '✓ Valid (${hours}h ${remaining.inMinutes % 60}m left)';
        statusIcon = Icons.check_circle;
      } else {
        final mins = remaining.inMinutes;
        statusColor = Colors.green;
        statusText = '✓ Valid ($mins min left)';
        statusIcon = Icons.check_circle;
      }

      return Row(
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } catch (e) {
      return Row(
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.blueGrey[400]),
          const SizedBox(width: 4),
          Text(
            'Available until emailed',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }
}
