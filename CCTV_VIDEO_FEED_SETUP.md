# CCTV Real Video Feed Implementation

## ✅ Changes Completed

### 1. Added Dependencies
- **flutter_vlc_player**: ^7.4.2 - Primary player for RTSP/HTTP/HTTPS streams
- Provides excellent RTSP support with hardware acceleration on Android/iOS

### 2. Created Video Feed Widgets

#### `lib/widgets/camera_feed_widget.dart`
- Main widget using VLC player for robust streaming
- Features:
  - Auto-connects to camera streams with authentication support
  - Hardware acceleration enabled for smooth playback
  - Network caching optimizations (1000ms buffer)
  - Live indicator overlay
  - Camera name display
  - Automatic error handling with retry button
  - Loading states with progress indicator
  - Connection error messages

#### `lib/widgets/camera_feed_fallback.dart`
- Backup widget using video_player
- Use when VLC player is unavailable or for HTTP streams
- Note: Limited RTSP support on iOS/Web

### 3. Updated CCTV Screen
- Replaced all placeholder UI with real video feeds
- Grid view now shows live camera feeds
- Fullscreen view displays actual video stream
- Both views use the new `CameraFeedWidget`

## 📋 Next Steps

### 1. Install Dependencies
Run in terminal:
```bash
flutter pub get
```

### 2. Platform-Specific Setup

#### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

#### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 3. Configure Your Cameras

Use the "Add Camera" dialog in CCTV screen to add your cameras with:
- **Camera Name**: e.g., "Front Entrance", "Cashier Area"
- **Camera Type**: Select RTSP, HTTP, HTTPS, or V380 Pro
- **Camera URL**: Your camera's stream URL
  - RTSP: `rtsp://192.168.1.100:554/stream`
  - HTTP: `http://192.168.1.100:8080/video.mjpg`
  - V380 Pro: Auto-generated when using V380 builder
- **Authentication**: Check "Requires Authentication" if your camera needs credentials

### 4. Test Your Camera Streams

1. Open CCTV Monitoring screen
2. Add a camera with your actual camera URL
3. Tap on the camera tile to view fullscreen
4. If connection fails, check:
   - Camera is powered on and connected to network
   - IP address is correct
   - Port is accessible
   - Credentials are correct (if using authentication)
   - Your device is on the same network as the camera

## 🔧 Troubleshooting

### "Stream connection failed"
- **Check network**: Ensure device and camera are on same network
- **Verify URL**: Test camera URL in VLC desktop player first
- **Firewall**: Check if firewall is blocking camera port
- **Camera settings**: Enable RTSP/HTTP streaming in camera settings

### "RTSP streams not supported on this platform"
- iOS/Web have limited RTSP support with video_player
- Use HTTP/HTTPS streams instead
- Or use flutter_vlc_player (already implemented)

### Slow loading or buffering
- Reduce stream quality in camera settings (use sub-stream)
- Check network bandwidth
- Increase buffer size in `VlcAdvancedOptions.networkCaching()`

### Camera not appearing
- Check camera is powered and connected
- Verify IP address hasn't changed (use static IP)
- Test with ping command: `ping 192.168.1.100`
- Check camera manufacturer's app for stream URL

## 📚 Supported Camera Formats

### Working Stream Types:
- ✅ RTSP (Real-Time Streaming Protocol)
- ✅ HTTP/HTTPS streams
- ✅ MJPEG streams
- ✅ V380 Pro cameras

### Recommended Settings:
- **Resolution**: 720p or 1080p (sub-stream for low bandwidth)
- **FPS**: 15-30 fps
- **Codec**: H.264 or H.265
- **Protocol**: RTSP over TCP (more reliable than UDP)

## 🎥 Example Camera URLs

```dart
// Hikvision
rtsp://admin:password@192.168.1.64:554/Streaming/Channels/101

// Dahua
rtsp://admin:password@192.168.1.108:554/cam/realmonitor?channel=1&subtype=0

// V380 Pro
rtsp://admin:password@192.168.1.100:8554/live/main

// Generic MJPEG
http://192.168.1.100:8080/video.mjpg

// Public test stream
rtsp://demo.openfusion.net:554/stream
```

## 🔐 Security Notes

- Credentials are stored in local database (encrypted in production)
- Use strong passwords for camera accounts
- Consider VPN for remote access
- Keep camera firmware updated
- Disable UPnP on cameras if not needed

## 📱 Performance Tips

1. **Use sub-streams** for grid view (lower quality, less bandwidth)
2. **Use main stream** only in fullscreen mode
3. **Limit simultaneous streams** to 4-6 cameras
4. **Enable hardware acceleration** (already configured)
5. **Use wired connection** for camera when possible

## 🚀 Future Enhancements

- [ ] Record video to local storage
- [ ] Motion detection alerts
- [ ] PTZ (Pan-Tilt-Zoom) controls
- [ ] Two-way audio
- [ ] Cloud recording integration
- [ ] AI object detection
- [ ] Multi-camera sync playback
