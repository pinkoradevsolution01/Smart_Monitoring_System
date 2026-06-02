import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import '../../services/database_service.dart';
import '../../services/pos_service.dart';
import '../../utils/app_localizations.dart';

/// Screen for managing database backups and restoration
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<String> _backups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    try {
      final backups = await _databaseService.getAvailableBackups();
      setState(() {
        _backups = backups;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load backups: $e')));
    }
  }

  Future<void> _createBackup() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Creating backup...')));

      await _databaseService.createBackup();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreBackup(String backupPath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will replace all current data with the backup. '
          'Current data will be lost. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Restoring backup...')));

      await _databaseService.restoreFromBackup(backupPath);

      // Reload POSService data after restore
      try {
        final posService = GetIt.I<POSService>();
        await posService.loadProducts();
        await posService.loadRecentSales(days: 30);
        debugPrint('✅ POSService data reloaded after restore');
      } catch (e) {
        debugPrint('⚠️ Warning: Could not reload POSService: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup restored successfully! Data has been reloaded.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Refresh the backup list
      await _loadBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreLatestBackup() async {
    if (_backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backups available to restore'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get the latest backup (first in the list as they're sorted newest first)
    final latestBackup = _backups.first;
    final backupName = _formatBackupName(latestBackup);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Restore'),
        content: Text(
          'This will restore the latest backup:\n\n'
          '$backupName\n\n'
          'All current data will be replaced. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _restoreBackup(latestBackup);
    }
  }

  Future<void> _exportBackup() async {
    try {
      // Check if running on Android or iOS
      final isAndroidOrIOS = Platform.isAndroid || Platform.isIOS;

      if (isAndroidOrIOS) {
        // On Android/iOS, pass bytes directly to saveFile
        final bytes = await _databaseService.getDatabaseBytes();
        final uint8Bytes = Uint8List.fromList(bytes);

        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Database Backup',
          fileName:
              'pos_system_export_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.db',
          bytes: uint8Bytes,
        );

        if (result == null) return;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // On Windows/Linux/macOS, use the standard file path approach
        final String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Database Backup',
          fileName:
              'pos_system_export_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.db',
        );

        if (outputPath == null) return;

        await _databaseService.exportDatabase(outputPath);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatBackupName(String path) {
    final fileName = path.split('\\').last.split('/').last;
    // Extract timestamp from filename: pos_system_backup_2025-12-18T10-30-00.db
    final match = RegExp(
      r'_(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})\.db',
    ).firstMatch(fileName);
    if (match != null) {
      final timestamp = match
          .group(1)!
          .replaceAll('T', ' ')
          .replaceAll('-', ':');
      try {
        final date = DateTime.parse(
          timestamp.replaceAll(':', '-').replaceAll(' ', 'T'),
        );
        return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
      } catch (e) {
        return fileName;
      }
    }
    return fileName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1000,
                maxHeight: constraints.maxHeight,
              ),
              child: Column(
                children: [
                  // Info Card
                  Card(
                    margin: const EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete Data Protection',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your data is stored in:\nDocuments\\SmartMonitoringSystem\n\n'
                                  'This folder is NOT deleted when you uninstall the app. '
                                  'Automatic backups are created daily and kept for 7 days.\n\n'
                                  'Includes: Products, Sales, Inventory, Damage Reports, '
                                  'Suppliers, Purchase Orders, Restock Records, CCTV Data, and Cameras.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _createBackup,
                                icon: const Icon(Icons.backup),
                                label: const Text('Create Backup'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _exportBackup,
                                icon: const Icon(Icons.download),
                                label: const Text('Export'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Quick Restore Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _backups.isEmpty
                                ? null
                                : _restoreLatestBackup,
                            icon: const Icon(Icons.restore),
                            label: const Text('Quick Restore (Latest Backup)'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Backups List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Available Backups (${_backups.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (!_loading)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadBackups,
                            tooltip: 'Refresh',
                          ),
                      ],
                    ),
                  ),

                  const Divider(),

                  // Backups List
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _backups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.backup_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No backups available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first backup to protect your data',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _backups.length,
                            itemBuilder: (context, index) {
                              final backupPath = _backups[index];
                              final isAutoBackup = backupPath.contains(
                                'pos_system_backup_',
                              );

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAutoBackup
                                      ? Colors.blue.shade100
                                      : Colors.green.shade100,
                                  child: Icon(
                                    isAutoBackup
                                        ? Icons.schedule
                                        : Icons.backup,
                                    color: isAutoBackup
                                        ? Colors.blue.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                                title: Text(_formatBackupName(backupPath)),
                                subtitle: Text(
                                  isAutoBackup
                                      ? 'Automatic backup'
                                      : 'Manual backup',
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.restore),
                                  color: Theme.of(context).colorScheme.primary,
                                  onPressed: () => _restoreBackup(backupPath),
                                  tooltip: 'Restore this backup',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
