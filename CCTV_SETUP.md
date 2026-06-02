# CCTV Integration Guide

This document explains how to configure and use the real CCTV monitoring system in Smart Monitoring System.

## Overview

The CCTV module provides:
- **Live Stream Support**: RTSP and HTTP video streams from IP cameras
- **Timestamp-based Seek**: Jump to specific moments in recorded footage from sales timestamps
- **Configuration Management**: Easy setup and connection testing
- **Multi-platform Support**: Works on Windows, Linux, macOS, Android, and iOS

## Features

### 1. **Live CCTV Monitoring**
- Connect to IP cameras via RTSP or HTTP streams
- View live feed directly in the owner dashboard
- Real-time connection status indicators

### 2. **Sales-to-CCTV Linking**
- Each sale in the cashier POS log can be linked to CCTV timestamp
- Owner can click the camera icon to view corresponding footage
- Automatic timestamp tracking

### 3. **Connection Management**
- Test camera connectivity before deployment
- Connection error reporting
- Automatic fallback handling

## Setup Instructions

### Step 1: Configure Your CCTV Camera

#### Option A: Using a Public Demo Camera (Testing)
The system comes pre-configured with a public demo RTSP stream. Navigate to the CCTV screen and test the connection—no setup needed!

#### Option B: Connect Your IP Camera

1. **Get Your Camera's RTSP URL**:
   - Local network cameras (recommended):
     ```
     rtsp://192.168.1.100:554/stream
     ```
     Replace `192.168.1.100` with your camera's IP address

   - Find your camera's IP:
     - Check your router's connected devices
     - Open the camera's web interface
     - Use a network scanner app

2. **Common RTSP URL Formats by Brand**:

   | Brand | RTSP URL Format |
   |-------|-----------------|
   | Hikvision | `rtsp://IP:554/Streaming/Channels/101` |
   | Dahua | `rtsp://IP:554/stream` |
   | Axis | `rtsp://IP:554/axis-media/media.amp` |
   | Uniview | `rtsp://IP:554/stream` |
   | Amcrest | `rtsp://IP:554/cam/realmonitor` |
   | Reolink | `rtsp://IP:554/h264Preview_01_main` |

3. **Configuration in App**:
   - Open Owner Dashboard → CCTV Monitoring
   - Click Settings icon (⚙️)
   - Enter your Camera URL
   - (Optional) Enter recordings directory path
   - Click "Test Connection"
   - If successful, you'll see a ✓ green indicator

### Step 2: Set Up Recordings Directory (Optional)

If you have pre-recorded footage stored on disk:

1. **Create a recordings folder** with this structure:
   ```
   /recordings/
   ├── 2024-11-26/
   │   ├── 14-30-45.mp4  (timestamp: 2:30:45 PM)
   │   ├── 14-45-00.mp4
   │   └── ...
   ├── 2024-11-25/
   │   └── ...
   ```

2. **Set the path in CCTV settings**:
   - Windows: `C:\surveillance\recordings`
   - Linux: `/home/user/surveillance/recordings`
   - macOS: `/Users/user/surveillance/recordings`

### Step 3: Access CCTV from POS

1. **Owner Dashboard**:
   - Navigate to CCTV Monitoring screen
   - Configure and test connection
   - View live feed

2. **From Cashier Sales Log**:
   - Cashier POS → Sales Log (history icon)
   - Click camera icon next to any sale
   - Automatically opens CCTV screen with sale timestamp
   - Click "Seek to Timestamp" to jump to that moment

## API Reference

### CCTVService

```dart
// Get the singleton instance
CCTVService service = CCTVService.instance;

// Configure connection
service.configure(
  cameraUrl: 'rtsp://192.168.1.100:554/stream',
  recordingsDirectory: '/recordings',
  streamTimeout: Duration(seconds: 30),
);

// Test connection
bool success = await service.testConnection();

// Check connection status
bool isConnected = service.isConnected;
String? error = service.connectionError;

// Seek to timestamp (for DVR/NVR systems)
bool seeked = await service.seekTo(DateTime.now());

// Get recording path for timestamp
String? recordingPath = service.getRecordingPath(DateTime.now());

// Get live stream URL
String? liveUrl = service.getLiveStreamUrl();

// Disconnect
service.disconnect();

// Listen to connection changes
service.addListener(() {
  print('CCTV state changed: ${service.isConnected}');
});
```

### CCTVConfig

```dart
// Access demo URLs
String demoUrl = CCTVConfig.defaultCameraUrl;

// Validate camera URL
bool valid = CCTVConfig.isValidCameraUrl('rtsp://192.168.1.100:554/stream');

// Get example URLs by brand
String? hikvisionUrl = CCTVConfig.getExampleUrl('Hikvision');

// Get all supported brands
List<String> brands = CCTVConfig.getSupportedBrands();
```

## Troubleshooting

### Connection Failed

**Problem**: "Connection failed" or timeout error

**Solutions**:
1. **Check camera IP address**:
   ```bash
   # Windows: Open Command Prompt
   ping 192.168.1.100
   ```

2. **Verify RTSP port is open** (default: 554):
   - Check camera network settings
   - Verify firewall isn't blocking port 554
   - Some cameras use port 8554 instead

3. **Test with VLC Media Player**:
   - Open VLC → Media → Open Network Stream
   - Enter your RTSP URL
   - If VLC can't connect, the camera URL is incorrect

4. **Try HTTP instead of RTSP**:
   ```
   http://192.168.1.100:8080/video.mjpg
   ```

### No Video Display

**Problem**: Connected but no video showing

**Current Limitation**: The UI currently shows connection status only. To display actual video:

1. Add `video_player` package (already in pubspec.yaml)
2. Implement video player in `_buildLiveStreamPreview()`:
   ```dart
   VideoPlayer(_controller);
   ```

3. For RTSP streams on Flutter web, use HLS/MJPEG workaround or server-side transcoding

### Timestamp Seeking Not Working

**Problem**: "Seek to Timestamp" button doesn't seek

**Reasons**:
1. Your system doesn't have DVR/NVR capabilities
2. Recordings aren't stored or not accessible
3. Recording filename format doesn't match expected pattern

**Solutions**:
- Implement custom `seekTo()` logic in `CCTVService` for your specific system
- Contact your camera manufacturer for API documentation
- Use a separate DVR management system for playback

## Advanced Integration

### Custom Camera Systems

To integrate with proprietary CCTV systems, extend `CCTVService`:

```dart
class MyCustomCCTVService extends CCTVService {
  @override
  Future<bool> testConnection() async {
    // Custom connection logic
    // Call your camera API
    // Update _isConnected and _connectionError
    notifyListeners();
    return _isConnected;
  }

  @override
  Future<bool> seekTo(DateTime timestamp) async {
    // Custom seek logic
    // Send command to your DVR/NVR system
    return true;
  }
}
```

### Real-time Video Integration

To display live video (web requires HLS/MJPEG):

```dart
// For native platforms (Android/iOS):
// Use video_player package with RTSP URL

// For web:
// Convert RTSP to HLS using FFmpeg or use MJPEG stream
// Or use platform channels for native RTSP handling
```

### Database Recording Links

To store CCTV recordings linked to sales:

```dart
// In database_service.dart, add:
INSERT INTO sales (id, timestamp, cctv_recording_path, ...)
VALUES (?, ?, '/recordings/2024-11-26/14-30-45.mp4', ...)

// Modify CCTVService to fetch recording for sale timestamp
String? getRecordingForSale(Sale sale) {
  return getRecordingPath(sale.saleDate);
}
```

## Security Considerations

⚠️ **Important**: When deploying to production:

1. **Use HTTPS/Secure RTSP**:
   - `rtsps://` for encrypted RTSP
   - `https://` for HTTP streams
   - Requires camera support

2. **Network Security**:
   - Keep cameras on isolated network segment
   - Use firewall rules to restrict access
   - Change default camera credentials

3. **API Authentication**:
   - Some cameras require username/password
   - Extend `CCTVService` to handle auth headers:
     ```dart
     headers: {
       'Authorization': 'Basic ' + base64.encode(utf8.encode('user:pass'))
     }
     ```

4. **Recording Storage**:
   - Encrypt recordings at rest
   - Implement proper access controls
   - Comply with local data protection regulations (GDPR, CCPA, etc.)

## Support

For issues or feature requests:
1. Check this guide's Troubleshooting section
2. Consult your camera manufacturer's documentation
3. Review Flutter video_player and camera package documentation

## Next Steps

- [ ] Test CCTV connection with your actual camera
- [ ] Configure recordings directory if using DVR
- [ ] Implement live video display (if needed)
- [ ] Set up security authentication
- [ ] Test timestamp seeking with recorded footage
