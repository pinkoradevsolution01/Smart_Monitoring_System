/// CCTV Configuration defaults and helpers
class CCTVConfig {
  /// Default RTSP camera URL (example)
  /// Replace with your actual camera IP and stream URL
  static const String defaultCameraUrl =
      'rtsp://demo.openfusion.net:554/stream'; // Public demo stream

  /// Default recordings directory
  /// On different platforms:
  /// - Windows: C:\surveillance\recordings
  /// - Linux: /home/user/surveillance/recordings
  /// - macOS: /Users/user/surveillance/recordings
  /// - Android: /storage/emulated/0/CCTV/recordings
  /// - iOS: Documents/CCTV/recordings (app sandbox)
  static const String defaultRecordingsDir = '/recordings';

  /// Stream connection timeout (seconds)
  static const int streamTimeoutSeconds = 30;

  /// Supported camera URLs format:
  /// RTSP: rtsp://192.168.1.100:554/stream
  /// HTTP: http://192.168.1.100:8080/video.mjpg
  /// HTTPS: https://camera.example.com/stream
  static bool isValidCameraUrl(String url) {
    return url.startsWith('rtsp://') ||
        url.startsWith('http://') ||
        url.startsWith('https://');
  }

  /// Common RTSP camera manufacturers and their URLs
  static const Map<String, String> commonCameraUrls = {
    'Hikvision': 'rtsp://192.168.1.100:554/Streaming/Channels/101',
    'Dahua': 'rtsp://192.168.1.100:554/stream',
    'Axis': 'rtsp://192.168.1.100:554/axis-media/media.amp',
    'Uniview': 'rtsp://192.168.1.100:554/stream',
    'Amcrest': 'rtsp://192.168.1.100:554/cam/realmonitor',
    'Reolink': 'rtsp://192.168.1.100:554/h264Preview_01_main',
    'V380 Pro': 'rtsp://192.168.1.100:8554/live/main',
    'V380 Pro (Sub)': 'rtsp://192.168.1.100:8554/live/sub',
  };

  /// V380 Pro specific configuration
  static const Map<String, dynamic> v380Config = {
    'defaultPort': 8554,
    'mainStreamPath': '/live/main',
    'subStreamPath': '/live/sub',
    'defaultUsername': 'admin',
    'defaultPassword': '',
    'requiresAuth': true,
  };

  /// Build V380 Pro RTSP URL
  /// @param ip Camera IP address (e.g., '192.168.1.100')
  /// @param username Camera username (default: 'admin')
  /// @param password Camera password
  /// @param useSubStream Use sub-stream (lower quality) instead of main stream
  /// @param port RTSP port (default: 8554)
  static String buildV380Url({
    required String ip,
    String username = 'admin',
    String password = '',
    bool useSubStream = false,
    int port = 8554,
  }) {
    final path = useSubStream
        ? v380Config['subStreamPath']
        : v380Config['mainStreamPath'];

    if (username.isNotEmpty) {
      return 'rtsp://$username:$password@$ip:$port$path';
    }
    return 'rtsp://$ip:$port$path';
  }

  /// Get example URL for a camera brand
  static String? getExampleUrl(String brand) => commonCameraUrls[brand];

  /// Get all available camera brands
  static List<String> getSupportedBrands() => commonCameraUrls.keys.toList();
}
