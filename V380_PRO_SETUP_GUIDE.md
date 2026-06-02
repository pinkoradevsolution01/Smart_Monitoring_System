 # V380 Pro Camera Setup Guide

This guide will help you connect your V380 Pro camera to the Smart Monitoring System.

## Overview

V380 Pro cameras are popular WiFi security cameras that support RTSP streaming. This app now has built-in support for V380 Pro cameras with easy configuration.

## Prerequisites

1. **V380 Pro Camera** properly set up and connected to your WiFi network
2. **Same Network**: Your device running this app must be on the same WiFi network as the camera
3. **Camera IP Address**: You need to know your camera's local IP address
4. **Camera Credentials**: Username and password (default is usually `admin` with blank or `admin` password)

## Finding Your Camera's IP Address

### Method 1: Using V380 Pro Mobile App
1. Open the V380 Pro app on your phone
2. Select your camera
3. Go to **Settings** → **Device Information**
4. Note the **IP Address** (e.g., `192.168.1.100`)

### Method 2: Using Your Router
1. Log into your router's admin panel (usually `192.168.1.1` or `192.168.0.1`)
2. Look for **Connected Devices** or **DHCP Client List**
3. Find your V380 camera in the list (may show as "IPC" or "V380")
4. Note its IP address

### Method 3: Network Scanner App
1. Download a network scanner app (e.g., Fing, IP Scanner)
2. Scan your network
3. Look for devices with manufacturer name containing "Macro" or "V380"
4. Note the IP address

## Adding V380 Pro Camera to the App

### Quick Setup (Recommended)

1. **Open CCTV Monitoring**
   - From Owner Dashboard → CCTV Monitoring
   - Click the **+** button to add a camera

2. **Select V380 Pro Preset**
   - Camera Name: Enter a friendly name (e.g., "Front Door V380")
   - Camera Brand: Select **"V380 Pro"** from dropdown
   - Camera IP Address: Enter your camera's IP (e.g., `192.168.1.100`)

3. **Enter Credentials**
   - Username: Enter `admin` (or your custom username)
   - Password: Enter your camera password

4. **Save and Test**
   - Click **Add**
   - The app will automatically build the correct RTSP URL
   - Test the connection by selecting the camera

### Manual URL Setup (Advanced)

If you prefer to enter the URL manually:

1. **Add Camera**
   - Camera Name: Enter a name
   - Camera Brand: Select **"Custom URL"**
   - Camera Type: Select **RTSP**

2. **Enter RTSP URL**
   
   **Format with authentication:**
   ```
   rtsp://admin:password@192.168.1.100:8554/live/main
   ```
   
   **Format without authentication:**
   ```
   rtsp://192.168.1.100:8554/live/main
   ```
   
   Replace:
   - `admin` with your username
   - `password` with your password
   - `192.168.1.100` with your camera's IP address

3. **Check "Requires Authentication"** and enter credentials separately

## V380 Pro RTSP URLs

V380 Pro cameras typically use these stream paths:

| Stream | Quality | URL Path |
|--------|---------|----------|
| Main Stream | High Quality (1080p) | `/live/main` |
| Sub Stream | Lower Quality (480p) | `/live/sub` |

**Default Port:** `8554`

### Complete URL Examples

**Main Stream (High Quality):**
```
rtsp://admin:yourpassword@192.168.1.100:8554/live/main
```

**Sub Stream (Lower Bandwidth):**
```
rtsp://admin:yourpassword@192.168.1.100:8554/live/sub
```

## Common V380 Pro Settings

| Setting | Default Value |
|---------|---------------|
| Username | `admin` |
| Password | *(blank)* or `admin` |
| RTSP Port | `8554` |
| HTTP Port | `80` |

## Troubleshooting

### Camera Not Connecting

1. **Verify IP Address**
   - Ping the camera: `ping 192.168.1.100`
   - Ensure it responds

2. **Check Credentials**
   - Default username is usually `admin`
   - Try blank password first, then `admin`
   - Check if you changed credentials in V380 app

3. **Enable RTSP in V380 App**
   - Some V380 cameras require RTSP to be enabled
   - Open V380 app → Settings → Enable RTSP

4. **Firewall/Port Blocking**
   - Ensure port 8554 is not blocked
   - Try temporarily disabling firewall

5. **Network Issues**
   - Ensure device and camera are on same WiFi network
   - Check if your network allows device-to-device communication
   - Some guest networks block local connections

### Video Quality Issues

**For Better Quality:**
- Use Main Stream (`/live/main`)
- Ensure strong WiFi signal
- Reduce compression in V380 app settings

**For Lower Bandwidth:**
- Use Sub Stream (`/live/sub`)
- Better for remote viewing or slow networks

### Authentication Errors

1. **Reset Camera Password**
   - Use V380 app to reset password
   - Or press reset button on camera (10 seconds)

2. **URL Format**
   - Ensure credentials are embedded: `rtsp://user:pass@ip:port/path`
   - No spaces in username or password
   - Special characters in password may need URL encoding

3. **Test in VLC Player**
   - Open VLC → Media → Open Network Stream
   - Enter your RTSP URL
   - If it works in VLC, the URL is correct

## Testing Your Connection

### Using VLC Media Player (Recommended)

1. Download VLC: https://www.videolan.org/
2. Open VLC → Media → Open Network Stream
3. Enter your RTSP URL:
   ```
   rtsp://admin:password@192.168.1.100:8554/live/main
   ```
4. Click Play
5. If video appears, your configuration is correct!

### Using the App

1. Add your camera following steps above
2. Tap on the camera tile
3. Wait for connection (may take 5-10 seconds)
4. Video should appear if configured correctly

## Advanced Configuration

### Static IP for Camera (Recommended)

To prevent IP address changes:

1. **Access Router Settings**
2. **DHCP Reservation** or **Static IP Binding**
3. Assign a fixed IP to your camera's MAC address
4. Camera will always use the same IP

### Port Forwarding (Remote Access)

⚠️ **Security Warning:** Only do this if you need remote access and understand the risks.

1. **Router Settings** → Port Forwarding
2. Forward external port (e.g., 8554) to camera IP
3. Access remotely: `rtsp://username:password@your-public-ip:8554/live/main`
4. **Strongly recommended:** Change default credentials first

### Multiple V380 Cameras

You can add multiple V380 cameras:

1. Each camera needs a unique IP address
2. Add them one by one with different names
3. View all cameras in a grid layout
4. Switch between cameras in the app

## Security Best Practices

1. ✅ **Change Default Password** - Don't use `admin` or blank
2. ✅ **Use Strong Password** - Mix of letters, numbers, symbols
3. ✅ **Local Network Only** - Don't expose to internet if possible
4. ✅ **Regular Firmware Updates** - Check V380 app for updates
5. ✅ **Disable Unused Features** - If you don't need cloud, disable it

## Need Help?

### Camera-Specific Issues
- Check V380 Pro app and documentation
- Visit V380 support forums
- Contact camera manufacturer

### App Issues
- Check if camera works in VLC first
- Verify URL format matches examples above
- Ensure database has been updated (version 8)

## Quick Reference

### V380 Pro Quick Add Checklist

- [ ] Camera on WiFi and powered on
- [ ] Know camera IP address
- [ ] Know username and password
- [ ] On same network as camera
- [ ] Selected "V380 Pro" from dropdown
- [ ] Entered IP, username, password
- [ ] Saved and tested connection

### V380 Pro URL Template

```
rtsp://[username]:[password]@[camera-ip]:8554/live/[main|sub]
```

**Example:**
```
rtsp://admin:mypassword@192.168.1.100:8554/live/main
```

## What's New

- ✅ V380 Pro preset with auto-URL generation
- ✅ Authentication support for RTSP cameras
- ✅ Easy IP-based configuration
- ✅ Main/Sub stream selection
- ✅ Secure credential storage

---

**Last Updated:** December 2025
**App Version:** 1.0.0+1
**Compatible with:** V380 Pro WiFi cameras with RTSP support
