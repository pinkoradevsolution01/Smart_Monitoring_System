import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/code_request_service.dart';

class ActivationRequestsScreen extends StatefulWidget {
  const ActivationRequestsScreen({super.key});

  @override
  State<ActivationRequestsScreen> createState() =>
      _ActivationRequestsScreenState();
}

class _ActivationRequestsScreenState extends State<ActivationRequestsScreen> {
  final CodeRequestService _requestService = CodeRequestService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _filter = 'pending'; // 'pending', 'fulfilled', 'all'

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _requestService.getRequests();
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading requests: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_filter == 'all') return _requests;
    return _requests
        .where((r) => (r['status']?.toString() ?? '') == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📬 Activation Requests'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRequests,
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
        child: Column(
          children: [
            _buildFilterChips(),
            _buildStatsBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _filteredRequests.isEmpty
                  ? _buildEmptyState()
                  : _buildRequestsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFilterChip('Pending', 'pending', Colors.orange),
          const SizedBox(width: 8),
          _buildFilterChip('Fulfilled', 'fulfilled', Colors.green),
          const SizedBox(width: 8),
          _buildFilterChip('All', 'all', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      selectedColor: color.withValues(alpha: 0.3),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[800],
      side: BorderSide(color: isSelected ? color : Colors.grey[700]!),
    );
  }

  Widget _buildStatsBar() {
    final pendingCount = _requests
        .where((r) => r['status'] == 'pending')
        .length;
    final fulfilledCount = _requests
        .where((r) => r['status'] == 'fulfilled')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[850],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Pending', pendingCount, Colors.orange),
          _buildStatItem('Fulfilled', fulfilledCount, Colors.green),
          _buildStatItem('Total', _requests.length, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filter == 'pending'
                ? Icons.inbox_outlined
                : Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            _filter == 'pending'
                ? 'No Pending Requests'
                : _filter == 'fulfilled'
                ? 'No Fulfilled Requests'
                : 'No Requests Yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == 'pending'
                ? 'New requests will appear here'
                : 'Completed requests will appear here',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final isPending = request['status'] == 'pending';
    final statusColor = isPending ? Colors.orange : Colors.green;

    return Card(
      color: Colors.grey[850],
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            isPending ? Icons.schedule : Icons.check_circle,
            color: statusColor,
          ),
        ),
        title: Text(
          request['business_name'] ?? 'Unknown Business',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${request['package_name']} - ${request['package_price']}',
              style: TextStyle(color: Colors.blue[300], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(request['requested_at']),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        trailing: isPending
            ? Chip(
                label: const Text('PENDING'),
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                labelStyle: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              )
            : Chip(
                label: const Text('FULFILLED'),
                backgroundColor: Colors.green.withValues(alpha: 0.2),
                labelStyle: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
        children: [
          _buildDetailRow(
            'Contact Email',
            request['contact_email'] ?? 'N/A',
            Icons.email,
            Colors.blue,
          ),
          _buildDetailRow(
            'Contact Phone',
            request['contact_phone'] ?? 'N/A',
            Icons.phone,
            Colors.green,
          ),
          _buildDetailRow(
            'Request Type',
            (request['request_type'] ?? 'N/A').toUpperCase(),
            Icons.category,
            Colors.purple,
          ),
          if (request['additional_notes'] != null &&
              request['additional_notes'].toString().isNotEmpty)
            _buildDetailRow(
              'Notes',
              request['additional_notes'],
              Icons.note,
              Colors.orange,
            ),
          if (!isPending && request['activation_code'] != null)
            _buildDetailRow(
              'Activation Code',
              request['activation_code'],
              Icons.vpn_key,
              Colors.amber,
            ),
          if (!isPending && request['fulfilled_at'] != null)
            _buildDetailRow(
              'Fulfilled At',
              _formatDate(request['fulfilled_at']),
              Icons.check_circle,
              Colors.green,
            ),
          const Divider(color: Colors.grey),
          const SizedBox(height: 8),
          if (isPending)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copyContactInfo(request),
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('Copy Info'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showFulfillDialog(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Fulfill Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  void _copyContactInfo(Map<String, dynamic> request) {
    final info =
        '''
Business Name: ${request['business_name']}
Package: ${request['package_name']} (${request['package_price']})
Type: ${request['request_type']}
Contact Email: ${request['contact_email']}
Contact Phone: ${request['contact_phone']}
Notes: ${request['additional_notes'] ?? 'None'}
Requested: ${_formatDate(request['requested_at'])}
''';

    Clipboard.setData(ClipboardData(text: info));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Contact information copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showFulfillDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while processing
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Row(
          children: [
            Icon(Icons.hourglass_bottom, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Finding Activation Code',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business: ${request['business_name']}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Package: ${request['package_name']}',
              style: const TextStyle(color: Colors.blue),
            ),
            const SizedBox(height: 24),
            const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Searching for available activation code...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    // Fetch code and fulfill in background
    _fulfillRequestWithAvailableCode(request, context);
  }

  Future<void> _fulfillRequestWithAvailableCode(
    Map<String, dynamic> request,
    BuildContext dialogContext,
  ) async {
    try {
      final packageName = request['package_name'] as String;

      // Get available activation code
      final code = await _requestService.getAvailableActivationCode(
        packageName,
      );

      if (code == null) {
        // No code available - close dialog and show error
        if (mounted && dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No available activation codes for $packageName'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Fulfill the request on the server so the email send and expiry start
      // happen together only after delivery succeeds.
      final success = await _requestService.fulfillRequestWithEmail(
        requestId: request['id'],
        activationCode: code,
      );

      if (!success) {
        throw Exception('Failed to fulfill request and send activation email');
      }

      // Close loading dialog
      if (mounted && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      // Show success message with email status
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Request fulfilled! Code: $code\n📧 Email sent to customer',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      await _loadRequests(); // Reload list
    } catch (e) {
      debugPrint('Error fulfilling request: $e');

      // Close loading dialog
      if (mounted && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
