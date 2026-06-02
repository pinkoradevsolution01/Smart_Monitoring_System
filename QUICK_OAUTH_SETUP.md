# Quick Setup: Google OAuth (5 Minutes)

## ⚠️ You're seeing this because Google OAuth is not configured yet

Follow these steps to enable Google Sign In:

---

## Step 1: Configure Google Cloud Console (2 minutes)

1. **Go to**: https://console.cloud.google.com
2. **Create/Select Project**: Choose existing or create new project
3. **Enable APIs**: Go to "Enable APIs and Services"
   - Search for "Google+ API"
   - Click Enable
4. **Create OAuth Credentials**:
   - Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
   - Application type: **Web application**
   - Name: `Smart Monitoring System`
   - **Authorized redirect URIs**: Add BOTH of these URLs:
     ```
     https://olrrbyrzrotojsjkqcxr.supabase.co/auth/v1/callback
     http://localhost:54321/auth/callback
     ```
     (The first is for Supabase, the second is for Windows desktop app)
   - Click "Create"
5. **Copy Credentials**:
   - Copy the **Client ID**
   - Copy the **Client Secret**

---

## Step 2: Configure Supabase (2 minutes)

1. **Go to**: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr
2. **Navigate to**: Authentication → Providers
3. **Find Google** in the provider list
4. **Enable Google**:
   - Toggle ON
   - Paste **Client ID** from Step 1
   - Paste **Client Secret** from Step 1
   - **Authorize Redirect URLs** should already have:
     ```
     https://olrrbyrzrotojsjkqcxr.supabase.co/auth/v1/callback
     ```
   - **IMPORTANT for Windows Desktop**: Add this redirect URL:
     ```
     http://localhost:54321/auth/callback
     ```
5. **Click Save**

---

## Step 3: Deploy Database Schema (1 minute)

1. Go to: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/editor
2. Click "New Query"
3. Open file: `SUPABASE_SCHEMA.sql` in your project
4. Copy ALL content and paste in SQL Editor
5. Click "Run" (bottom right)
6. Wait for "Success" message

---

## Step 4: Test (30 seconds)

1. Close and restart your app
2. Click "Check OAuth Setup Status" button
3. Should see ✅ green checkmarks
4. Click "Sign in with Google"
5. Browser will open for Google authentication
6. Select your Google account
7. You'll be signed in!

---

## 🆘 Having Issues?

### Error: "OAuth not configured"
- ✅ Check you completed Step 1 & 2
- ✅ Make sure you clicked "Save" in Supabase
- ✅ Wait 30 seconds for changes to propagate
- ✅ Restart the app

### Error: "Redirect URI mismatch"
- ✅ Verify BOTH URLs are in Google Console:
  - `https://olrrbyrzrotojsjkqcxr.supabase.co/auth/v1/callback`
  - `http://localhost:54321/auth/callback`
- ✅ No trailing slash, no extra spaces
- ✅ Make sure to save changes in Google Cloud Console

### Error: "No user after Google sign in" or "localhost refused to connect"
**This should now be FIXED with the new implementation:**

#### What changed:
- ✅ The app now starts a **local callback server** on port 54321
- ✅ After you complete Google sign-in, it redirects to `localhost:54321`
- ✅ The app captures the authentication and closes the server automatically

#### If you still see the error:
1. **Make sure port 54321 is not used by another application**
   - Close other development servers
   - Check Windows Task Manager for processes using that port
   
2. **Restart the app completely**
   - Close the app
   - Start it again
   - Try Google Sign In

3. **Check Windows Firewall**
   - The app needs permission to start a local HTTP server
   - If prompted, allow the app through your firewall
   
4. **Verify both redirect URLs are added** (see step above)

5. **Check the debug output**
   - Look for: "✅ Local callback server started on port 54321"
   - If you see: "⚠️ Port 54321 might be in use" - choose a different port or close the blocking app

### Browser doesn't open
- ✅ Check Windows firewall settings
- ✅ Try running app as administrator
- ✅ Make sure default browser is set

### Authentication times out
- ✅ Complete the Google sign-in within 30 seconds
- ✅ If timeout occurs, try again
- ✅ Check your internet connection speed

### Still stuck?
- Check full guide: `SUPABASE_OAUTH_SETUP_GUIDE.md`
- View database schema: `SUPABASE_SCHEMA.sql`

---

## ✨ After Setup is Complete

Your system will have:
- 🔐 Secure Google authentication
- ☁️ Multi-device cloud sync
- 📊 Real-time data synchronization
- 🔄 Automatic backups
- 🌐 Access from any device

The one-time setup unlocks all cloud features! 🚀
