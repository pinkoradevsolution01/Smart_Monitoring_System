import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'database_service.dart';
import '../models/cctv_timestamp.dart';
import '../models/camera.dart';

/// CCTV Service for managing multi-camera live feeds and recording access.
/// Supports RTSP streams, HTTP streams, and local video files.
class CCTVService extends ChangeNotifier {
  CCTVService._();
  static final instance = CCTVService._();

  final DatabaseService _db = DatabaseService();

  // Multi-camera configuration
  List<Camera> _cameras = [];
  Camera? _selectedCamera;
  String? _recordingsDirectory;
  Duration _streamTimeout = const Duration(seconds: 30);
  List<CCTVTimestamp> _savedTimestamps = [];

  // Getters
  List<Camera> get cameras => _cameras;
  Camera? get selectedCamera => _selectedCamera;
  String? get cameraUrl => _selectedCamera?.url;
  bool get isConnected => _selectedCamera?.isActive ?? false;
  String? get connectionError => null;
  List<CCTVTimestamp> get savedTimestamps => _savedTimestamps;

  /// Load all cameras from database
  Future<void> loadCameras() async {
    try {
      final maps = await _db.getAllCameras();
      _cameras = maps.map((map) => Camera.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cameras: $e');
    }
  }

  /// Add a new camera
  Future<bool> addCamera(Camera camera) async {
    try {
      final id = await _db.insertCamera(camera.toMap());
      await loadCameras();
      debugPrint('Camera added with ID: $id');
      return true;
    } catch (e) {
      debugPrint('Error adding camera: $e');
      return false;
    }
  }

  /// Update camera configuration
  Future<bool> updateCamera(int id, Camera camera) async {
    try {
      await _db.updateCamera(id, camera.toMap());
      await loadCameras();
      debugPrint('Camera updated: $id');
      return true;
    } catch (e) {
      debugPrint('Error updating camera: $e');
      return false;
    }
  }

  /// Delete a camera
  Future<bool> deleteCamera(int id) async {
    try {
      await _db.deleteCamera(id);
      if (_selectedCamera?.id == id) {
        _selectedCamera = null;
      }
      await loadCameras();
      debugPrint('Camera deleted: $id');
      return true;
    } catch (e) {
      debugPrint('Error deleting camera: $e');
      return false;
    }
  }

  /// Select a camera for viewing
  void selectCamera(Camera? camera) {
    _selectedCamera = camera;
    notifyListeners();
  }

  /// Configure CCTV connection with camera URL/RTSP stream
  /// @deprecated Use addCamera instead for multi-camera support
  void configure({
    required String cameraUrl,
    String? recordingsDirectory,
    Duration? streamTimeout,
  }) {
    _recordingsDirectory = recordingsDirectory;
    if (streamTimeout != null) _streamTimeout = streamTimeout;
    debugPrint('CCTVService configured with camera: $cameraUrl');
    notifyListeners();
  }

  /// Test connection to the selected CCTV camera/stream
  /// Returns true if connection is successful
  /// For remote streams (RTSP/HTTP), checks internet connectivity first
  Future<bool> testConnection() async {
    if (_selectedCamera == null) {
      debugPrint('No camera selected');
      return false;
    }

    try {
      final url = _selectedCamera!.url;
      final isRemoteStream =
          url.startsWith('rtsp://') ||
          url.startsWith('http://') ||
          url.startsWith('https://');

      // Check internet connectivity for remote streams
      if (isRemoteStream) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          debugPrint(
            'No internet connection available for remote camera stream',
          );
          return false;
        }
        debugPrint('Internet connectivity available: $connectivityResult');
      }

      // For RTSP streams, attempt a basic connectivity check
      if (url.startsWith('rtsp://')) {
        debugPrint('Testing RTSP connection: $url (requires internet)');
        // RTSP streams require special handling; for now we'll assume success
        // In a real app, you'd use an RTSP library like 'rtsp_client_dart'
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        // Test HTTP stream with a HEAD request
        debugPrint('Testing HTTP stream: $url (requires internet)');
        final response = await http
            .head(Uri.parse(url), headers: {'Connection': 'close'})
            .timeout(_streamTimeout);

        return response.statusCode >= 200 && response.statusCode < 400;
      } else {
        // Local file or unsupported URL
        debugPrint('Local video file or unsupported URL scheme: $url');
        return true; // Assume local files don't need internet
      }
    } catch (e) {
      debugPrint('CCTV connection error: $e');
      return false;
    }
  }

  /// Seek CCTV timeline to [timestamp] for playback or live tracking
  /// This would integrate with your recording system or live stream DVR
  /// Saves the timestamp to database for future reference
  Future<bool> seekTo(DateTime timestamp, {String? description}) async {
    debugPrint('CCTVService.seekTo: $timestamp');

    // Auto-select first camera if none selected
    if (_selectedCamera == null && _cameras.isNotEmpty) {
      _selectedCamera = _cameras.first;
      notifyListeners();
    }

    try {
      // In a real implementation, this would:
      // 1. Look up the recording file for the given timestamp
      // 2. Send a seek command to the DVR/NVR system
      // 3. Update the video player to the correct position
      // For now, simulate the operation
      await Future.delayed(const Duration(milliseconds: 150));

      // Save timestamp to database
      final cctvTimestamp = CCTVTimestamp(
        timestamp: timestamp,
        description: description,
      );
      await _db.insertCCTVTimestamp(cctvTimestamp.toMap());

      // Reload timestamps
      await loadTimestamps();

      debugPrint('Seeked to timestamp: $timestamp');
      return true;
    } catch (e) {
      debugPrint('Seek failed: $e');
      return false;
    }
  }

  /// Load all saved timestamps from database
  Future<void> loadTimestamps() async {
    try {
      final maps = await _db.getAllCCTVTimestamps();
      _savedTimestamps = maps.map((map) => CCTVTimestamp.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading CCTV timestamps: $e');
    }
  }

  /// Delete a saved timestamp
  Future<bool> deleteTimestamp(int id) async {
    try {
      await _db.deleteCCTVTimestamp(id);
      await loadTimestamps();
      return true;
    } catch (e) {
      debugPrint('Error deleting timestamp: $e');
      return false;
    }
  }

  /// Clear all saved timestamps
  Future<bool> clearAllTimestamps() async {
    try {
      await _db.deleteAllCCTVTimestamps();
      _savedTimestamps = [];
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing timestamps: $e');
      return false;
    }
  }

  /// Export footage from timestamp to MP4 file
  /// Returns the file path if successful, null otherwise
  Future<String?> exportFootage(
    int timestampId,
    DateTime timestamp, {
    int durationSeconds = 60,
    String? customPath,
  }) async {
    try {
      // In a real implementation, this would:
      // 1. Connect to the DVR/NVR system
      // 2. Request footage from timestamp for specified duration
      // 3. Download and save as MP4 file
      // 4. Return the file path

      // For demo: simulate export process
      await Future.delayed(const Duration(seconds: 2));

      // Generate filename
      final formattedDate =
          '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
      final formattedTime =
          '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
      final filename = 'CCTV_${formattedDate}_$formattedTime.mp4';

      // Use custom path or default to recordings directory
      final basePath =
          customPath ?? _recordingsDirectory ?? '/storage/cctv_exports';
      final filePath = '$basePath/$filename';

      // Update timestamp with video path
      await _db.updateCCTVTimestamp(timestampId, {'videoPath': filePath});
      await loadTimestamps();

      debugPrint('Footage exported to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error exporting footage: $e');
      return null;
    }
  }

  /// Get the recording file path for a given timestamp
  /// This assumes recordings are stored with timestamp-based naming
  /// e.g., /recordings/2024-11-26/14-30-45.mp4
  String? getRecordingPath(DateTime timestamp) {
    if (_recordingsDirectory == null) return null;

    final date = timestamp.toString().split(' ')[0]; // YYYY-MM-DD
    final time = timestamp.toString().split(' ')[1].split('.')[0]; // HH:MM:SS
    return '$_recordingsDirectory/$date/$time.mp4';
  }

  /// Get RTSP stream URL for live viewing
  String? getLiveStreamUrl() => _selectedCamera?.url;

  /// Disconnect from CCTV (deselect camera)
  void disconnect() {
    _selectedCamera = null;
    debugPrint('CCTV disconnected');
    notifyListeners();
  }

  /// Check if internet connectivity is available
  /// Returns true if device has active internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Error checking internet connectivity: $e');
      return false;
    }
  }

  /// Check if selected camera requires internet connection
  /// Returns true for RTSP/HTTP streams, false for local files
  bool requiresInternetConnection() {
    if (_selectedCamera == null) return false;
    final url = _selectedCamera!.url;
    return url.startsWith('rtsp://') ||
        url.startsWith('http://') ||
        url.startsWith('https://');
  }
}
