-- ============================================================================
-- DIAGNOSTIC QUERIES - Activation Codes Expiry Issue
-- ============================================================================
-- Copy and paste these queries one by one into Supabase SQL Editor
-- Run each query and review results to identify the problem
-- ============================================================================

-- ============================================================================
-- STEP 0: Check what columns exist in activation_codes table
-- ============================================================================
-- Run this first to see the actual table structure

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'activation_codes'
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================================================
-- STEP 1: Check activation_codes status distribution
-- ============================================================================
-- Expected: status should be 'unused', 'assigned', 'used', or 'revoked'
-- If you see 'expired' status here, that's the problem!

SELECT 
  status,
  COUNT(*) as count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM activation_codes
GROUP BY status
ORDER BY count DESC;

-- ============================================================================
-- STEP 2: Find any activation_codes incorrectly marked 'expired'
-- ============================================================================
-- activation_codes should NEVER have status='expired' 
-- Only subscriptions table should have expired status!

SELECT 
  code,
  package_name,
  status,
  device_id,
  device_name,
  created_at,
  used_at
FROM activation_codes
WHERE status = 'expired'
ORDER BY code
LIMIT 100;

-- If you see results above, that's your problem - codes were wrongly marked!

-- ============================================================================
-- STEP 3: Check subscriptions expiry status (this is normal)
-- ============================================================================
-- subscriptions table CAN have status='expired' (this is expected)

SELECT 
  status,
  COUNT(*) as count
FROM subscriptions
GROUP BY status
ORDER BY status;

-- ============================================================================
-- STEP 4: View recent subscriptions (active and expired)
-- ============================================================================

SELECT 
  device_name,
  package_name,
  activation_code,
  status,
  activated_at::date as activated,
  expires_at::date as expires,
  CASE 
    WHEN expires_at > NOW() THEN EXTRACT(DAY FROM expires_at - NOW())::int
    ELSE 0
  END as days_remaining
FROM subscriptions
ORDER BY expires_at DESC
LIMIT 30;

-- ============================================================================
-- STEP 5: Check for unused codes with old created_at dates
-- ============================================================================
-- Old unused codes are still valid (codes don't expire until activated)

SELECT 
  COUNT(*) as unused_codes,
  MIN(created_at)::date as oldest_code,
  MAX(created_at)::date as newest_code
FROM activation_codes
WHERE status = 'unused';

-- ============================================================================
-- FIX QUERIES - Only run these AFTER confirming the problem above
-- ============================================================================

-- ============================================================================
-- FIX 1: Restore wrongly marked 'expired' activation codes
-- ============================================================================
-- IMPORTANT: Only run this if STEP 2 returned results with status='expired'
-- This fixes codes that were never actually used (device_id is NULL)

-- Preview what will be fixed (run this first):
SELECT 
  code,
  package_name,
  status,
  device_id,
  created_at
FROM activation_codes
WHERE status = 'expired' AND device_id IS NULL;

-- If the above looks correct, run this to fix:
/*
UPDATE activation_codes
SET status = 'unused'
WHERE status = 'expired' 
  AND device_id IS NULL;
*/

-- ============================================================================
-- FIX 2: Reset created_at for old unused codes (optional)
-- ============================================================================
-- Only run if you want to reset timestamps on unused codes

-- Preview what will be updated:
SELECT 
  COUNT(*) as codes_to_update,
  MIN(created_at)::date as oldest,
  MAX(created_at)::date as newest
FROM activation_codes
WHERE status = 'unused' 
  AND created_at < NOW() - INTERVAL '30 days';

-- If you want to reset these timestamps, run:
/*
UPDATE activation_codes
SET created_at = NOW()
WHERE status = 'unused' 
  AND created_at < NOW() - INTERVAL '30 days';
*/

-- ============================================================================
-- FIX 3: If codes were used but wrongly marked expired, restore to 'used'
-- ============================================================================
-- IMPORTANT: Only run if codes have device_id (they were activated)

-- Preview:
SELECT 
  code,
  package_name,
  status,
  device_id,
  device_name,
  used_at
FROM activation_codes
WHERE status = 'expired' 
  AND device_id IS NOT NULL;

-- If these codes were legitimately used, restore them:
/*
UPDATE activation_codes
SET status = 'used'
WHERE status = 'expired' 
  AND device_id IS NOT NULL;
*/

-- ============================================================================
-- VERIFICATION QUERIES - Run these after applying fixes
-- ============================================================================

-- Verify no more 'expired' codes exist:
SELECT COUNT(*) as expired_codes_remaining
FROM activation_codes
WHERE status = 'expired';
-- Expected: 0

-- Count available codes by package:
SELECT 
  package_name,
  COUNT(*) as unused_count
FROM activation_codes
WHERE status = 'unused'
GROUP BY package_name
ORDER BY package_name;

-- Check total codes status:
SELECT 
  status,
  COUNT(*) as count
FROM activation_codes
GROUP BY status
ORDER BY 
  CASE status
    WHEN 'unused' THEN 1
    WHEN 'assigned' THEN 2
    WHEN 'used' THEN 3
    WHEN 'revoked' THEN 4
    ELSE 5
  END;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- After running diagnostics:
-- 1. If STEP 2 shows 'expired' codes → Run appropriate FIX query
-- 2. If STEP 3 shows expired subscriptions → This is NORMAL (monthly rental)
-- 3. Verify fixes worked using VERIFICATION queries
-- 
-- Root cause is likely:
-- - Someone ran UPDATE activation_codes SET status='expired' by mistake
-- - Should have been: UPDATE subscriptions SET status='expired'
-- 
-- Prevention:
-- - Set up RLS policies to restrict updates on activation_codes
-- - Only allow service_role to update activation_codes
-- - Document that only subscriptions table has 'expired' status
-- ============================================================================
