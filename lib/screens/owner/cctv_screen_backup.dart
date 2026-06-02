import 'package:flutter/material.dart';
import '../../services/cctv_service.dart';
import '../../utils/app_localizations.dart';

class CCTVScreen extends StatefulWidget {
  final DateTime? timestamp;

  const CCTVScreen({super.key, this.timestamp});

  @override
  State<CCTVScreen> createState() => _CCTVScreenState();
}

class _CCTVScreenState extends State<CCTVScreen> {
  late CCTVService _cctvService;
  bool _seeking = false;
  bool _testingConnection = false;
  bool _showSettings = false;
  late TextEditingController _cameraUrlController;
  late TextEditingController _recordingsController;
  // Explicit UI config: max preview width (can be adjusted)
  static const double _kPreviewMaxWidth = 1000.0;

  @override
  void initState() {
    super.initState();
    _cctvService = CCTVService.instance;
    _cameraUrlController = TextEditingController(text: _cctvService.cameraUrl);
    _recordingsController = TextEditingController(
      text: '/recordings',
    ); // Default path
    _cctvService.addListener(_onCCTVStateChanged);
  }

  void _onCCTVStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cctvService.removeListener(_onCCTVStateChanged);
    _cameraUrlController.dispose();
    _recordingsController.dispose();
    super.dispose();
  }

  Future<void> _seek() async {
    if (widget.timestamp == null) return;
    setState(() => _seeking = true);

    // Show dialog to optionally add description
    String? description;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save Timestamp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Timestamp: ${widget.timestamp!.toLocal()}'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Suspicious activity',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                description = null;
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                description = controller.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (description == null && !mounted) {
      setState(() => _seeking = false);
      return;
    }

    final ok = await _cctvService.seekTo(
      widget.timestamp!,
      description: description?.isEmpty ?? true ? null : description,
    );

    if (!mounted) return;
    setState(() => _seeking = false);

    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timestamp saved: ${widget.timestamp!.toLocal()}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save timestamp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveCurrentTimestamp() async {
    final currentTime = DateTime.now();

    // Show dialog to add description
    String? description;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Current Timestamp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Time: ${currentTime.toLocal()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Important event, Incident recorded',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                description = controller.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    // Save timestamp
    final ok = await _cctvService.seekTo(
      currentTime,
      description: description?.isEmpty ?? true ? null : description,
    );

    if (!mounted) return;

    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timestamp saved: ${currentTime.toLocal()}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save timestamp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final url = _cameraUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a camera URL')),
      );
      return;
    }

    setState(() => _testingConnection = true);
    _cctvService.configure(
      cameraUrl: url,
      recordingsDirectory: _recordingsController.text.trim(),
    );
    final success = await _cctvService.testConnection();
    if (!mounted) return;
    setState(() => _testingConnection = false);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ CCTV connection successful')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Connection failed: ${_cctvService.connectionError}'),
        ),
      );
    }
  }

  Widget _buildLiveStreamPreview() {
    if (!_cctvService.isConnected) {
      final content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Camera Not Connected',
            style: TextStyle(color: Colors.grey[300], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _cctvService.connectionError ?? 'Configure camera to connect',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      );

      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Keep preview responsive: full width on small screens,
                // but constrained on larger screens for better centering.
                maxWidth: MediaQuery.of(context).size.width < _kPreviewMaxWidth
                    ? double.infinity
                    : _kPreviewMaxWidth,
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Center(child: content),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Placeholder for live stream preview
    // In a real app, use video_player or native camera preview
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videocam, size: 80, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'LIVE FEED',
          style: TextStyle(
            color: Colors.green,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _cctvService.cameraUrl ?? 'Connected',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width < _kPreviewMaxWidth
                  ? double.infinity
                  : _kPreviewMaxWidth,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CCTV Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Camera URL / RTSP Stream'),
          const SizedBox(height: 8),
          TextField(
            controller: _cameraUrlController,
            decoration: InputDecoration(
              hintText: 'e.g., rtsp://192.168.1.100:554/stream',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link),
              helperText: 'RTSP or HTTP stream URL',
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Recordings Directory (Optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _recordingsController,
            decoration: InputDecoration(
              hintText: 'e.g., /recordings or C:\\recordings',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.folder),
              helperText: 'Path to stored video recordings',
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: Icon(
                    _testingConnection
                        ? Icons.hourglass_empty
                        : Icons.check_circle,
                  ),
                  label: Text(
                    _testingConnection ? 'Testing...' : 'Test Connection',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cctvService.isConnected
                      ? () {
                          _cctvService.disconnect();
                          setState(() => _showSettings = false);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text(
                    'Disconnect',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_cctvService.connectionError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _cctvService.connectionError!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          if (_cctvService.isConnected)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connected to ${_cctvService.cameraUrl}',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.timestamp;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('cctv_monitoring')),
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.close : Icons.settings),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: _showSettings
          ? _buildSettingsPanel()
          : Column(
              children: [
                Expanded(flex: 3, child: _buildLiveStreamPreview()),
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (timestamp != null) ...[
                              const Text(
                                'Linked Timestamp:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                timestamp.toLocal().toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _seeking ? null : _seek,
                                icon: Icon(
                                  _seeking
                                      ? Icons.hourglass_empty
                                      : Icons.play_arrow,
                                ),
                                label: Text(
                                  _seeking ? 'Seeking...' : 'Seek to Timestamp',
                                ),
                              ),
                            ] else
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam, size: 48),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Live CCTV Monitoring',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _saveCurrentTimestamp,
                                    icon: const Icon(Icons.bookmark_add),
                                    label: const Text('Save Current Timestamp'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTimestampsLog,
        icon: const Icon(Icons.history),
        label: Text(AppLocalizations.t('timestamps_log')),
      ),
    );
  }

  void _openTimestampsLog() async {
    await _cctvService.loadTimestamps();
    if (!mounted) return;

    final timestamps = _cctvService.savedTimestamps;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.access_time),
            const SizedBox(width: 8),
            Text(AppLocalizations.t('saved_timestamps')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: timestamps.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.t('no_timestamps_saved'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: timestamps.length,
                  itemBuilder: (context, idx) {
                    final ts = timestamps[idx];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const Icon(
                            Icons.videocam,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          ts.formattedTimestamp,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: ${ts.formattedDate}'),
                            if (ts.description != null &&
                                ts.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  ts.description!,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: AppLocalizations.t('view_footage'),
                              icon: const Icon(Icons.play_circle_outline),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CCTVScreen(timestamp: ts.timestamp),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: ts.videoPath != null
                                  ? AppLocalizations.t('video_exported')
                                  : AppLocalizations.t('export_video'),
                              icon: Icon(
                                ts.videoPath != null
                                    ? Icons.check_circle
                                    : Icons.download,
                                color: ts.videoPath != null
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                              onPressed: ts.id == null
                                  ? null
                                  : () async {
                                      if (ts.videoPath != null) {
                                        // Show video path info
                                        if (context.mounted) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text(
                                                AppLocalizations.t(
                                                  'video_exported',
                                                ),
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    AppLocalizations.t(
                                                      'file_path',
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(ts.videoPath!),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    AppLocalizations.t('close'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      // Export footage
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final navigator = Navigator.of(context);

                                      // Show loading dialog
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(
                                          child: Card(
                                            child: Padding(
                                              padding: EdgeInsets.all(24),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(),
                                                  SizedBox(height: 16),
                                                  Text('Exporting footage...'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );

                                      final filePath = await _cctvService
                                          .exportFootage(
                                            ts.id!,
                                            ts.timestamp,
                                            durationSeconds: 60,
                                          );

                                      if (context.mounted) {
                                        navigator.pop(); // Close loading dialog
                                      }

                                      if (filePath != null) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${AppLocalizations.t('video_export_success')}: $filePath',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(
                                              seconds: 4,
                                            ),
                                          ),
                                        );
                                        if (context.mounted) {
                                          navigator
                                              .pop(); // Close timestamps dialog
                                          _openTimestampsLog(); // Refresh list
                                        }
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AppLocalizations.t(
                                                'video_export_failed',
                                              ),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                            ),
                            IconButton(
                              tooltip: AppLocalizations.t('delete'),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(
                                      AppLocalizations.t('confirm_delete'),
                                    ),
                                    content: Text(
                                      AppLocalizations.t(
                                        'delete_timestamp_confirm',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          AppLocalizations.t('cancel'),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Text(
                                          AppLocalizations.t('delete'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && ts.id != null) {
                                  await _cctvService.deleteTimestamp(ts.id!);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _openTimestampsLog();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (timestamps.isNotEmpty)
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(AppLocalizations.t('clear_all')),
                    content: Text(
                      AppLocalizations.t('clear_all_timestamps_confirm'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppLocalizations.t('cancel')),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text(AppLocalizations.t('clear_all')),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _cctvService.clearAllTimestamps();
                  if (context.mounted) {
                    navigator.pop();
                  }
                }
              },
              child: Text(AppLocalizations.t('clear_all')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }
}
