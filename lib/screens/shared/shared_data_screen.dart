import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/shared_api_service.dart';

class SharedDataScreen extends StatefulWidget {
  const SharedDataScreen({super.key});

  @override
  State<SharedDataScreen> createState() => _SharedDataScreenState();
}

class _SharedDataScreenState extends State<SharedDataScreen> {
  SharedApiService? _svc;

  @override
  void initState() {
    super.initState();
    if (GetIt.I.isRegistered<SharedApiService>()) {
      _svc = GetIt.I<SharedApiService>();
      _svc!.addListener(_onUpdate);
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc?.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _svc?.sharedData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final ok = await _svc?.fetchSharedData(force: true) ?? false;
              if (!ok && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Fetch failed')));
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Endpoint: ${_svc?.endpointUrl ?? 'Not configured'}'),
            const SizedBox(height: 12),
            Text(
              'Auto-refresh: ${_svc?.autoRefreshEnabled == true ? 'On' : 'Off'}',
            ),
            const SizedBox(height: 16),
            const Text('Payload:'),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data != null ? data.payload.toString() : 'No data cached',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
