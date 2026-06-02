-- ============================================================================
-- FIX: Extend All Expired Activation Code Subscriptions
-- ============================================================================
-- 
-- Run this SQL in Supabase SQL Editor to extend all expired subscriptions
-- to 30 days from now.
--
-- IMPORTANT:
-- 1. Go to Supabase Dashboard → SQL Editor
-- 2. Copy and paste the SQL below
-- 3. Click "Run" to execute
-- 4. Check the results - you should see X rows updated
-- 5. Go to Table Editor → subscriptions to verify expires_at dates
--
-- ============================================================================

-- Check how many subscriptions are currently expired
SELECT 
  COUNT(*) as total_subscriptions,
  SUM(CASE WHEN expires_at < NOW() THEN 1 ELSE 0 END) as expired_count,
  SUM(CASE WHEN expires_at >= NOW() THEN 1 ELSE 0 END) as active_count,
  MIN(expires_at) as oldest_expiry,
  MAX(expires_at) as latest_expiry
FROM subscriptions;

-- ============================================================================
-- OPTION 1: Extend ALL subscriptions to 30 days from now
-- ============================================================================
-- Use this if you want to give all users a fresh 30-day trial/license

UPDATE subscriptions
SET 
  expires_at = NOW() + INTERVAL '30 days',
  status = 'active'
WHERE expires_at < NOW();

-- Verify: Check updated subscriptions
SELECT 
  id,
  device_id,
  activation_code,
  package_name,
  status,
  expires_at,
  EXTRACT(DAY FROM (expires_at - NOW())) as days_remaining
FROM subscriptions
WHERE status = 'active'
ORDER BY expires_at ASC;

-- ============================================================================
-- OPTION 2: Reset only already-activated subscriptions (if you used codes)
-- ============================================================================
-- Use this if you want to extend subscriptions that were actively used

UPDATE subscriptions
SET 
  expires_at = activated_at + INTERVAL '30 days',
  status = 'active'
WHERE activation_code IS NOT NULL 
  AND STATUS != 'cancelled'
  AND expires_at < NOW();

-- ============================================================================
-- OPTION 3: Manually set expiry to a specific date
-- ============================================================================
-- Example: Set all expiries to April 1, 2026

UPDATE subscriptions
SET 
  expires_at = '2026-04-01 23:59:59+00',
  status = 'active'
WHERE expires_at < NOW();

-- ============================================================================
-- After running any of the above:
-- 1. Restart your Flutter app
-- 2. The licenses should now be unlocked
-- 3. Monitor the subscription expiry dates
-- ============================================================================

-- Check the final state
SELECT 
  COUNT(*) as active_subscriptions,
  MIN(expires_at) as oldest_remaining,
  MAX(expires_at) as latest_remaining,
  AVG(EXTRACT(DAY FROM (expires_at - NOW()))) as avg_days_remaining
FROM subscriptions
WHERE status = 'active';
