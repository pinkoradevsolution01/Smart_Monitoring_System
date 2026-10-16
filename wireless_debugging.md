Use Android Wireless Debugging (Android 11+).
1. Connect your phone and computer to the same Wi‑Fi.
2. On your phone, open:
   Settings → Developer options → Wireless debugging
3. Enable it, then tap Pair device with pairing code.
4. In VS Code PowerShell, run:
$androidAdb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $androidAdb pair PHONE_IP:PAIRING_PORT
Example:
& $androidAdb pair 192.168.0.218:39539
5. Enter the six-digit pairing code shown on the phone.
6. Return to the Wireless debugging screen and find the normal IP address and port. Connect using that port, which may be different from the pairing port:
& $androidAdb connect PHONE_IP:DEBUG_PORT
Example:
& $androidAdb connect 192.168.1.15:42015
7. Confirm VS Code can see it:
& $androidAdb devices -l
flutter devices
8. Run the app wirelessly:
flutter run -d PHONE_IP:DEBUG_PORT --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
Example device ID:
flutter run -d 192.168.1.15:42015
Keep the phone unlocked and Wireless debugging enabled. If it disconnects, run the adb connect command again; pairing is usually only needed once.