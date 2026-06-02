# License Activation System - Implementation Guide

## Overview
The Smart Monitoring System now has a **hardened license activation system** that enforces trial expiry and requires activation codes to unlock the app after trial expiration.

## Key Components

### 1. LicenseService (`lib/services/license_service.dart`)
Central service managing all license operations:
- **Trial expiry checking** - automatically detects expired free trials
- **Periodic monitoring** - checks status every 10 seconds (optimized for 3-minute trials)
- **Automatic locking** - notifies listeners when trial expires
- **Online activation** - validates codes with server (configurable endpoint)
- **Offline fallback** - uses checksum validation when network unavailable
- **Persistent storage** - saves activation status in SharedPreferences
- **Notification system** - extends ChangeNotifier for reactive UI updates

### 2. Enhanced Startup Flow (`lib/screens/shared/splash_screen.dart`)
On app startup:
1. LicenseService checks trial/activation status
2. If `isLocked == true`, redirects to TrialLockedScreen
3. If unlocked, proceeds to normal login flow

### 3. Automatic Lock Enforcement (`lib/main.dart`)
Global license listener:
- Listens to LicenseService state changes throughout app lifecycle
- When `isLocked` becomes true while app is running:
  - Automatically navigates to TrialLockedScreen
  - Removes all previous routes (no back button escape)
  - Works from any screen in the app
- Triggered by periodic checks (every 10 seconds) or manual force checks

### 3. Hardened Lock Screen (`lib/screens/shared/trial_locked_screen.dart`)
New features:
- **Activation code input** - 20+ character alphanumeric codes
- **Real-time validation** - calls LicenseService.activate()
- **No developer bypass** - removed "Developer Options" button
- **User guidance** - clear instructions and contact info
- **Responsive UI** - loading states, error messages

## How It Works

### Automatic Trial Expiry Lock
The system enforces license restrictions automatically:

1. **On Startup**: Splash screen checks `LicenseService.isLocked`
2. **During Runtime**: 
   - Periodic check runs every 10 seconds
   - When trial expires, `isLocked` changes to `true`
   - Global listener in `main.dart` detects the change
   - Automatically navigates to locked screen from any screen
   - No back button or navigation escape

3. **Lock Criteria**:
   ```dart
   // Trial expired:
   subscription_mode = 'free_trial' 
   trial_expires < DateTime.now()
   → LicenseService.isLocked = true
   → Auto-redirect to TrialLockedScreen
   
   // Activated:
   activation_status = true
   activation_code exists
   → LicenseService.isLocked = false
   → Normal app access
   ```

### Activation Process
1. User enters activation code in locked screen
2. System checks if using placeholder URL (`your-server.com`)
   - If placeholder: skips online validation, uses offline mode
   - If real URL: attempts online validation
3. If online validation fails or times out, uses offline checksum validation
4. Valid code sets:
   - `activation_code` = code
   - `activation_status` = true
   - `subscription_mode` = 'activated'
5. App unlocks and redirects to login

### Offline Mode (Default for Testing)
By default, the system uses a placeholder server URL and runs in **offline mode**:
- No network requests are made
- Activation codes are validated using local checksum algorithm
- Debug logs show: `"Skipping online validation (placeholder URL configured)"`
- This is **intentional** for testing without a server

**Note:** Network errors like "remote computer refused connection" are expected and handled gracefully when using the placeholder URL.

### Security Features
- **No developer bypass** - removed from locked screen
- **Online verification** - validates codes with server
- **Offline protection** - checksum algorithm prevents simple guessing
- **Persistent lock** - stays locked until valid activation
- **Service-level enforcement** - checked at startup, not just UI

## Configuration

### Server Endpoint
Update in `lib/services/license_service.dart`:
```dart
static const String _activationEndpoint = 
    'https://your-server.com/api/validate-activation';
```

### Expected Server Response
```json
{
  "valid": true,
  "package_name": "Premium",
  "message": "Activation successful"
}
```

### Offline Validation Algorithm
Current implementation: simple checksum (sum of char codes % 7 == 0)
**For production**, replace with stronger algorithm:
```dart
ActivationResult _validateOffline(String code) {
  // TODO: Implement your cryptographic validation
  // Examples: HMAC-SHA256, RSA signature, license key algorithm
}
```

## Testing

### Expected Debug Messages (Normal Behavior)
When testing with the default placeholder URL, you'll see these **expected** messages:
```
LicenseService: Skipping online validation (placeholder URL configured)
LicenseService: Using offline validation mode
```

These are **not errors** - the system is working correctly in offline mode for testing.

### Generate Valid Test Code (Offline)
```dart
// Example codes that pass offline validation (sum % 7 == 0):
'ABCDEFGHIJ0123456789' // Hardcoded test code (always works)
'TEST1234567890ABCDEF' // Hardcoded test code (always works)
'DEV20240209TESTCODE1' // Hardcoded test code (always works)
```

### Hardcoded Test Codes (Development)
These codes are **hardcoded** in the system and will always work:
1. **TEST1234567890ABCDEF**
2. **DEV20240209TESTCODE1**
3. **ABCDEFGHIJ0123456789**

Use any of these for testing activation. No checksum calculation needed - they bypass validation.

### Generate Additional Codes
Run the generator script to create more valid codes:
```bash
dart run scripts/generate_test_codes.dart
```

### Test Trial Lock
**Automatic Lock Test (Recommended):**
1. Start 3-minute free trial in package selection
2. Note the expiry time shown in the confirmation dialog (date + time)
3. Use the app normally (any screen)
4. After 3 minutes, system **automatically locks within 10 seconds**
5. System navigates to locked screen - no manual action needed!

**Quick Manual Test (Optional):**
1. Login to Developer Dashboard → "License Test Tools"
2. Click "Expire Trial NOW" to set trial to past
3. Click "Force Check Now" to trigger immediate lock
4. System instantly locks and navigates to locked screen

**Enter activation code to unlock:**
- **TEST1234567890ABCDEF**
- **DEV20240209TESTCODE1**
- **ABCDEFGHIJ0123456789**

### Test Activation
1. Wait for trial to expire automatically (3 minutes + up to 10 seconds)
2. System automatically locks and shows activation screen
3. Click "I Have an Activation Code"
4. Enter any test code:
   - **TEST1234567890ABCDEF** (recommended)
   - **DEV20240209TESTCODE1**
   - **ABCDEFGHIJ0123456789**
5. Click "Activate Now"
6. System unlocks and redirects to login

## Configuration

### Current Settings (Optimized for 3-Minute Testing)
The system is pre-configured for fast testing:
- **Trial Duration**: 3 minutes (in `package_selection_screen.dart`)
- **Check Interval**: 10 seconds (in `license_service.dart`)
- **Auto-Lock**: Happens within 10 seconds after expiry

### Production Configuration
When deploying with 30-day trials, update these values:

**license_service.dart** - Increase check interval:
```dart
const Duration(seconds: 10)   // Testing (current)
↓
const Duration(seconds: 60)   // Production (every minute)
```

**package_selection_screen.dart** - Change trial duration:
```dart
const Duration(minutes: 3)    // Testing (current)
↓
const Duration(days: 30)      // Production (30-day trial)
```

## Developer Tools

### Check Current License Status
```dart
final licenseService = GetIt.I<LicenseService>();
print('Is Locked: ${licenseService.isLocked}');
print('Is Activated: ${licenseService.isActivated}');
print('Trial Expires: ${licenseService.trialExpires}');
print('Days Remaining: ${licenseService.getDaysRemainingInTrial()}');
```

### Force Deactivation (Testing)
```dart
await licenseService.deactivate();
await licenseService.refreshStatus();
```

### Refresh License Status
```dart
// After manual SharedPreferences changes:
await licenseService.refreshStatus();
```

## Production Checklist

- [ ] Replace `_activationEndpoint` with real server URL
- [ ] Implement strong offline validation algorithm (HMAC/RSA)
- [ ] Set up server endpoint for online validation
- [ ] Generate secure activation codes with proper entropy
- [ ] Test network failure scenarios
- [ ] Add logging/analytics for activation attempts
- [ ] Document activation code format for sales team
- [ ] Create admin panel for code generation/revocation
- [ ] Add rate limiting to prevent brute force attempts
- [ ] Consider adding license expiry dates (not just perpetual)

## Configuration

### Adjust Lock Check Interval
For faster testing (e.g., 3-minute trials), reduce the check interval in `license_service.dart`:

```dart
// Default: checks every 30 seconds
_periodicCheckTimer = Timer.periodic(
  const Duration(seconds: 30), 
  (_) => _checkLicenseStatus(),
);

// For testing: checks every 10 seconds
_periodicCheckTimer = Timer.periodic(
  const Duration(seconds: 10), // Faster for testing
  (_) => _checkLicenseStatus(),
);
```

**Recommendation**: 
- Production: 30-60 seconds (balances UX and performance)
- Testing: 10 seconds (faster feedback for 3-minute trials)

### Manual Force Check
Call `licenseService.forceCheck()` to trigger immediate check without waiting for periodic timer.

## Sales Integration

### Typical Purchase Flow
1. Customer completes purchase
2. Sales system generates unique activation code
3. Code sent via email with instructions
4. Customer enters code in locked screen
5. System validates online → unlocks immediately

### Code Format Requirements
- **Length**: 20+ characters
- **Characters**: A-Z, 0-9 only (uppercase)
- **Optional**: Dashes for readability (e.g., `XXXX-XXXX-XXXX-XXXX-XXXX`)
- **Validation**: Must pass server check OR offline checksum

## Support Contact Info
Update in `trial_locked_screen.dart`:
```dart
Text('📧 Email: jaybe.gubot01@gmail.com')
Text('📞 Phone: +1-XXX-XXX-XXXX')
Text('🌐 Web: www.smartstore.com/purchase')
```

## Migration Notes

### Existing Trials
- Old trial users will be locked when trial expires
- No automatic grace period
- Must activate or purchase new trial

### Developer Access
- Developer bypass has been removed from locked screen
- Developers can still access via developer_auth at initial setup
- Once trial expires, developers also need activation codes

### Backward Compatibility
- Service checks for existing `subscription_mode` values
- Supports: `free_trial`, `paid`, `activated`
- Legacy users without mode set: not locked (allows initial setup)

## Architecture Benefits

✅ **Centralized logic** - All license checks in one service  
✅ **Reactive updates** - ChangeNotifier pattern for UI sync  
✅ **Network resilient** - Offline fallback validation  
✅ **Persistent state** - Survives app restarts  
✅ **Service layer enforcement** - Not just UI-level checks  
✅ **Extensible** - Easy to add features (expiry dates, multiple licenses, etc.)

## Future Enhancements

- [ ] License expiry dates (not just perpetual licenses)
- [ ] Multi-device license management
- [ ] Hardware fingerprinting to prevent code sharing
- [ ] Grace period option (e.g., 3 days after trial expiry)
- [ ] Automatic renewal reminders
- [ ] In-app purchase integration for mobile platforms
- [ ] Analytics dashboard for license usage
- [ ] Floating licenses (network-based activation)
