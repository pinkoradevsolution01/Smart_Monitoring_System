/// Supabase configuration for license activation and cross-device sync
class SupabaseConfig {
  //  Replace with your actual Supabase project credentials
  // Get these from: https://app.supabase.com/project/_/settings/api

  /// Your Supabase project URL
  /// Format: https://xxxxxxxxxxxxx.supabase.co
  static const String supabaseUrl = 'https://olrrbyrzrotojsjkqcxr.supabase.co';

  /// Your Supabase anon/public key
  /// This is safe to expose in client-side code
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9scnJieXJ6cm90b2pzamtxY3hyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2MjQxNDYsImV4cCI6MjA4NjIwMDE0Nn0.bv91cJbDYo1HI5KXHt979rgfWabGt4URWDnJGc1WTYI';

  /// Your Supabase service role key (ADMIN ONLY - DO NOT EXPOSE IN CLIENT)
  /// Get this from: Supabase Dashboard → Settings → API → service_role key
  /// This key bypasses Row Level Security - use ONLY for admin operations
  static const String supabaseServiceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9scnJieXJ6cm90b2pzamtxY3hyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDYyNDE0NiwiZXhwIjoyMDg2MjAwMTQ2fQ.61TcNb-cReNARnE2gdxHZUcn5rL8nwyuCoh9cy9cyZM'; // Replace with actual service_role key

  /// Check if Supabase is configured
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseUrl.startsWith('https://olrrbyrzrotojsjkqcxr.supabase.co') &&
      supabaseAnonKey.isNotEmpty;

  /// Derived functions URL for Supabase Edge Functions
  /// e.g. https://&lt;project&gt;.functions.supabase.co
  static String get supabaseFunctionsUrl {
    if (supabaseUrl.contains('.supabase.co')) {
      return supabaseUrl.replaceFirst('.supabase.co', '.functions.supabase.co');
    }
    return supabaseUrl;
  }

  // =========================================================================
  // GMAIL OAUTH ACCESS CONTROL
  // =========================================================================

  /// Whitelist of specific admin email addresses allowed to sign in
  /// Leave empty ([]) to allow ALL Gmail accounts (development mode)
  /// Add specific emails for production: ['admin@company.com', 'owner@store.com']
  static const List<String> allowedAdminEmails = [
    // Founder - Add your Gmail address here:
    // 'your.email@gmail.com',  // Replace with your actual Gmail

    // Example: 'johndoe@gmail.com',
    // Example: 'admin@yourcompany.com',
  ];

  /// Whitelist of email domains allowed to sign in
  /// Leave empty ([]) to disable domain check
  /// Add domains for organization-wide access: ['yourcompany.com', 'corp.com']
  static const List<String> allowedAdminDomains = [
    // Example: 'yourcompany.com',
    // Example: 'trustedpartner.com',
  ];

  /// Check if email is in the allowed emails list
  static bool isAdminEmail(String email) {
    if (allowedAdminEmails.isEmpty) return true; // Allow all if empty
    return allowedAdminEmails.contains(email.toLowerCase());
  }

  /// Check if email domain is in the allowed domains list
  static bool isAdminDomain(String email) {
    if (allowedAdminDomains.isEmpty) return true; // Allow all if empty
    final domain = email.split('@').last.toLowerCase();
    return allowedAdminDomains.any((d) => domain == d.toLowerCase());
  }

  /// Check if email is authorized to access admin panel
  /// Returns true if email is in allowedAdminEmails OR domain is in allowedAdminDomains
  /// Returns true if both lists are empty (development mode)
  static bool isAuthorizedAdmin(String email) {
    // If both lists are empty, allow all (development mode)
    if (allowedAdminEmails.isEmpty && allowedAdminDomains.isEmpty) {
      return true;
    }

    // Check specific email OR domain
    return isAdminEmail(email) || isAdminDomain(email);
  }
}

/* ============================================================================
 * SUPABASE SETUP INSTRUCTIONS
 * ============================================================================
 * 
 * Follow these steps to set up Supabase for your license activation system:
 * 
 * STEP 1: Create Supabase Account (FREE)
 * ----------------------------------------
 * 1. Go to https://supabase.com
 * 2. Click "Start your project" and sign up with GitHub
 * 3. Create a new organization (e.g., "Smart Monitoring System")
 * 4. Create a new project:
 *    - Name: smart-monitoring-system
 *    - Database Password: (save this securely!)
 *    - Region: Choose closest to your customers (Southeast Asia)
 *    - Pricing Plan: Free Tier (no credit card required)
 * 
 * STEP 2: Get API Credentials
 * ----------------------------
 * 1. In your Supabase dashboard, go to Settings → API
 * 2. Copy your "Project URL" and replace YOUR_SUPABASE_URL above
 * 3. Copy your "anon public" key and replace YOUR_SUPABASE_ANON_KEY above
 * 
 * STEP 3: Create Database Tables
 * -------------------------------
 * 1. Go to SQL Editor in Supabase dashboard
 * 2. Copy and paste the schema from SUPABASE_SCHEMA.md
 * 3. Click "Run" to create tables
 * 
 * STEP 4: Import Activation Codes
 * --------------------------------
 * 1. Go to Table Editor → activation_codes
 * 2. Click "Insert" → "Insert rows"
 * 3. Upload your ACTIVATION_CODES.txt codes:
 *    - code: 6B67B63WSGMEOYUC0L4Y
 *    - package_name: Basic (or Standard/Premium)
 *    - status: unused
 *    - created_at: (auto-filled)
 * 4. Repeat for all 100 codes (or use CSV import)
 * 
 * STEP 5: Test Connection
 * ------------------------
 * 1. Run your Flutter app: flutter run
 * 2. Go to Package Selection → Get Started - Monthly
 * 3. Enter activation code: 6B67B63WSGMEOYUC0L4Y
 * 4. Check Supabase dashboard → Table Editor → activation_codes
 * 5. Code status should change to "used"
 * 6. Check subscriptions table for new entry
 * 
 * STEP 6: Security Settings (IMPORTANT!)
 * ---------------------------------------
 * 1. Go to Authentication → Policies
 * 2. Enable Row Level Security (RLS) on all tables
 * 3. Add policies (see SUPABASE_SCHEMA.md for policy SQL)
 * 
 * FREE TIER LIMITS:
 * -----------------
 * ✅ 500MB database storage (enough for 10,000+ activations)
 * ✅ 50,000 monthly active users
 * ✅ 2GB bandwidth/month
 * ✅ Unlimited API requests
 * ✅ Automatic backups (7 days retention)
 * 
 * UPGRADE TO PRO (₱1,200/month) WHEN:
 * -----------------------------------
 * - You exceed 50 active devices
 * - Need daily backups with point-in-time recovery
 * - Want email support
 * - Need more than 500MB storage
 * 
 * TROUBLESHOOTING:
 * ----------------
 * - "Invalid API credentials": Double-check URL and anon key
 * - "Table does not exist": Run the schema SQL from SUPABASE_SCHEMA.md
 * - "Row Level Security": Disable RLS or add proper policies
 * - "Code not found": Make sure codes are imported to activation_codes table
 * 
 * ============================================================================ */
