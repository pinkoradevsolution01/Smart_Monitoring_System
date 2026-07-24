import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/subscriber_service.dart';
import '../../services/cloud_subscription_service.dart';
import '../../models/subscriber.dart';

class SubscribersScreen extends StatefulWidget {
  const SubscribersScreen({super.key});

  @override
  State<SubscribersScreen> createState() => _SubscribersScreenState();
}
class _SubscribersScreenState extends State<SubscribersScreen>
    with WidgetsBindingObserver {
  final SubscriberService _svc = SubscriberService();
  bool _isSyncing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.addListener(_onChange);
    // Auto-sync when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('=============================================================');
      debugPrint('📊 SUBSCRIBERS SCREEN OPENED - AUTO-SYNCING');
      debugPrint('=============================================================');
      _syncSubscribers();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !_isSyncing) {
        _syncSubscribers();
      }
    });
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _svc.removeListener(_onChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isSyncing) {
      _syncSubscribers();
    }
  }

  Future<void> _syncSubscribers() async {
    setState(() => _isSyncing = true);
    try {
      final newCount = await _svc.syncFromAllSources();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newCount > 0 
                  ? '✅ Synced successfully! Added $newCount new subscriber${newCount == 1 ? '' : 's'}'
                  : '✅ Sync complete. All subscribers up to date',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = _svc.subscribers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribers'),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncSubscribers,
              tooltip: 'Sync from Cloud',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'About Subscribers',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Info banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Showing ${subs.length} cloud subscriber${subs.length == 1 ? '' : 's'}. '
                        'Tap sync icon to refresh from the cloud.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: subs.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.subscriptions_outlined,
                              size: 72,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text('No subscribers yet'),
                            const SizedBox(height: 8),
                            Text(
                              'Subscribers are loaded from cloud subscription records',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isSyncing ? null : _syncSubscribers,
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync Now'),
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: subs.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, i) {
                            final s = subs[i];
                            return ListTile(
                              leading: Icon(
                                s.status == 'cancelled'
                                    ? Icons.cancel_outlined
                                    : Icons.person_outline,
                                color: s.status == 'cancelled' ? Colors.red : null,
                              ),
                              title: Text(s.name),
                              subtitle: Text(
                                '${s.email}${s.contactNumber != null ? ' • ${s.contactNumber}' : ''}',
                              ),
                              trailing: Text(
                                s.status.toUpperCase(),
                                style: TextStyle(
                                  color: s.status == 'cancelled'
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              onTap: () => _showDetails(s),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('About Subscribers'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unified Subscriber Management:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                '📱 This screen shows all subscribers from:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '• Local cached subscribers (from this device)\n'
                '• Cloud subscription records (from Supabase)\n'
                '• Automatically synced when you open this screen\n\n'
                '💡 Note: The subscriber name comes from the activation request or the business name tied to the code.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              const Text(
                '🔄 Sync Feature:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the sync icon (🔄) to fetch the latest subscribers from both local database and cloud. '
                'This ensures you have a complete list of subscribers across all devices.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              const Text(
                '🎯 What You Can Do:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '• View all subscribers in one place\n'
                '• Monitor subscription status\n'
                '• Deactivate subscriptions\n'
                '• Track registration dates',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subscribers from both sources are automatically merged and deduplicated.',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  void _showDetails(Subscriber s) async {
    // Fetch subscription records for this subscriber
    final cloudService = CloudSubscriptionService();
    if (cloudService.subscriptions.isEmpty) {
      await cloudService.fetchSubscriptions();
    }
    
    // Find subscriptions for this subscriber (by device ID or email match)
    final subscriberSubscriptions = cloudService.subscriptions.where((sub) {
      return sub.deviceId == s.id || 
             sub.deviceName?.toLowerCase() == s.email.toLowerCase();
    }).toList();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(s.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('📧 Email', s.email),
              _buildDetailRow('Status', s.status.toUpperCase()),
              if (s.contactNumber != null) 
                _buildDetailRow('📱 Contact', s.contactNumber!),
              _buildDetailRow('📅 Registered', s.createdAt.toLocal().toString().split('.')[0]),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.cloud_outlined, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Cloud Subscriptions (${subscriberSubscriptions.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (subscriberSubscriptions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No cloud subscriptions found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...subscriberSubscriptions.map((sub) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sub.isActive 
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sub.isActive
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            sub.isActive ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: sub.isActive ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sub.packageName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: sub.isActive ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${sub.formattedStatus}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Activated: ${sub.activatedAt.toLocal().toString().split('.')[0]}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (s.status != 'cancelled')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeactivation(s);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Deactivate'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivation(Subscriber s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Confirm Deactivation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to deactivate ${s.name}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• Mark linked subscription records as inactive'),
            const Text('• Remove the subscriber’s local and business data'),
            const Text('• Reset the system to an inactive subscriber state'),
            const SizedBox(height: 12),
            const Text(
              '⚠️ This action CANNOT be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deactivateSubscriber(s);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateSubscriber(Subscriber s) async {
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deactivating subscriber...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _svc.purgeSubscriberData(s);

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.name} has been deactivated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _syncSubscribers();
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deactivating subscriber: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
