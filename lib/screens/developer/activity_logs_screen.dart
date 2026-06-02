import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../services/database_service.dart';

// ignore_for_file: unnecessary_underscores, unnecessary_this

class ActivityLogEntry {
  final int id;
  final String type;
  final String message;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  ActivityLogEntry({
    required this.id,
    required this.type,
    required this.message,
    this.meta,
    required this.createdAt,
  });

  factory ActivityLogEntry.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic>? meta;
    try {
      if (m['meta'] != null) {
        if (m['meta'] is String && (m['meta'] as String).isNotEmpty) {
          meta = jsonDecode(m['meta'] as String) as Map<String, dynamic>;
        } else if (m['meta'] is Map) {
          meta = Map<String, dynamic>.from(m['meta'] as Map);
        }
      }
    } catch (e) {
      meta = null;
    }
    return ActivityLogEntry(
      id: m['id'] as int,
      type: m['type'] as String,
      message: m['message'] as String,
      meta: meta,
      createdAt: DateTime.parse(m['createdAt'] as String),
    );
  }
}

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  List<ActivityLogEntry> _logs = [];
  bool _loading = true;
  String _selectedType = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  List<String> _types = ['all'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final rows = await DatabaseService().fetchActivityLogs(limit: 200);
      final parsed = rows
          .map((r) => ActivityLogEntry.fromMap(Map<String, dynamic>.from(r)))
          .toList();
      // build type list from fetched rows
      final types = <String>{'all'};
      for (final r in parsed) {
        types.add(r.type);
      }
      setState(() {
        _types = types.toList();
      });
      setState(() {
        _logs = parsed;
      });
    } catch (e) {
      debugPrint('Failed to load activity logs: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _loading = true);
    try {
      final rows = await DatabaseService().fetchActivityLogs(
        type: _selectedType == 'all' ? null : _selectedType,
        from: _fromDate,
        to: _toDate,
        limit: 2000,
      );
      final parsed = rows
          .map((r) => ActivityLogEntry.fromMap(Map<String, dynamic>.from(r)))
          .toList();
      if (!mounted) return;
      setState(() {
        _logs = parsed;
      });
    } catch (e) {
      debugPrint('Failed to apply filters: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply filters: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedType = 'all';
      _fromDate = null;
      _toDate = null;
    });
    await _loadLogs();
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now.subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _toDate = picked);
  }

  // ignore: unused_element
  Future<String> _exportsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(
      path.join(dir.path, 'SmartMonitoringSystem', 'Exports'),
    );
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Logs')),
      body: Container(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedType,
                                          items: _types
                                              .map(
                                                (t) => DropdownMenuItem(
                                                  value: t,
                                                  child: Text(t),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) => setState(
                                            () => _selectedType = v ?? 'all',
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: 'Type',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: SizedBox(
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: _pickFromDate,
                                            child: Text(
                                              _fromDate == null
                                                  ? 'From'
                                                  : _fromDate!
                                                        .toLocal()
                                                        .toString()
                                                        .split(' ')[0],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: SizedBox(
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: _pickToDate,
                                            child: Text(
                                              _toDate == null
                                                  ? 'To'
                                                  : _toDate!
                                                        .toLocal()
                                                        .toString()
                                                        .split(' ')[0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: _resetFilters,
                                        child: const Text('Reset'),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: SizedBox(
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: _applyFilters,
                                            child: const Text('Apply'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _logs.isEmpty
                                  ? const Center(
                                      child: Text('No activity logs found'),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _loadLogs,
                                      child: ListView.separated(
                                        padding: const EdgeInsets.all(12),
                                        itemCount: _logs.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(),
                                        itemBuilder: (context, i) {
                                          final l = _logs[i];
                                          return ListTile(
                                            leading: _iconForType(l.type),
                                            title: Text(l.message),
                                            subtitle: Text(
                                              '${l.type} • ${l.createdAt.toLocal()}',
                                            ),
                                            trailing:
                                                l.meta != null &&
                                                    l.meta!.isNotEmpty
                                                ? const Icon(Icons.info_outline)
                                                : null,
                                            onTap: () => _showDetails(l),
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
          },
        ),
      ),
    );
  }

  Widget _iconForType(String type) {
    switch (type) {
      case 'trial_cancelled':
        return const Icon(Icons.cancel, color: Colors.red);
      case 'trial_activated':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.event, color: Colors.blueGrey);
    }
  }

  void _showDetails(ActivityLogEntry l) {
    // Use post-frame callback to avoid showing a dialog during a frame update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.type),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.message),
              const SizedBox(height: 12),
              Text('Created: ${l.createdAt.toLocal()}'),
              if (l.meta != null) ...[
                const SizedBox(height: 12),
                Text('Meta:'),
                Text(l.meta.toString()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }
}
