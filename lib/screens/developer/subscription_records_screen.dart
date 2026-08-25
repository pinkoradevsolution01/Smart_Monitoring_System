import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/cloud_subscription_service.dart';
import '../../models/subscription_record.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';

class SubscriptionRecordsScreen extends StatefulWidget {
  final CloudSubscriptionService cloudSubscriptionService;

  const SubscriptionRecordsScreen({
    super.key,
    required this.cloudSubscriptionService,
  });

  @override
  State<SubscriptionRecordsScreen> createState() =>
      _SubscriptionRecordsScreenState();
}

class _SubscriptionRecordsScreenState extends State<SubscriptionRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus =
      'all'; // all, active, expired, cancelled, one_time, saas

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SubscriptionRecord> _getFilteredSubscriptions() {
    List<SubscriptionRecord> subscriptions =
        widget.cloudSubscriptionService.subscriptions;

    // Apply status filter
    if (_filterStatus == 'active') {
      subscriptions = subscriptions.where((s) => s.isActive).toList();
    } else if (_filterStatus == 'expired') {
      subscriptions = subscriptions.where((s) => s.isExpired).toList();
    } else if (_filterStatus == 'cancelled') {
      subscriptions = subscriptions
          .where((s) => s.status.toLowerCase() == 'cancelled')
          .toList();
    } else if (_filterStatus == 'one_time') {
      // Perpetual licenses have no expiry date. This also includes cancelled
      // one-time licenses, which can be narrowed further with search.
      subscriptions = subscriptions.where((s) => s.expiresAt == null).toList();
    } else if (_filterStatus == 'saas') {
      subscriptions = subscriptions.where((s) => s.expiresAt != null).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      subscriptions = subscriptions.where((s) {
        return (s.deviceName?.toLowerCase().contains(query) ?? false) ||
            s.activationCode.toLowerCase().contains(query) ||
            s.packageName.toLowerCase().contains(query);
      }).toList();
    }

    return subscriptions;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DeveloperTheme.dark(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Subscription Records'),
          backgroundColor: Colors.grey[900],
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportToCsv,
              tooltip: 'Export to CSV',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => widget.cloudSubscriptionService.refresh(),
              tooltip: 'Refresh',
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
              // Search and Filter Bar
              _buildSearchAndFilterBar(),

              // Subscription List
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.cloudSubscriptionService,
                  builder: (context, _) {
                    if (widget.cloudSubscriptionService.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (widget.cloudSubscriptionService.error != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.cloudSubscriptionService.error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  widget.cloudSubscriptionService.refresh(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final subscriptions = _getFilteredSubscriptions();

                    if (subscriptions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 80,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No subscriptions found matching "$_searchQuery"'
                                  : 'No subscription records found',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: subscriptions.length,
                      itemBuilder: (context, index) {
                        final subscription = subscriptions[index];
                        return _buildSubscriptionCard(subscription);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by device name, package, or activation code...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filterStatus == 'all',
                onSelected: (selected) {
                  setState(() {
                    _filterStatus = 'all';
                  });
                },
                selectedColor: Colors.blue.withValues(alpha: 0.3),
                checkmarkColor: Colors.blue,
              ),
              FilterChip(
                label: const Text('Active'),
                selected: _filterStatus == 'active',
                onSelected: (selected) {
                  setState(() {
                    _filterStatus = 'active';
                  });
                },
                selectedColor: Colors.green.withValues(alpha: 0.3),
                checkmarkColor: Colors.green,
              ),
              FilterChip(
                label: const Text('Expired'),
                selected: _filterStatus == 'expired',
                onSelected: (selected) {
                  setState(() {
                    _filterStatus = 'expired';
                  });
                },
                selectedColor: Colors.red.withValues(alpha: 0.3),
                checkmarkColor: Colors.red,
              ),
              FilterChip(
                label: const Text('Cancelled'),
                selected: _filterStatus == 'cancelled',
                onSelected: (_) => setState(() => _filterStatus = 'cancelled'),
                selectedColor: Colors.red.withValues(alpha: 0.3),
                checkmarkColor: Colors.red,
              ),
              FilterChip(
                label: const Text('One-Time'),
                selected: _filterStatus == 'one_time',
                onSelected: (_) => setState(() => _filterStatus = 'one_time'),
                selectedColor: Colors.green.withValues(alpha: 0.3),
                checkmarkColor: Colors.green,
              ),
              FilterChip(
                label: const Text('SaaS'),
                selected: _filterStatus == 'saas',
                onSelected: (_) => setState(() => _filterStatus = 'saas'),
                selectedColor: Colors.blue.withValues(alpha: 0.3),
                checkmarkColor: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionRecord subscription) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final isActive = subscription.isActive;
    final statusColor = isActive ? Colors.green : Colors.red;

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showSubscriptionDetails(subscription),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subscription.deviceName ?? 'Unknown Device',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPackageColor(
                        subscription.packageName,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getPackageColor(
                          subscription.packageName,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      subscription.packageName,
                      style: TextStyle(
                        color: _getPackageColor(subscription.packageName),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Rows
              _buildDetailRow(
                Icons.vpn_key,
                'Code',
                subscription.activationCode,
                Colors.orange,
              ),
              const SizedBox(height: 6),
              _buildDetailRow(
                Icons.calendar_today,
                'Activated',
                dateFormat.format(subscription.activatedAt.toLocal()),
                Colors.blue,
              ),
              const SizedBox(height: 6),
              _buildDetailRow(
                Icons.event,
                'Expires',
                subscription.expiresAt == null
                    ? 'Perpetual'
                    : dateFormat.format(subscription.expiresAt!.toLocal()),
                isActive ? Colors.green : Colors.red,
              ),
              if (isActive) ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  Icons.timer,
                  'Remaining',
                  '${subscription.remainingDays} days',
                  Colors.purple,
                ),
              ],
              const SizedBox(height: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.check : Icons.warning,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subscription.formattedStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getPackageColor(String packageName) {
    switch (packageName.toLowerCase()) {
      case 'basic':
        return Colors.blue;
      case 'standard':
        return Colors.purple;
      case 'premium':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  void _showSubscriptionDetails(SubscriptionRecord subscription) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm:ss');

    showDialog(
      context: context,
      builder: (dialogContext) => Theme(
        data: DeveloperTheme.dark(context),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                subscription.isActive ? Icons.check_circle : Icons.cancel,
                color: subscription.isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              const Text('Subscription Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoItem('ID', subscription.id.toString()),
                _buildInfoItem('Device Name', subscription.deviceName ?? 'N/A'),
                _buildInfoItem('Device ID', subscription.deviceId),
                _buildInfoItem('Package', subscription.packageName),
                _buildInfoItem('Activation Code', subscription.activationCode),
                _buildInfoItem(
                  'Status',
                  subscription.formattedStatus,
                  color: subscription.isActive ? Colors.green : Colors.red,
                ),
                const Divider(),
                _buildInfoItem(
                  'Activated At',
                  dateFormat.format(subscription.activatedAt.toLocal()),
                ),
                _buildInfoItem(
                  'Expires At',
                  subscription.expiresAt == null
                      ? 'Perpetual'
                      : dateFormat.format(subscription.expiresAt!.toLocal()),
                ),
                if (subscription.lastCheckedAt != null)
                  _buildInfoItem(
                    'Last Checked',
                    dateFormat.format(subscription.lastCheckedAt!.toLocal()),
                  ),
                if (subscription.notes != null) ...[
                  const Divider(),
                  _buildInfoItem('Notes', subscription.notes!),
                ],
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: subscription.activationCode),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Activation code copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: DeveloperTheme.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color ?? DeveloperTheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _exportToCsv() {
    final csv = widget.cloudSubscriptionService.exportToCsv();

    Clipboard.setData(ClipboardData(text: csv));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription data copied to clipboard as CSV'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
