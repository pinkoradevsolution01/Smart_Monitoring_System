# Gmail OAuth Integration Guide

## Overview
This guide explains how to integrate Gmail (Google) authentication with your Smart Monitoring System using Supabase OAuth.

---

## 🚀 Setup Steps

### Step 1: Enable Google Provider in Supabase (5 minutes)

1. **Go to Supabase Dashboard** → Your Project

2. **Navigate to**: Authentication → Providers

3. **Find "Google"** in the providers list

4. **Enable Google Provider**:
   - Toggle "Enable Sign in with Google" to ON
   - You'll need Google OAuth credentials

### Step 2: Create Google OAuth App (10 minutes)

1. **Go to Google Cloud Console**: [https://console.cloud.google.com](https://console.cloud.google.com)

2. **Create New Project** (if you don't have one):
   - Click "Select a project" → "New Project"
   - Name: `Smart Monitoring System`
   - Click "Create"

3. **Enable Google+ API**:
   - Go to: APIs & Services → Library
   - Search for "Google+ API"
   - Click "Enable"

4. **Create OAuth Credentials**:
   - Go to: APIs & Services → Credentials
   - Click "Create Credentials" → "OAuth client ID"
   - Application type: **Web application**
   - Name: `Smart Monitoring System - Supabase`

5. **Add Authorized Redirect URIs**:
   ```
   https://[YOUR_SUPABASE_PROJECT_ID].supabase.co/auth/v1/callback
   ```
   
   Example:
   ```
   https://abcdefghijklmnop.supabase.co/auth/v1/callback
   ```
   
   **How to find your Project ID:**
   - Go to Supabase Dashboard → Settings → API
   - Your URL: `https://[PROJECT_ID].supabase.co`
   - Copy the PROJECT_ID part

6. **Save and Copy Credentials**:
   - Click "Create"
   - Copy **Client ID** (looks like: `123456789-abc.apps.googleusercontent.com`)
   - Copy **Client secret** (looks like: `GOCSPX-abc123...`)

### Step 3: Configure Supabase with Google Credentials (2 minutes)

1. **Back to Supabase Dashboard** → Authentication → Providers → Google

2. **Paste Google OAuth Credentials**:
   - **Client ID**: Paste from Google Console
   - **Client secret**: Paste from Google Console

3. **Additional Settings** (optional):
   - **Skip nonce check**: Leave UNCHECKED (more secure)
   - **Authorized Client IDs**: Leave empty (unless using mobile apps)

4. **Click "Save"**

### Step 4: Get Supabase Redirect URL

Copy this URL for your app configuration:
```
https://[YOUR_PROJECT_ID].supabase.co/auth/v1/callback
```

You'll need this in your Flutter app.

---

## 📱 Flutter App Integration

### Current Implementation

The system already has:
- ✅ `supabase_flutter` package installed
- ✅ Supabase initialized in `main.dart`
- ✅ DeveloperAuthScreen for admin login

### Add "Sign in with Google" Button

The DeveloperAuthScreen now includes a Gmail sign-in button that:
1. Opens Google OAuth flow in browser
2. User selects/logs into their Gmail account
3. Redirects back to app with auth token
4. Automatically creates admin account if first-time
5. Navigates to dashboard

### How It Works

```dart
// Sign in with Google
final response = await Supabase.instance.client.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'smartmonitor://login-callback',
);

// After successful auth
final user = Supabase.instance.client.auth.currentUser;
print('Logged in as: ${user?.email}');
```

---

## 🔒 Security Considerations

### Admin Role Assignment

**IMPORTANT**: By default, anyone with a Gmail account can sign in. To restrict admin access:

#### Option 1: Email Whitelist (Recommended)

Add allowed admin emails to your app:

```dart
// lib/services/supabase_config.dart
class SupabaseConfig {
  // ...existing code...
  
  /// Allowed admin Gmail accounts
  static const List<String> allowedAdminEmails = [
    'your.email@gmail.com',
    'admin@yourdomain.com',
    'it.admin@yourdomain.com',
  ];
  
  static bool isAdminEmail(String email) {
    return allowedAdminEmails.contains(email.toLowerCase());
  }
}
```

#### Option 2: Database-Based Access Control

Create an `admin_users` table in Supabase:

```sql
-- Create admin users table
CREATE TABLE admin_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  role VARCHAR(50) DEFAULT 'admin',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);

-- Add your email
INSERT INTO admin_users (email, role) VALUES
  ('your.email@gmail.com', 'super_admin'),
  ('admin@yourdomain.com', 'admin');

-- Enable RLS
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read (for login check)
CREATE POLICY "Allow public read admin_users" ON admin_users
  FOR SELECT USING (true);
```

Then check in your app:

```dart
// After Google sign-in
final userEmail = user?.email;
final response = await Supabase.instance.client
    .from('admin_users')
    .select()
    .eq('email', userEmail)
    .eq('is_active', true)
    .maybeSingle();

if (response == null) {
  // Not an authorized admin
  await Supabase.instance.client.auth.signOut();
  showError('Unauthorized. Contact system administrator.');
  return;
}

// User is authorized admin
print('Welcome ${response['role']} user!');
```

#### Option 3: Supabase Auth Hooks (Advanced)

Use Supabase Edge Functions to validate on sign-in:

```typescript
// supabase/functions/validate-admin/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const allowedDomains = ['yourcompany.com', 'yourdomain.com']
const allowedEmails = ['specific.email@gmail.com']

serve(async (req) => {
  const { email } = await req.json()
  
  // Check if email domain is allowed
  const domain = email.split('@')[1]
  const isAllowed = allowedDomains.includes(domain) || 
                    allowedEmails.includes(email)
  
  if (!isAllowed) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized domain' }),
      { status: 403 }
    )
  }
  
  return new Response(
    JSON.stringify({ success: true }),
    { status: 200 }
  )
})
```

---

## 🧪 Testing Gmail Authentication

### Test Flow

1. **Run your app**: `flutter run`

2. **Navigate to**: Developer Auth Screen

3. **Click**: "Sign in with Google" button

4. **Browser opens** with Google sign-in

5. **Select Gmail account**: Choose admin account

6. **Grant permissions**: Allow access to basic profile

7. **Redirect to app**: Automatic navigation

8. **Verify**:
   ```dart
   final user = Supabase.instance.client.auth.currentUser;
   print('User ID: ${user?.id}');
   print('Email: ${user?.email}');
   print('Full Name: ${user?.userMetadata?['full_name']}');
   print('Avatar: ${user?.userMetadata?['avatar_url']}');
   ```

### Expected Console Output

```
✅ Supabase initialized successfully
🔐 Google OAuth flow started...
✅ User signed in: your.email@gmail.com
📝 User ID: 123e4567-e89b-12d3-a456-426614174000
👤 Display Name: John Doe
🖼️ Avatar: https://lh3.googleusercontent.com/...
```

---

## 📊 User Data Available After Sign-In

After successful Gmail authentication, you can access:

```dart
final user = Supabase.instance.client.auth.currentUser;

// Basic Info
String? userId = user?.id;              // UUID
String? email = user?.email;            // Gmail address
DateTime? createdAt = user?.createdAt;   // First sign-in time

// User Metadata (from Google)
Map<String, dynamic>? metadata = user?.userMetadata;
String? fullName = metadata?['full_name'];         // "John Doe"
String? firstName = metadata?['given_name'];       // "John"
String? lastName = metadata?['family_name'];       // "Doe"
String? picture = metadata?['avatar_url'];         // Profile picture URL
String? locale = metadata?['locale'];              // "en" or "fil"
```

### Save to AdminService

```dart
// Update admin account with Gmail data
final admin = AdminAccount(
  id: user!.id,
  name: metadata?['full_name'] ?? email!,
  email: email!,
  password: '', // Not used with OAuth
  contactNumber: '', // User can add later
  createdAt: DateTime.now(),
  profilePictureUrl: metadata?['avatar_url'],
);

await adminService.updateAdminAccount(admin);
```

---

## 🔄 Sign Out

```dart
// Sign out from Supabase (clears session)
await Supabase.instance.client.auth.signOut();

// Clear local admin data
await DeveloperAuthScreen.clearAuthentication();

// Navigate to login
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) => DeveloperAuthScreen()),
);
```

---

## 🐛 Troubleshooting

### "Error 400: redirect_uri_mismatch"

**Problem**: Redirect URI not configured in Google Console

**Fix**:
1. Go to Google Cloud Console → Credentials
2. Edit your OAuth client
3. Add exact redirect URI from Supabase:
   ```
   https://[YOUR_PROJECT_ID].supabase.co/auth/v1/callback
   ```
4. Save and wait 5 minutes for changes to propagate

### "OAuth app not verified"

**Problem**: Google requires app verification for production

**Solutions**:
- **Option 1 (Testing)**: Click "Advanced" → "Go to Smart Monitoring System (unsafe)"
- **Option 2 (Production)**: Submit app for Google verification
- **Option 3 (Internal)**: Use Google Workspace domain and mark as "Internal"

### "Popup blocked" or "Redirect failed"

**Problem**: Browser blocking OAuth popup/redirect

**Fix**:
- On Desktop: Allow popups for your app
- On Mobile: Deep linking may not be configured
- Fallback: Use manual code entry instead

### "Invalid client"

**Problem**: Wrong Client ID or Client Secret in Supabase

**Fix**:
1. Verify credentials in Google Console
2. Re-copy Client ID and Client Secret
3. Paste again in Supabase → Authentication → Providers → Google
4. Click "Save"

---

## 🎨 UI Customization

### Custom Google Button

The sign-in button uses Google's brand guidelines:

```dart
ElevatedButton.icon(
  onPressed: _signInWithGoogle,
  icon: Image.network(
    'https://www.google.com/favicon.ico',
    width: 20,
    height: 20,
  ),
  label: const Text('Sign in with Google'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    // ...
  ),
)
```

### Dark Mode Support

```dart
style: ElevatedButton.styleFrom(
  backgroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[800]
      : Colors.white,
  foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
)
```

---

## 📋 Production Checklist

Before deploying Gmail authentication:

- [ ] Google OAuth app created
- [ ] Redirect URI configured in Google Console
- [ ] Google credentials added to Supabase
- [ ] Email whitelist implemented (if restricting access)
- [ ] Admin users table created (if using database control)
- [ ] Test sign-in on development environment
- [ ] Test sign-in on production build
- [ ] Test sign-out flow
- [ ] Test unauthorized email rejection
- [ ] Verify user data stored correctly
- [ ] Test offline behavior (cached session)
- [ ] Configure session expiry settings
- [ ] Set up email notifications for new admin sign-ins

---

## 🔐 Session Management

### Session Duration

Default: **1 hour** (3600 seconds)

Change in Supabase Dashboard:
- Authentication → Settings → JWT Expiry
- Set custom duration (e.g., 86400 for 24 hours)

### Refresh Tokens

Supabase automatically refreshes tokens. Check session:

```dart
// Check if user is still logged in
final session = Supabase.instance.client.auth.currentSession;
if (session == null) {
  // Session expired, prompt login
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => DeveloperAuthScreen()),
  );
}
```

### Persistent Login

```dart
// On app startup, check for existing session
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(/* ... */);
  
  final session = Supabase.instance.client.auth.currentSession;
  final initialRoute = session != null
      ? '/admin-dashboard'  // Still logged in
      : '/login';           // Need to login
  
  runApp(MyApp(initialRoute: initialRoute));
}
```

---

## 📱 Mobile Deep Linking (Optional)

For mobile apps, configure deep linking to handle OAuth redirects:

### Android Configuration

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
    android:scheme="smartmonitor"
    android:host="login-callback" />
</intent-filter>
```

### iOS Configuration

```xml
<!-- ios/Runner/Info.plist -->
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

## 🎯 Summary

**What you get with Gmail OAuth:**
✅ Secure authentication via Google
✅ No password management (Google handles it)
✅ Profile picture and name automatically populated
✅ Fast one-click sign-in
✅ Cross-device session sync via Supabase
✅ Automatic token refresh
✅ Email verification already done by Google

**Setup time**: ~15 minutes
**Cost**: FREE (Google OAuth is free)
**Security**: ⭐⭐⭐⭐⭐ (Google-grade security)

---

## 📚 Additional Resources

- **Supabase Auth Docs**: https://supabase.com/docs/guides/auth
- **Google OAuth Setup**: https://supabase.com/docs/guides/auth/social-login/auth-google
- **Flutter Integration**: https://supabase.com/docs/reference/dart/auth-signinwithoauth
- **Google Cloud Console**: https://console.cloud.google.com

---

**Last Updated**: February 9, 2026  
**Version**: 1.0  
**Status**: Production Ready ✅
