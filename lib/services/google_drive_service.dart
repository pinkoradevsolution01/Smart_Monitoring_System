import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Custom HTTP client that adds authentication headers
class _AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final String _accessToken;

  _AuthenticatedHttpClient(this._inner, this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}

/// Google Drive service for cloud-based backup and restore
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  static const String _appFolderName = 'SmartMonitoringSystem_Backups';

  factory GoogleDriveService() {
    return _instance;
  }

  GoogleDriveService._internal();

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  String? _backupFolderId;

  bool get isSupported => !Platform.isWindows;

  /// Initialize Google Sign In
  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: ['https://www.googleapis.com/auth/drive.file'],
    );
    return _googleSignIn!;
  }

  /// Check if user is signed in
  Future<bool> isSignedIn() async {
    if (!isSupported) return false;
    final isSignedIn = await googleSignIn.isSignedIn();
    return isSignedIn;
  }

  /// Sign in with Google
  Future<bool> signIn() async {
    try {
      if (!isSupported) {
        debugPrint(
          'ℹ️ Google Drive backups are not supported on this platform',
        );
        return false;
      }

      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('❌ Google Sign-In cancelled by user');
        return false;
      }
      debugPrint('✅ Signed in as: ${account.email}');
      await _initializeDriveApi();
      await _getOrCreateBackupFolder();
      return true;
    } on PlatformException catch (e) {
      debugPrint('❌ Sign-in error (${e.code}): ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Sign-in error: $e');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!isSupported) return;
      await googleSignIn.signOut();
      _driveApi = null;
      _backupFolderId = null;
      debugPrint('✅ Signed out');
    } catch (e) {
      debugPrint('❌ Sign-out error: $e');
    }
  }

  /// Initialize Drive API
  Future<void> _initializeDriveApi() async {
    try {
      if (!isSupported) return;
      final account = googleSignIn.currentUser;
      if (account == null) return;

      final auth = await account.authentication;
      if (auth.accessToken == null) {
        debugPrint('❌ No access token available');
        return;
      }

      // Create authenticated HTTP client
      final httpClient = _AuthenticatedHttpClient(
        http.Client(),
        auth.accessToken!,
      );

      _driveApi = drive.DriveApi(httpClient);
      debugPrint('✅ Drive API initialized');
    } catch (e) {
      debugPrint('❌ Drive API init error: $e');
    }
  }

  /// Get or create app-specific backup folder
  Future<void> _getOrCreateBackupFolder() async {
    try {
      if (!isSupported) return;
      if (_driveApi == null) return;

      // Search for existing backup folder
      final query =
          "name = '$_appFolderName' and trashed = false and mimeType = 'application/vnd.google-apps.folder'";
      final result = await _driveApi!.files.list(q: query, spaces: 'drive');

      if (result.files != null && result.files!.isNotEmpty) {
        _backupFolderId = result.files!.first.id;
        debugPrint('✅ Found backup folder: $_backupFolderId');
        return;
      }

      // Create new backup folder
      final folder = drive.File(
        name: _appFolderName,
        mimeType: 'application/vnd.google-apps.folder',
      );

      final createdFolder = await _driveApi!.files.create(folder);
      _backupFolderId = createdFolder.id;
      debugPrint('✅ Created backup folder: $_backupFolderId');
    } catch (e) {
      debugPrint('❌ Folder creation error: $e');
    }
  }

  /// Upload backup file to Google Drive
  Future<bool> uploadBackup(File backupFile, String fileName) async {
    try {
      if (!isSupported || _driveApi == null || _backupFolderId == null) {
        debugPrint('❌ Drive API not initialized');
        return false;
      }

      final fileToUpload = drive.File(
        name: fileName,
        parents: [_backupFolderId!],
      );

      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());

      await _driveApi!.files.create(fileToUpload, uploadMedia: media);

      debugPrint('✅ Backup uploaded: $fileName');
      return true;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return false;
    }
  }

  /// Download backup file from Google Drive
  Future<Uint8List?> downloadBackup(String fileId) async {
    try {
      if (!isSupported || _driveApi == null) {
        debugPrint('❌ Drive API not initialized');
        return null;
      }

      final media =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final bytes = await _collectBytes(media.stream);
      debugPrint('✅ Backup downloaded: $fileId');
      return bytes;
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return null;
    }
  }

  /// List backup files from Google Drive
  Future<List<BackupFileInfo>> listBackups() async {
    try {
      if (!isSupported || _driveApi == null || _backupFolderId == null) {
        debugPrint('❌ Drive API not initialized');
        return [];
      }

      final query = "'$_backupFolderId' in parents and trashed = false";
      final result = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        orderBy: 'createdTime desc',
      );

      final files = <BackupFileInfo>[];
      if (result.files != null) {
        for (final file in result.files!) {
          files.add(
            BackupFileInfo(
              id: file.id!,
              name: file.name!,
              createdTime: file.createdTime,
              modifiedTime: file.modifiedTime,
              size: file.size,
            ),
          );
        }
      }

      debugPrint('✅ Listed ${files.length} backups');
      return files;
    } catch (e) {
      debugPrint('❌ List error: $e');
      return [];
    }
  }

  /// Delete backup file from Google Drive
  Future<bool> deleteBackup(String fileId) async {
    try {
      if (!isSupported || _driveApi == null) {
        debugPrint('❌ Drive API not initialized');
        return false;
      }

      await _driveApi!.files.delete(fileId);
      debugPrint('✅ Backup deleted: $fileId');
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  /// Helper to collect bytes from stream
  Future<Uint8List> _collectBytes(Stream<List<int>> stream) async {
    final chunks = <List<int>>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }
    return Uint8List.fromList(chunks.fold<List<int>>([], (a, b) => a + b));
  }

  /// Get current user email
  String? getCurrentUserEmail() {
    if (!isSupported) return null;
    return googleSignIn.currentUser?.email;
  }
}

/// Model for backup file info
class BackupFileInfo {
  final String id;
  final String name;
  final DateTime? createdTime;
  final DateTime? modifiedTime;
  final int? size;

  BackupFileInfo({
    required this.id,
    required this.name,
    this.createdTime,
    this.modifiedTime,
    dynamic size,
  }) : size = _parseSize(size);

  static int? _parseSize(dynamic sizeValue) {
    if (sizeValue == null) return null;
    if (sizeValue is int) return sizeValue;
    if (sizeValue is String) {
      try {
        return int.parse(sizeValue);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String get sizeDisplay {
    if (size == null) return 'Unknown';
    final mb = size! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String get createdDisplay {
    if (createdTime == null) return 'Unknown';
    return '${createdTime!.year}-${createdTime!.month.toString().padLeft(2, '0')}-${createdTime!.day.toString().padLeft(2, '0')} ${createdTime!.hour.toString().padLeft(2, '0')}:${createdTime!.minute.toString().padLeft(2, '0')}';
  }
}
