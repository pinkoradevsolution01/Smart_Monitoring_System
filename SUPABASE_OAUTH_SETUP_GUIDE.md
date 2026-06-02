# Supabase Google OAuth Setup Guide
## Smart Monitoring System - Multi-Device Cloud Sync

This guide walks you through setting up Google OAuth authentication and cloud database synchronization for your Smart Monitoring System with Supabase.

---

## 📋 Prerequisites

- Supabase account (free tier works fine)
- Google Cloud Console account
- Flutter SDK installed
- Smart Monitoring System codebase

---

## Part 1: Supabase Project Setup

### Step 1: Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign in or create an account
4. Click "New Project"
5. Fill in:
   - **Name**: `smart-monitoring-system`
   - **Database Password**: Generate a strong password (save this!)
   - **Region**: Choose closest to your location
   - **Plan**: Free tier is sufficient
6. Click "Create new project" (takes ~2 minutes)

### Step 2: Get Supabase Credentials

Once your project is ready:

1. Go to **Project Settings** (gear icon in sidebar)
2. Click **API** tab
3. Copy these values:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon public key** (under Project API keys)

4. Open your code file: `lib/services/supabase_config.dart`
5. Update the values:

```dart
class SupabaseConfig {
  // Replace with your Supabase project URL
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  
  // Replace with your Supabase anon key
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
}
```

---

## Part 2: Google Cloud Console Setup

### Step 1: Create Google Cloud Project

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com)
2. Click the project dropdown (top left)
3. Click **New Project**
4. Fill in:
   - **Project name**: `smart-monitoring-oauth`
   - **Location**: No organization
5. Click **Create**

### Step 2: Enable Google+ API

1. In your new project, go to **APIs & Services** > **Library**
2. Search for "Google+ API"
3. Click **Google+ API**
4. Click **Enable**

### Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services** > **OAuth consent screen**
2. Choose **External** (unless you have Google Workspace)
3. Click **Create**
4. Fill in App information:
   - **App name**: `Smart Monitoring System`
   - **User support email**: Your email
   - **Developer contact email**: Your email
5. Click **Save and Continue**
6. **Scopes**: Click **Add or Remove Scopes**
   - Add: `.../auth/userinfo.email`
   - Add: `.../auth/userinfo.profile`
   - Click **Update** then **Save and Continue**
7. **Test users**: Add your Gmail address for testing
8. Click **Save and Continue** > **Back to Dashboard**

### Step 4: Create OAuth Credentials

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Choose **Application type**:
   - For **Web**: Select "Web application"
   - For **Android**: Select "Android"
   - For **iOS**: Select "iOS"
4. Fill in:
   - **Name**: `Smart Monitor Web Client` (or Android/iOS)
   
   **For Web:**
   - **Authorized JavaScript origins**: Add your domain
   - **Authorized redirect URIs**: Add:
     ```
     https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
     ```
   
   **For Android:**
   - **Package name**: `com.example.smart_monitoring_system`
   - **SHA-1 certificate fingerprint**: (get from your keystore)
   
   **For iOS:**
   - **Bundle ID**: `com.example.smartMonitoringSystem`

5. Click **Create**
6. **SAVE THESE:**
   - **Client ID** (looks like: `xxxxx.apps.googleusercontent.com`)
   - **Client Secret** (only for web)

---

## Part 3: Supabase Authentication Setup

### Step 1: Enable Google Provider

1. In your Supabase project dashboard
2. Go to **Authentication** > **Providers**
3. Find **Google** in the list
4. Toggle **Enable Sign in with Google**
5. Paste your Google credentials:
   - **Client ID**: From Google Console
   - **Client Secret**: From Google Console (if web)
6. Click **Save**

### Step 2: Configure Redirect URLs

1. Still in **Authentication** > **Providers**
2. Click **Google** provider settings
3. Add **Authorized Redirect URIs**:
   ```
   https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
   smartmonitor://oauth-callback
   ```
4. Copy the **Callback URL** shown (will be used in Google Console)
5. Click **Save**

### Step 3: Update Google Console Redirect URIs

1. Go back to **Google Cloud Console**
2. **APIs & Services** > **Credentials**
3. Click your OAuth 2.0 Client ID
4. Under **Authorized redirect URIs**, add:
   ```
   https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
   ```
5. Click **Save**

---

## Part 4: Database Schema Setup

### Step 1: Run SQL Schema

1. In Supabase dashboard, go to **SQL Editor**
2. Click **New Query**
3. Copy and paste the complete SQL from `SUPABASE_SCHEMA.sql` file
4. Click **Run** (or Ctrl+Enter)
5. Verify tables created:
   - businesses
   - products
   - sales
   - sale_items
   - inventory_movements
   - users (for user management across devices)

### Step 2: Enable Row Level Security (RLS)

The SQL schema automatically sets up RLS policies, but verify:

1. Go to **Database** > **Tables**
2. For each table (products, sales, etc.):
   - Click table name
   - Go to **Policies** tab
   - Ensure you see policies like "Users can only access their business data"
3. If not, re-run the SQL schema

---

## Part 5: Flutter App Configuration

### Step 1: Initialize Supabase in main.dart

Update your `main.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // ...rest of your initialization
  runApp(const MyApp());
}
```

### Step 2: Configure Deep Linking (Windows/Android/iOS)

#### For Windows:

1. Create `windows/runner/deeplink_handler.h` and `deeplink_handler.cpp` (files provided in repo)
2. Register URL scheme `smartmonitor://` in Windows registry
3. Or use: `flutter run -d windows` and OAuth will redirect in browser

#### For Android:

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="smartmonitor" android:host="oauth-callback" />
</intent-filter>
```

#### For iOS:

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>smartmonitor</string>
        </array>
    </dict>
</array>
```

---

## Part 6: Testing

### Test Owner Registration

1. Clear app data:
   ```bash
   Remove-Item -Path "$env:APPDATA\smart_monitoring_system\*" -Recurse -Force
   ```

2. Run the app:
   ```bash
   flutter run -d windows
   ```

3. You should see **Owner Registration Screen**
4. Click **"Sign in with Google"**
5. Browser opens → Choose your Google account
6. Accept permissions
7. You're redirected back → Owner account created!
8. Business ID automatically generated for multi-device sync

### Test Developer Account

1. At package selection screen, tap the store icon **7 times**
2. Enter password: `developer123` or `admin@dev`
3. Developer auth screen appears
4. Click **"Sign in with Google"** or use Founder Quick Setup
5. Access developer dashboard

### Test Multi-Device Sync

1. **Device 1**: Register an owner account, add products
2. **Device 2**: Sign in with the same Google account
3. **Device 2**: Products from Device 1 should appear automatically!
4. Both devices share the same `business_id`

---

## Troubleshooting

### Error: "OAuth redirect failed"

**Solution**:
- Verify redirect URIs in Google Console match Supabase callback URL exactly
- Check that Google OAuth is enabled in Supabase
- Ensure no typos in URLs

### Error: "User not authenticated after OAuth"

**Solution**:
- Wait 2-3 seconds for Supabase to process redirect
- Check browser console for errors
- Verify `smartmonitor://` deep link is registered

### Error: "Supabase not configured"

**Solution**:
- Update `lib/services/supabase_config.dart` with actual credentials
- Ensure `Supabase.initialize()` is called in `main.dart` before `runApp()`

### Error: "Row violates row-level security policy"

**Solution**:
- Ensure `business_id` is set during owner registration
- Verify RLS policies allow access based on `business_id`
- Check that user is authenticated with Supabase

### Products not syncing across devices

**Solution**:
- Verify both devices used same Google account for owner sign-in
- Check `business_id` is the same on both devices (stored in SharedPreferences)
- Ensure internet connection on both devices
- Check Supabase dashboard → Database → products table for data

---

## Security Best Practices

1. **Never commit Supabase keys to Git**:
   ```bash
   echo "lib/services/supabase_config.dart" >> .gitignore
   ```

2. **Use environment variables** (for production):
   ```dart
   static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
   ```

3. **Enable Row Level Security** on all tables (done in schema)

4. **Restrict OAuth consent screen** to specific Gmail domains if for business use

5. **Rotate credentials** if exposed

---

## Next Steps

✅ Owner and Developer accounts now use Google OAuth  
✅ Multi-device data sync enabled via Supabase  
✅ Secure authentication with no passwords to remember  

**Optional enhancements**:
- Add offline sync with local SQLite cache
- Implement conflict resolution for simultaneous edits
- Add real-time subscriptions for instant updates
- Enable push notifications via Firebase Cloud Messaging

---

## Support

Having issues? Check:
- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Documentation](https://docs.flutter.dev)
- [Google OAuth 2.0 Docs](https://developers.google.com/identity/protocols/oauth2)

---

**🎉 Congratulations! Your system now supports:**
- ✅ 5 clients (businesses)
- ✅ Each with 2-3 devices sharing data
- ✅ Secure Google authentication
- ✅ Cloud-based multi-device sync
- ✅ Real-time updates across devices
