# Backup & Restore Feature - Setup Guide

## Overview
The backup and restore feature now includes support for:
- **Local Backups**: Save backups to the local device storage (automatic daily backups)
- **Google Drive Backups**: Upload backups to Google Drive for cross-device access
- **Smart Restore**: Restore from local backups, Google Drive, or select custom backup files

## Features

### ✅ Automatic Local Backups
- Automatically created daily
- Kept for 7 days
- Accessible from the "Local Backups" list
- No configuration needed

### ✅ Manual Local Backups
- Create on demand via "Create Backup" button
- Store in local Documents folder
- Quick restore from latest local backup

### ✅ Google Drive Cloud Backups
- Upload backups to Google Drive
- Access backups across different devices
- Restore from Google Drive backup files
- Delete old cloud backups

### ✅ Export & Restore
- Export backup to custom folder
- Restore from custom file location
- Works across different devices when files are transferred

## Setup Instructions

### 1. Google Drive Configuration (One-time Setup)

#### For Development:
```bash
# No additional setup needed for testing
# The app uses Google Sign-In plugin
```

#### For Production Deployment:

**Step 1: Create Google Cloud Project**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project
3. Enable the Google Drive API
4. Create OAuth 2.0 credentials:
   - Type: Web application
   - Authorized JavaScript origins: Add your app domain
   - Authorized redirect URIs: Add your app's OAuth callback URL

**Step 2: Configure Android**
1. Go to Google Cloud Console > Credentials
2. Create OAuth 2.0 credentials for Android
3. Add SHA-1 fingerprint of your debug/release keystore
4. Download the credentials JSON
5. Update `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <application>
       <meta-data
           android:name="com.google.android.gms.version"
           android:value="@integer/google_play_services_version" />
   </application>
   ```

**Step 3: Configure iOS**
1. Download the OAuth 2.0 credentials for iOS
2. Add to `ios/Runner/GoogleService-Info.plist`
3. Update `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.googleusercontent.apps.YOUR_APP_ID</string>
           </array>
       </dict>
   </array>
   ```

**Step 4: Configure Web**
1. Add web origin to Google Cloud Console
2. Initialize Google Sign-In in your web config

### 2. Using the Backup & Restore Feature

#### Creating a Local Backup
```
1. Open Owner Dashboard
2. Navigate to "Backup & Restore"
3. Click "Create Backup"
4. Select "Local Storage"
5. Backup is saved automatically
```

#### Creating a Cloud Backup (Google Drive)
```
1. Open "Backup & Restore"
2. Click "Create Backup"
3. If not signed in: Click "Sign In to Google Drive"
4. Authenticate with your Google account
5. Select "Google Drive"
6. Backup is uploaded automatically
```

#### Exporting to Custom Folder
```
1. Click "Export"
2. Choose save location
3. Select filename and save
```

#### Restoring from Local Storage
```
1. Click "Restore from File/Cloud"
2. Select "Local Storage"
3. Choose backup from list
4. Confirm restore (warning: will overwrite current data)
```

#### Restoring from Google Drive
```
1. Click "Restore from File/Cloud"
2. Select "Google Drive"
3. Choose cloud backup from list
4. Confirm restore (warning: will overwrite current data)
```

#### Restoring from Custom File
```
1. Click "Restore from File/Cloud"
2. Select "Select File"
3. Browse and choose .db backup file
4. Confirm restore
```

## Cross-Device Usage

### Scenario: Backup on Device A, Restore on Device B

**Using Google Drive:**
1. On Device A:
   - Create backup and upload to Google Drive
2. On Device B:
   - Sign in to Google Drive
   - Go to Backup & Restore
   - Click "Restore from File/Cloud"
   - Select "Google Drive"
   - Choose the backup
   - Restore

**Using File Transfer:**
1. On Device A:
   - Export backup to custom location
   - Transfer file via USB, email, cloud storage, etc.
2. On Device B:
   - Go to Backup & Restore
   - Click "Restore from File/Cloud"
   - Select "Select File"
   - Choose the transferred backup file
   - Restore

## Database Location

- **Windows**: `C:\Users\<UserName>\Documents\SmartMonitoringSystem\`
- **Android**: `/data/data/com.example.smart_monitoring_system/files/`
- **iOS**: `<App Container>/Documents/SmartMonitoringSystem/`
- **macOS**: `~/Documents/SmartMonitoringSystem/`
- **Linux**: `~/.local/share/smart_monitoring_system/`

Backups are stored in:
- **Local**: `<DatabaseLocation>/Backups/`
- **Google Drive**: `SmartMonitoringSystem_Backups/` folder

## Data Included in Backups

- ✅ All Products
- ✅ Sales Records
- ✅ Inventory Movements
- ✅ Damage Reports
- ✅ Suppliers
- ✅ Purchase Orders
- ✅ Restock Records
- ✅ CCTV Data
- ✅ Cameras
- ✅ Customers
- ✅ Loyalty Program Data
- ✅ Attendance Records

## Security Notes

1. **Automatic Backups**: Created locally, not uploaded by default
2. **Google Drive Backups**: Only uploaded when you click "Create Backup" and select "Google Drive"
3. **File Permissions**: You control access to your Google Drive account
4. **Encryption**: Data is transmitted over HTTPS (secure connection)
5. **Local Storage**: Backups stored in protected application directory

## Troubleshooting

### "Google Sign-In failed"
- Check internet connection
- Verify Google account permissions
- Clear app cache and try again
- Ensure device has Google Play Services (Android)

### "Backup upload failed"
- Check Google Drive storage quota
- Verify stable internet connection
- Try signing out and signing back in
- Ensure backup folder permission exists

### "Restore failed"
- Verify backup file integrity
- Ensure sufficient storage space
- Close all other instances of the app
- Check that backup file is valid .db format

### "Can't see cloud backups"
- Ensure you're signed in to Google Drive
- Check that backups were uploaded successfully
- Click refresh to reload the list
- Verify Google Drive folder permissions

## File Format & Compatibility

- **Format**: SQLite Database (.db)
- **Compression**: None (uncompressed)
- **Version**: Compatible with all recent app versions
- **Backward Compatibility**: Can restore older backups (migrations applied automatically)

## Backup & Restore Storage Requirements

- **Minimum Free Space**: 100 MB for backup creation
- **Maximum Backup Size**: Limited by available storage/Google Drive quota
- **Automatic Cleanup**: Old local backups automatically deleted (kept for 7 days)

## Support

For issues or questions:
1. Check app logs in the console
2. Verify backup file location and permissions
3. Try the troubleshooting steps above
4. Contact support with error messages

---

**Last Updated**: June 4, 2026
**Feature Status**: ✅ Production Ready
