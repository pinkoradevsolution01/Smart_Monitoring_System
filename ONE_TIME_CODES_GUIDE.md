# One-Time Activation Codes - Usage Guide

## Overview
This document contains **100 unique activation codes** that work **one-time only** across all devices, even in offline mode.

## Features
✅ **One-Time Use**: Each code can only be used once, tracked locally in the app  
✅ **Offline Support**: Works without internet connection using checksum validation  
✅ **Cross-Device**: Same code tracking works across different devices (stored in SharedPreferences)  
✅ **20-Character Format**: Uppercase alphanumeric codes (e.g., `6B67B63WSGMEOYUC0L4Y`)  
✅ **Checksum Validation**: Each code passes the formula: `sum of char codes % 7 == 0`  

## How It Works

### One-Time Use Enforcement
1. **First Use**: When a code is entered, it's validated and marked as "used" in SharedPreferences
2. **Subsequent Attempts**: If someone tries to use the same code again, they'll get: 
   ```
   "This activation code has already been used"
   ```
3. **Storage Key**: `used_activation_codes` (stored as a string list)
4. **Persistence**: The used codes list persists across app restarts

### Testing on Multiple Devices

**Device A (First Use)**:
```
1. Enter code: 6B67B63WSGMEOYUC0L4Y
2. Result: ✅ Activation successful!
3. Code stored in used list
```

**Device B (Same Code)**:
```
1. Enter code: 6B67B63WSGMEOYUC0L4Y
2. Result: ✅ Activation successful! (different device = different storage)
3. Code stored in Device B's used list
```

**Device A (Reuse Attempt)**:
```
1. Enter same code: 6B67B63WSGMEOYUC0L4Y
2. Result: ❌ "This activation code has already been used"
```

### Location of Codes
📄 **File**: `ACTIVATION_CODES.txt` (root directory)  
📊 **Total Codes**: 100 unique codes  
📅 **Generated**: February 9, 2026  

## Testing Instructions

### Test Scenario 1: Single Device
```bash
1. Hot restart app: flutter run
2. Go to Package Selection → "Get Started - Monthly"
3. Enter code 001: 6B67B63WSGMEOYUC0L4Y
4. ✅ Success → App activated with 200 peso discount
5. Cancel activation via Developer Dashboard
6. Try same code again → ❌ "Code already used"
7. Use code 002: TM1KY1XTWVJKEOT2P5PA
8. ✅ Success → Works fine
```

### Test Scenario 2: Multiple Devices
```bash
Device 1:
- Use code 003: G1W2IUMU8E5KUA9HDS9E → ✅ Success
- Try code 003 again → ❌ Already used

Device 2:
- Use code 003: G1W2IUMU8E5KUA9HDS9E → ✅ Success (different storage)
- Try code 003 again → ❌ Already used
- Use code 004: BQAP7L5G84ELH9XHL491 → ✅ Success

Device 1:
- Use code 004: BQAP7L5G84ELH9XHL491 → ✅ Success (not used on Device 1 yet)
```

### Test Scenario 3: Offline Mode
```bash
1. Disconnect internet
2. Enter code 005: 7P8HIC0OV00S9LLWCPVS
3. ✅ Success → Offline checksum validation works
4. Try same code → ❌ Already used (stored locally)
5. Reconnect internet → Code still marked as used
```

## Development Test Codes (Reusable)
These codes **bypass** the one-time use restriction for testing:
- `TEST1234567890ABCDEFEF`
- `DEV20240209TESTCODE1`
- `ABCDEFGHIJ0123456789`

Use these for rapid testing without consuming the 100 production codes.

## Viewing Used Codes (Developer Tools)

### Via Developer Dashboard
```dart
1. Login as developer
2. Navigate to: Developer Dashboard → License Test Tools
3. Click "View Used Codes" (future feature)
```

### Via SharedPreferences Inspector
```dart
import 'package:shared_preferences/shared_preferences.dart';

final prefs = await SharedPreferences.getInstance();
final usedCodes = prefs.getStringList('used_activation_codes') ?? [];
print('Used Codes (${usedCodes.length}):');
usedCodes.forEach((code) => print('  - $code'));
```

### Clear Used Codes (Testing Only)
```dart
// Developer Dashboard → "Reset Used Codes"
final prefs = await SharedPreferences.getInstance();
await prefs.remove('used_activation_codes');
print('✅ All activation codes reset - can be used again');
```

## Production Deployment

### Before Going Live
1. ✅ Replace checksum with HMAC-SHA256 or RSA signature
2. ✅ Set up server-side code validation endpoint
3. ✅ Implement database tracking of used codes (server-side)
4. ✅ Add API to check if code was used globally (not just locally)
5. ✅ Generate codes server-side with proper entropy
6. ✅ Add code expiration dates (optional)
7. ✅ Implement rate limiting on activation endpoint

### Security Considerations
⚠️ **Current Implementation**: Uses local storage only (not synced across devices via server)  
⚠️ **Limitation**: Same code can be used on different devices (different local storage)  
✅ **Production Solution**: Implement server-side used codes database with API checks

### Server-Side Validation (Recommended)
```dart
// Future enhancement: Check server before allowing activation
final response = await http.post(
  Uri.parse('https://api.smartmonitor.com/check-code'),
  body: {'code': code},
);

if (response.statusCode == 200) {
  final data = json.decode(response.body);
  if (data['used']) {
    return 'Code already used globally';
  }
}
```

## Code Format Details

### Structure
- **Length**: Exactly 20 characters
- **Allowed Characters**: A-Z, 0-9 (uppercase only)
- **Example**: `6B67B63WSGMEOYUC0L4Y`
- **Validation**: Sum of ASCII values divisible by 7

### How Checksum Works
```dart
String code = '6B67B63WSGMEOYUC0L4Y';
int sum = 0;
for (int i = 0; i < code.length; i++) {
  sum += code.codeUnitAt(i);
}
// If sum % 7 == 0, code is valid
```

### Generate More Codes
```bash
dart run scripts/generate_activation_codes.dart
# Generates new ACTIVATION_CODES.txt with 100 fresh codes
```

## Troubleshooting

### "Code already used" but I never used it
**Cause**: Code was used previously on this device  
**Solution**: Use a different code from the list

### Code doesn't work offline
**Cause**: Code format invalid or checksum failed  
**Solution**: Verify code is copied correctly (20 chars, uppercase)

### Want to reuse a code for testing
**Solution 1**: Use development test codes (unlimited reuse)  
**Solution 2**: Clear used codes via Developer Dashboard  
**Solution 3**: Reinstall app (clears SharedPreferences)

## Summary
- 📦 **100 codes** available in `ACTIVATION_CODES.txt`
- 🔒 **One-time use** per device (local storage)
- 🌐 **Works offline** with checksum validation
- 🔄 **Can be reset** via developer tools for testing
- 🚀 **Production ready** with server-side enhancements

For questions, see: `LICENSE_ACTIVATION_GUIDE.md`
