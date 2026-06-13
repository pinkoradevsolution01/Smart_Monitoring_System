import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import '../../services/database_service.dart';
import '../../services/pos_service.dart';
import '../../services/google_drive_service.dart';
import '../../utils/app_localizations.dart';

/// Screen for managing database backups and restoration
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  List<String> _localBackups = [];
  List<BackupFileInfo> _cloudBackups = [];
  bool _loading = true;
  bool _isSignedInToGoogle = false;
  String? _userEmail;
  bool _uploadingToGoogle = false;
  bool _downloadingFromGoogle = false;
  bool get _cloudBackupsSupported => _googleDriveService.isSupported;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    if (_cloudBackupsSupported) {
      _checkGoogleSignIn();
    }
  }

  Future<void> _checkGoogleSignIn() async {
    if (!_cloudBackupsSupported) return;
    final isSignedIn = await _googleDriveService.isSignedIn();
    if (!mounted) return;
    setState(() {
      _isSignedInToGoogle = isSignedIn;
      _userEmail = _googleDriveService.getCurrentUserEmail();
    });
    if (isSignedIn) {
      await _loadCloudBackups();
    }
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    try {
      final backups = await _databaseService.getAvailableBackups();
      setState(() {
        _localBackups = backups;
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

  Future<void> _loadCloudBackups() async {
    if (!_cloudBackupsSupported || !_isSignedInToGoogle) return;
    try {
      final backups = await _googleDriveService.listBackups();
      setState(() {
        _cloudBackups = backups;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cloud backups: $e')),
      );
    }
  }

  Future<void> _signInToGoogle() async {
    if (!_cloudBackupsSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Drive backups are not supported on Windows.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final success = await _googleDriveService.signIn();
      if (success) {
        setState(() {
          _isSignedInToGoogle = true;
          _userEmail = _googleDriveService.getCurrentUserEmail();
        });
        await _loadCloudBackups();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Signed in to Google Drive'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e is PlatformException
          ? '${e.message}\nCheck Android OAuth client package name and SHA-1 configuration.'
          : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed: $errorMessage')));
    }
  }

  Future<void> _signOutFromGoogle() async {
    if (!_cloudBackupsSupported) return;
    await _googleDriveService.signOut();
    setState(() {
      _isSignedInToGoogle = false;
      _userEmail = null;
      _cloudBackups = [];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Signed out from Google Drive')),
    );
  }

  Future<void> _showBackupDestinationDialog() async {
    showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Backup Destination'),
        content: const Text('Where would you like to save the backup?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, 1);
              _createLocalBackup();
            },
            child: const Text('Local Storage'),
          ),
          if (_isSignedInToGoogle)
            TextButton(
              onPressed: () {
                Navigator.pop(context, 2);
                _createAndUploadBackup();
              },
              child: const Text('Google Drive'),
            ),
          if (!_isSignedInToGoogle)
            TextButton(
              onPressed: () {
                Navigator.pop(context, 0);
                _signInToGoogle();
              },
              child: const Text('Sign In to Google Drive'),
            ),
        ],
      ),
    );
  }

  Future<void> _createLocalBackup() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Creating backup...')));

      await _databaseService.createBackup();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Backup created successfully!'),
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

  Future<void> _createAndUploadBackup() async {
    if (!_cloudBackupsSupported || !_isSignedInToGoogle) return;
    try {
      setState(() => _uploadingToGoogle = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating backup and uploading...')),
      );

      final bytes = await _databaseService.getDatabaseBytes();
      final fileName =
          'pos_system_backup_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.db';

      // Create temporary file from bytes
      final tempDir = await _getTempDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      // Upload to Google Drive
      final success = await _googleDriveService.uploadBackup(
        tempFile,
        fileName,
      );

      // Clean up temp file
      await tempFile.delete();

      setState(() => _uploadingToGoogle = false);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup uploaded to Google Drive!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadCloudBackups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Upload failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadingToGoogle = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportBackupToFolder() async {
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
            content: Text('✅ Database exported successfully!'),
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
            content: Text('✅ Database exported successfully!'),
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

  Future<void> _showRestoreSourceDialog() async {
    showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Restore Source'),
        content: const Text('Where is your backup located?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, 1);
              _showLocalBackupList();
            },
            child: const Text('Local Storage'),
          ),
          if (_cloudBackupsSupported && _isSignedInToGoogle)
            TextButton(
              onPressed: () {
                Navigator.pop(context, 2);
                _showCloudBackupList();
              },
              child: const Text('Google Drive'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, 3);
              _restoreFromFile();
            },
            child: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  void _showLocalBackupList() {
    if (_localBackups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No local backups available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _localBackups.length,
        itemBuilder: (context, index) {
          final backupPath = _localBackups[index];
          return ListTile(
            leading: const Icon(Icons.backup),
            title: Text(_formatBackupName(backupPath)),
            subtitle: const Text('Local backup'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.pop(context);
              _restoreBackup(backupPath);
            },
          );
        },
      ),
    );
  }

  void _showCloudBackupList() {
    if (_cloudBackups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cloud backups available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _cloudBackups.length,
        itemBuilder: (context, index) {
          final backup = _cloudBackups[index];
          return ListTile(
            leading: const Icon(Icons.cloud),
            title: Text(backup.name),
            subtitle: Text(
              'Created: ${backup.createdDisplay}\nSize: ${backup.sizeDisplay}',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.pop(context);
              _restoreFromCloud(backup.id);
            },
          );
        },
      ),
    );
  }

  Future<void> _restoreFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Select backup file to restore',
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      await _restoreBackup(filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File selection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreFromCloud(String fileId) async {
    if (!_cloudBackupsSupported) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Cloud?'),
        content: const Text(
          'This will replace all current data with the cloud backup. '
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
      setState(() => _downloadingFromGoogle = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading and restoring backup...')),
      );

      final bytes = await _googleDriveService.downloadBackup(fileId);
      if (bytes == null) throw Exception('Failed to download backup');

      await _databaseService.importDatabaseFromBytes(bytes);

      // Reload POSService data after restore
      try {
        final posService = GetIt.I<POSService>();
        await posService.loadProducts();
        await posService.loadRecentSales(days: 30);
        debugPrint('✅ POSService data reloaded after restore');
      } catch (e) {
        debugPrint('⚠️ Warning: Could not reload POSService: $e');
      }

      setState(() => _downloadingFromGoogle = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Backup restored successfully! Data has been reloaded.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );

      await _loadBackups();
      await _loadCloudBackups();
    } catch (e) {
      setState(() => _downloadingFromGoogle = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
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
        const SnackBar(
          content: Text(
            '✅ Backup restored successfully! Data has been reloaded.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );

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
    if (_localBackups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backups available to restore'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final latestBackup = _localBackups.first;
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

  String _formatBackupName(String path) {
    final fileName = path.split('\\').last.split('/').last;
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

  Future<Directory> _getTempDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return Directory.systemTemp;
    } else {
      final dir = await Directory.systemTemp.createTemp('backup_');
      return dir;
    }
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
              child: ListView(
                children: [
                  if (_cloudBackupsSupported)
                    // Google Drive Sign In Section
                    Card(
                      margin: const EdgeInsets.all(16),
                      color: _isSignedInToGoogle
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud,
                              color: _isSignedInToGoogle
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSignedInToGoogle
                                        ? 'Google Drive Connected'
                                        : 'Google Drive Not Connected',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isSignedInToGoogle
                                          ? Colors.green.shade900
                                          : Colors.blue.shade900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isSignedInToGoogle
                                        ? 'Email: $_userEmail\nYour backups are synced across devices'
                                        : 'Sign in to backup and restore your data from Google Drive',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isSignedInToGoogle
                                          ? Colors.green.shade800
                                          : Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: ElevatedButton(
                                onPressed: _isSignedInToGoogle
                                    ? _signOutFromGoogle
                                    : _signInToGoogle,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  backgroundColor: _isSignedInToGoogle
                                      ? Colors.red.shade600
                                      : Colors.blue.shade600,
                                ),
                                child: Text(
                                  _isSignedInToGoogle ? 'Sign Out' : 'Sign In',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      margin: const EdgeInsets.all(16),
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off,
                              color: Colors.orange.shade700,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Drive Backups Unavailable',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Use local backup and restore on Windows.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                                  'Your data is stored locally in:\nDocuments\\SmartMonitoringSystem\n\n'
                                  'Automatic backups are created daily and kept for 7 days.\n\n'
                                  'You can also backup to Google Drive for access across devices.',
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

                  // Action Buttons Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup Operations',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showBackupDestinationDialog,
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
                                onPressed: _exportBackupToFolder,
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _restoreLatestBackup,
                            icon: const Icon(Icons.restore),
                            label: const Text(
                              'Quick Restore (Latest Local Backup)',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _uploadingToGoogle || _downloadingFromGoogle
                                ? null
                                : _showRestoreSourceDialog,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Restore from File/Cloud'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Local Backups List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Local Backups (${_localBackups.length})',
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

                  // Local Backups List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          )
                        : _localBackups.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
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
                                  'No local backups available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _localBackups.length,
                            itemBuilder: (context, index) {
                              final backupPath = _localBackups[index];
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
                                  style: const TextStyle(fontSize: 12),
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

                  if (_cloudBackupsSupported && _isSignedInToGoogle) ...[
                    const SizedBox(height: 24),

                    // Cloud Backups List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            'Cloud Backups (${_cloudBackups.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadCloudBackups,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Cloud Backups List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _cloudBackups.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_off_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No cloud backups available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _cloudBackups.length,
                              itemBuilder: (context, index) {
                                final backup = _cloudBackups[index];

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.purple.shade100,
                                    child: Icon(
                                      Icons.cloud,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                  title: Text(backup.name),
                                  subtitle: Text(
                                    'Created: ${backup.createdDisplay}\nSize: ${backup.sizeDisplay}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        child: const Text('Restore'),
                                        onTap: () =>
                                            _restoreFromCloud(backup.id),
                                      ),
                                      PopupMenuItem(
                                        child: const Text('Delete'),
                                        onTap: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Delete Cloud Backup?',
                                              ),
                                              content: const Text(
                                                'This action cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            final success =
                                                await _googleDriveService
                                                    .deleteBackup(backup.id);
                                            if (!mounted) return;
                                            if (success) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '✅ Backup deleted',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              await _loadCloudBackups();
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
