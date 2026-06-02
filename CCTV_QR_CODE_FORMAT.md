# CCTV QR Code Format Guide

## Supported QR Code Formats

The system supports scanning QR codes from CCTV devices in multiple formats:

### 1. Direct URL Format (Simplest)
```
rtsp://192.168.1.100:554/stream
```
or
```
http://192.168.1.100:8080/video.mjpg
```

### 2. JSON Format (Most Common)
```json
{"ip":"192.168.1.100","port":"554","path":"/stream","user":"admin","pass":"12345","name":"Front Camera"}
```

**Fields:**
- `ip` (required) - Camera IP address
- `port` (optional, default: 554) - RTSP port
- `path` (optional, default: /stream) - Stream path
- `user` / `username` (optional) - Authentication username
- `pass` / `password` (optional) - Authentication password
- `name` (optional) - Suggested camera name

### 3. Key-Value Format
```
ip=192.168.1.100&port=554&path=/stream&user=admin&pass=12345&name=Front Camera
```

## How to Use

### In Mobile App:
1. Go to **CCTV Monitoring Screen**
2. Tap **"Add Camera"** button
3. Tap the **QR Scanner icon** (📷) in the dialog header
4. Point your camera at the CCTV device's QR code
5. The app will automatically parse and fill in the camera details
6. Review and confirm the camera name
7. Tap **"Add Camera"** to save

### QR Code Tips:
- ✅ Make sure QR code is clearly visible and well-lit
- ✅ Hold steady for 1-2 seconds
- ✅ Most IP cameras have QR codes on the device label or in the manual
- ✅ Some cameras provide QR codes in their web interface

## Camera Brand Examples

### V380 Pro QR Format:
```json
{"ip":"192.168.1.100","port":"8554","path":"/live/main","user":"admin","pass":""}
```

### Hikvision QR Format:
```json
{"ip":"192.168.1.100","port":"554","path":"/Streaming/Channels/101","user":"admin","pass":"12345"}
```

### Generic RTSP Camera:
```
rtsp://admin:12345@192.168.1.100:554/stream
```

## Generating QR Codes

If your camera doesn't have a QR code, you can generate one:

1. Visit a QR code generator website (e.g., qr-code-generator.com)
2. Choose "Text" type
3. Enter your camera URL in one of the formats above
4. Generate and print the QR code
5. Place it on or near your camera for easy scanning

## Troubleshooting

**QR code not scanning?**
- Ensure good lighting 
- Clean camera lens
- Hold phone steady 
- Try different angles
- QR code might be too small or damaged

**"Invalid QR code format" error?**
- Make sure the QR code contains camera connection information
- Verify the format matches one of the supported formats above
- Try entering details manually using "Add Camera" form

**Camera added but not connecting?**
- Verify camera is powered on
-   