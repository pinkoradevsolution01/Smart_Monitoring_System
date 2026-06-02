# V380 Pro Camera Integration - Summary

## ✅ Implementation Complete

Your Smart Monitoring System now fully supports V380 Pro cameras with authenticated RTSP streaming!

## What Was Added

### 1. **Camera Model Enhancement** (`lib/models/camera.dart`)
- Added `username` and `password` fields for authentication
- Added `getAuthenticatedUrl()` method to build RTSP URLs with embedded credentials
- Supports all camera types: RTSP, HTTP, HTTPS, and V380 Pro

### 2. **V380 Pro Configuration** (`lib/services/cctv_config.dart`)
- Added V380 Pro presets (Main Stream and Sub Stream)
- Added `v380Config` with default settings
- Added `buildV380Url()` helper method for easy URL generation
- V380 Pro URLs automatically built from IP + credentials

### 3. **Database Schema Update** (`lib/services/database_service_io.dart`)
- Database version upgraded to **v8**
- Added `username` and `password` columns to `cameras` table
- Migration automatically handles existing installations

### 4. **Enhanced UI** (`lib/screens/owner/cctv_screen.dart`)
- Camera Brand dropdown with V380 Pro preset
- Automatic URL builder for V380 cameras
- Authentication fields (username/password)
- Option to toggle authentication for any camera
- Separate fields for V380: just enter IP address
- Manual URL entry still available for advanced users

### 5. **Documentation** (`V380_PRO_SETUP_GUIDE.md`)
- Complete setup guide for V380 Pro cameras
- Troubleshooting tips
- URL format examples
- Security best practices

## How to Use V380 Pro Cameras

### Quick Setup Steps:

1. **Find Your Camera's IP Address**
   - Use V380 Pro app → Settings → Device Information
   - Or check your router's connected devices
   - Example: `192.168.1.100`

2. **Add Camera in App**
   - Owner Dashboard → CCTV Monitoring
   - Click **+** button
   - Enter Camera Name (e.g., "Front Door")
   - Select **"V380 Pro"** from Camera Brand dropdown
   - Enter Camera IP: `192.168.1.100`
   - Username: `admin` (default)
   - Password: (your camera password)
   - Click **Add**

3. **Done!**
   - URL is automatically built as: `rtsp://admin:password@192.168.1.100:8554/live/main`
   - Test the connection
   - Start viewing your camera feed

## Technical Details

### V380 Pro Default Settings
- **RTSP Port:** 8554
- **Username:** admin
- **Password:** (blank or admin)
- **Main Stream:** `/live/main` (1080p)
- **Sub Stream:** `/live/sub` (480p)

### Supported URL Format
```
rtsp://username:password@camera-ip:8554/live/main
```

Example:
```
rtsp://admin:mypassword@192.168.1.100:8554/live/main
```

## Database Migration

The database will automatically migrate when you run the app:
- Old installations: Adds username/password columns
- New installations: Creates cameras table with all fields
- No data loss - existing cameras preserved

## Features

✅ **V380 Pro Preset** - One-click setup with just IP address
✅ **Authentication Support** - Secure RTSP with credentials
✅ **Multi-Stream** - Choose main (high quality) or sub (low bandwidth)
✅ **Backwards Compatible** - Works with existing cameras
✅ **Manual Override** - Can still enter custom RTSP URLs
✅ **Secure Storage** - Credentials saved in local database

## Offline Capability

**Important:** V380 Pro cameras require **local network (LAN)** connection:

✅ **Works Offline** (No Internet Required):
- Camera and device on same WiFi network
- Local RTSP streaming
- No cloud connection needed

❌ **Requires Network**:
- WiFi/LAN connection between device and camera
- Both must be on same network
- Cannot work completely offline (needs local network)

## Security Notes

1. **Credentials are stored locally** in encrypted SQLite database
2. **RTSP authentication** embedded in URL for secure streaming
3. **Change default passwords** for better security
4. **Local network only** - don't expose cameras to internet without VPN

## Testing Your Setup

### Test in VLC Player First (Recommended):
1. Download VLC Media Player
2. Media → Open Network Stream
3. Enter: `rtsp://admin:password@192.168.1.100:8554/live/main`
4. If video plays in VLC, configuration is correct!

### Test in App:
1. Add camera with V380 Pro preset
2. Tap on camera tile
3. Wait 5-10 seconds for connection
4. Video should appear

## Troubleshooting

### Camera Won't Connect
- ✅ Verify camera IP with ping test
- ✅ Check username/password (try blank password)
- ✅ Enable RTSP in V380 app settings
- ✅ Ensure both devices on same WiFi network
- ✅ Check port 8554 not blocked by firewall

### Video Quality Issues
- Use `/live/main` for high quality
- Use `/live/sub` for lower bandwidth
- Check WiFi signal strength

### Authentication Errors
- Verify credentials in V380 app
- Try blank password if default
- Ensure no spaces in username/password
- Test URL in VLC first

## Next Steps

1. **Run the app** to trigger database migration
2. **Add your V380 Pro camera** using the preset
3. **Test the connection**
4. **View live feed** from your camera

## Support

See `V380_PRO_SETUP_GUIDE.md` for:
- Detailed setup instructions
- Complete troubleshooting guide
- Security best practices
- Advanced configuration options

---

**Status:** ✅ Ready to use
**Database Version:** 8
**Camera Types Supported:** V380 Pro, RTSP, HTTP, HTTPS
**Authentication:** Fully supported
