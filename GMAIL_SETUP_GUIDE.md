# Gmail Authentication & Email Notifications Setup Guide

## Overview
Your Smart Monitoring System now supports:
- ✅ Google Sign-In for admin accounts
- ✅ Email notifications sent to admin on login
- ✅ Support for low stock alerts and daily sales reports

## Prerequisites
1. Gmail account for admin
2. Firebase project configured
3. Google App Password for sending emails

---

## Part 1: Configure Firebase for Google Sign-In

### Step 1: Enable Google Sign-In in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Google** provider
5. **Enable** the Google provider
6. Enter your **support email** (your admin Gmail)
7. Click **Save**

### Step 2: Configure Android (if deploying to Android)

1. In Firebase Console, go to **Project Settings**
2. Under **Your apps**, find your Android app
3. Download the updated `google-services.json`
4. Replace `android/app/google-services.json` with the new file

### Step 3: Configure iOS (if deploying to iOS)

1. In Firebase Console, go to **Project Settings**
2. Under **Your apps**, find your iOS app
3. Download the updated `GoogleService-Info.plist`
4. Replace `ios/Runner/GoogleService-Info.plist` with the new file

### Step 4: Update Android build.gradle (already done)

File: `android/app/build.gradle`
```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.0.0')
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-auth'
}
```

---

## Part 2: Configure Email Notifications

### Step 1: Create Google App Password

1. Go to [Google Account](https://myaccount.google.com/)
2. Navigate to **Security**
3. Enable **2-Step Verification** (if not already enabled)
4. Scroll down to **2-Step Verification** → **App passwords**
5. Click **Select app** → Choose **Mail**
6. Click **Select device** → Choose **Other (Custom name)**
7. Enter name: "Smart Monitoring System"
8. Click **Generate**
9. **Copy the 16-character password** (you'll need this)

### Step 2: Configure Email Service in Your App

In your app's initialization code (e.g., `main.dart` or a settings screen):

```dart
import 'package:smart_monitoring_system/services/email_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase...
  
  // Configure email notifications
  final emailService = EmailNotificationService();
  emailService.configure(
    adminEmail: 'your-admin@gmail.com',        // Your admin Gmail
    smtpUsername: 'your-admin@gmail.com',      // Same Gmail
    smtpPassword: 'your-app-password-here',    // 16-char App Password
  );
  
  runApp(MyApp());
}
```

### Step 3: Test Email Notifications

The system will automatically send emails for:

1. **Admin Login Alerts** - Every time admin logs in
   - Sent to configured admin email
   - Contains login time, device info, IP address
   - Helps detect unauthorized access

2. **Low Stock Alerts** - When product stock is low
   - Triggered when stock ≤ reorder level
   - Lists product name and current stock

3. **Daily Sales Reports** - End-of-day summary
   - Total sales amount
   - Transaction count
   - Top selling products

---

## Part 3: Set Up Admin Account for Google Sign-In

### Option A: Create Admin in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Authentication** → **Users**
3. Click **Add user**
4. Enter your **admin Gmail address**
5. Set a **password** (can be anything, won't be used for Google Sign-In)
6. Click **Add user**

### Option B: Use the App's Create Admin Feature

1. Launch the app
2. Click **"Create Admin Account"** on login screen
3. Fill in admin details with your Gmail address
4. Complete the setup

---

## Part 4: Using Google Sign-In

### For Admin Users:

1. Open the app
2. On the login screen, click **"Sign in with Google (Admin Only)"**
3. Select your Gmail account
4. Grant permissions
5. You'll be logged in and redirected to Admin Dashboard
6. You'll receive an email notification about the login

### Security Features:

- ✅ Only admin emails can use Google Sign-In
- ✅ Non-admin accounts are rejected automatically
- ✅ Email notifications sent for every admin login
- ✅ Includes device info and login time

---

## Part 5: Email Notification Configuration (Advanced)

### Customize Email Templates

Edit `lib/services/email_notification_service.dart`:

```dart
// Change subject line
..subject = '🔐 Your Custom Subject'

// Modify HTML template
..html = '''
  <html>
    <body>
      <!-- Your custom email template -->
    </body>
  </html>
'''
```

### Add Custom Notifications

```dart
// In your code
final emailService = EmailNotificationService();

// Send custom alert
await emailService.sendAdminLoginNotification(
  adminEmail: 'admin@example.com',
  loginTime: DateTime.now().toString(),
  deviceInfo: 'Windows Desktop',
  ipAddress: '192.168.1.1',
);
```

### Configure Different SMTP Server (Optional)

```dart
emailService.configure(
  adminEmail: 'admin@example.com',
  smtpUsername: 'notifications@yourdomain.com',
  smtpPassword: 'your-password',
  smtpHost: 'smtp.yourdomain.com',  // Custom SMTP
  smtpPort: 587,
);
```

---

## Troubleshooting

### Google Sign-In Not Working

**Issue**: "Sign-in failed" error

**Solutions**:
1. Verify Google provider is enabled in Firebase Console
2. Check SHA-1 certificate is added for Android:
   ```bash
   cd android
   ./gradlew signingReport
   ```
3. Add SHA-1 to Firebase Console → Project Settings → Android app
4. Re-download `google-services.json`

### Email Notifications Not Sending

**Issue**: Emails not being received

**Solutions**:
1. Verify App Password is correct (16 characters, no spaces)
2. Check Gmail 2-Step Verification is enabled
3. Verify `smtpUsername` and `adminEmail` are correct
4. Check spam/junk folder
5. Enable "Less secure app access" if using old Gmail settings

**Issue**: "Authentication failed" error

**Solutions**:
1. Generate new App Password
2. Ensure using App Password, not regular Gmail password
3. Check if account has 2FA enabled

### Admin Access Denied

**Issue**: "Google Sign-In is for admin accounts only"

**Solutions**:
1. Verify email is registered as admin in app
2. Check `AdminService.isAdmin()` method
3. Create admin account first via "Create Admin Account" button

---

## Testing Checklist

- [ ] Google Sign-In works on Android
- [ ] Google Sign-In works on iOS
- [ ] Google Sign-In works on Web
- [ ] Email notification received on admin login
- [ ] Email contains correct login time and device info
- [ ] Non-admin accounts are rejected
- [ ] Regular email/password login still works
- [ ] Low stock alerts working (optional)
- [ ] Daily sales reports working (optional)

---

## Security Best Practices

1. **Never commit sensitive data**:
   - Add email credentials to environment variables
   - Don't hardcode passwords in source code
   - Use `.env` files (add to `.gitignore`)

2. **Secure App Password**:
   - Store in secure location
   - Rotate periodically
   - Revoke if compromised

3. **Firebase Security Rules**:
   - Restrict admin collection to authenticated users
   - Validate email domains for admin access
   - Enable audit logging

4. **Email Security**:
   - Use TLS/SSL for SMTP
   - Validate email addresses
   - Implement rate limiting

---

## Example: Complete Setup in main.dart

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/email_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseService().initialize();

  // Configure email notifications
  final emailService = EmailNotificationService();
  emailService.configure(
    adminEmail: 'admin@yourstore.com',
    smtpUsername: 'admin@yourstore.com',
    smtpPassword: 'xxxx xxxx xxxx xxxx',  // App Password
  );

  runApp(const MyApp());
}
```

---

## Support

For issues:
1. Check Flutter logs: `flutter logs`
2. Check Firebase Console logs
3. Verify Gmail App Password is valid
4. Review error messages in app

For Gmail issues:
- [Google Account Help](https://support.google.com/accounts)
- [App Passwords Guide](https://support.google.com/accounts/answer/185833)

For Firebase issues:
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firebase Support](https://firebase.google.com/support)

---

## What's Next?

1. **Test Google Sign-In** on your device
2. **Configure email notifications** with your Gmail
3. **Customize email templates** to match your branding
4. **Set up scheduled reports** for daily sales summaries
5. **Add more notification types** (new sale, system errors, etc.)

Your Smart Monitoring System is now enterprise-ready with professional authentication and notification features! 🎉
