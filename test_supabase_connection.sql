-- ============================================================================
-- SUPABASE CONNECTION TEST QUERIES
-- ============================================================================
-- Copy and paste these queries in Supabase SQL Editor to verify setup
-- Dashboard: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/sql
-- ============================================================================

-- ============================================================================
-- TEST 1: Check if tables exist
-- ============================================================================
SELECT 
  tablename, 
  schemaname,
  hasindexes,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('activation_codes', 'subscriptions', 'subscription_renewals')
ORDER BY tablename;

-- Expected: 3 rows (one for each table)
-- If you see fewer, some tables are missing

-- ============================================================================
-- TEST 2: Count activation codes by status
-- ============================================================================
SELECT 
  status,
  COUNT(*) as total_codes
FROM activation_codes
GROUP BY status
ORDER BY status;

-- Expected: Shows breakdown by status (unused, used, revoked)
-- If ERROR: "relation activation_codes does not exist" → Upload CSV first!

-- ============================================================================
-- TEST 3: View sample unused codes (for testing)
-- ============================================================================
SELECT 
  code,
  package_name,
  status,
  created_at
FROM activation_codes
WHERE status = 'unused'
ORDER BY created_at DESC
LIMIT 5;

-- Expected: Shows 5 unused codes
-- Copy one of these codes for testing activation

-- ============================================================================
-- TEST 4: Check RLS (Row Level Security) policies
-- ============================================================================
SELECT 
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('activation_codes', 'subscriptions', 'subscription_renewals')
ORDER BY tablename, policyname;

-- Expected: Multiple policies shown
-- activation_codes: 4 policies
-- subscriptions: 4 policies
-- subscription_renewals: 3 policies

-- ============================================================================
-- TEST 5: Verify anon key can read unused codes (simulates Flutter app)
-- ============================================================================
-- This query uses the same permissions as your Flutter app
SELECT COUNT(*) as accessible_codes
FROM activation_codes
WHERE status = 'unused';

-- Expected: Shows count of unused codes
-- If 0: No codes uploaded yet
-- If ERROR: RLS policies not configured

-- ============================================================================
-- TEST 6: Check subscription records
-- ============================================================================
SELECT 
  COUNT(*) as total_subscriptions,
  SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active,
  SUM(CASE WHEN status = 'expired' THEN 1 ELSE 0 END) as expired,
  SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled
FROM subscriptions;

-- Expected: Shows subscription breakdown
-- If ERROR: Table doesn't exist → Run SECTION 2 from SUPABASE_SQL_COMPLETE.md

-- ============================================================================
-- TEST 7: View recent activations (if any)
-- ============================================================================
SELECT 
  ac.code,
  ac.package_name,
  ac.used_at,
  ac.device_name,
  s.status as subscription_status,
  s.expires_at
FROM activation_codes ac
LEFT JOIN subscriptions s ON s.activation_code = ac.code
WHERE ac.status = 'used'
ORDER BY ac.used_at DESC
LIMIT 5;

-- Expected: Shows recently activated codes (if any exist)
-- Empty result is OK if no activations yet

-- ============================================================================
-- TEST 8: Check database size (Free tier: 500MB limit)
-- ============================================================================
SELECT pg_size_pretty(pg_database_size('postgres')) as database_size;

-- Expected: Shows current database size (should be < 500MB)

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================

-- If TEST 2 fails with "relation activation_codes does not exist":
-- → Go to Table Editor → Import data via spreadsheet
-- → Upload your activation_codes_import.csv
-- → Then run SECTION 1 from SUPABASE_SQL_COMPLETE.md

-- If TEST 4 shows no policies:
-- → Run SECTION 1 (Activation Codes RLS Policies) from SUPABASE_SQL_COMPLETE.md
-- → Run SECTION 3 (Subscriptions RLS Policies) from SUPABASE_SQL_COMPLETE.md

-- If TEST 5 returns 0 rows:
-- → Generate codes: Developer Dashboard → Activation Code Generator
-- → Export CSV
-- → Upload to Supabase Table Editor

-- ============================================================================
-- QUICK SETUP CHECKLIST
-- ============================================================================
-- [ ] Tables exist (activation_codes, subscriptions, subscription_renewals)
-- [ ] RLS policies configured (11+ policies total)
-- [ ] Activation codes uploaded (status='unused')
-- [ ] Flutter app can connect (supabase_config.dart configured)
-- [ ] Test code activation works (enter code in app)

-- ============================================================================
-- SUCCESS CRITERIA
-- ============================================================================
-- ✅ All 3 tables exist
-- ✅ RLS is enabled on all tables
-- ✅ At least 1 unused activation code exists
-- ✅ No permission errors when querying
-- ✅ Database size < 500MB
