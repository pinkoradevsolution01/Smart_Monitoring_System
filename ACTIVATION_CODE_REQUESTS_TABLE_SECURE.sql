-- ============================================================================
-- Activation Code Requests Table - SECURE VERSION
-- ============================================================================
-- Creates the activation_code_requests table with proper security settings
-- Fixes:
--   1. Function search_path set to public (SECURITY DEFINER)
--   2. RLS policies restricted to authenticated users where appropriate
--   3. Intentional: INSERT allows public (customers submit requests)
-- ============================================================================

-- Drop existing objects if upgrading
DROP TRIGGER IF EXISTS activation_requests_updated_at ON activation_code_requests CASCADE;
DROP FUNCTION IF EXISTS update_activation_requests_updated_at() CASCADE;
DROP POLICY IF EXISTS "Allow insert activation requests" ON activation_code_requests;
DROP POLICY IF EXISTS "Allow read activation requests" ON activation_code_requests;
DROP POLICY IF EXISTS "Allow update activation requests" ON activation_code_requests;

-- Create or recreate table
CREATE TABLE IF NOT EXISTS activation_code_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name TEXT NOT NULL,
  package_name TEXT NOT NULL,
  package_price TEXT NOT NULL,
  request_type TEXT NOT NULL CHECK (request_type IN ('monthly', 'trial')),
  contact_email TEXT NOT NULL,
  contact_phone TEXT NOT NULL,
  additional_notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'fulfilled')),
  activation_code TEXT,
  requested_at TIMESTAMPTZ NOT NULL,
  fulfilled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_activation_requests_status ON activation_code_requests(status);
CREATE INDEX IF NOT EXISTS idx_activation_requests_requested_at ON activation_code_requests(requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_activation_requests_customer ON activation_code_requests(contact_email);

-- ============================================================================
-- Row-Level Security (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE activation_code_requests ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow public INSERT (customers submit activation requests)
-- INTENTIONAL: This is designed to allow customers (unauthenticated) to submit requests
-- Validated by app-level checks (email format, non-empty fields)
CREATE POLICY "Allow public insert activation requests"
  ON activation_code_requests
  FOR INSERT
  WITH CHECK (
    -- Basic validation to prevent abuse
    business_name IS NOT NULL AND business_name != '' AND
    contact_email IS NOT NULL AND contact_email LIKE '%@%' AND
    contact_phone IS NOT NULL AND contact_phone != '' AND
    package_name IS NOT NULL AND package_name != ''
  );

-- Policy 2: Allow authenticated users (developers) to read all requests
CREATE POLICY "Developers can read activation requests"
  ON activation_code_requests
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Policy 3: Allow authenticated users (developers) to update requests
CREATE POLICY "Developers can update activation requests"
  ON activation_code_requests
  FOR UPDATE
  USING (auth.role() = 'authenticated');

-- ============================================================================
-- Updated At Trigger
-- ============================================================================
-- SECURITY FIX: Added SECURITY DEFINER and SET search_path = public
CREATE OR REPLACE FUNCTION update_activation_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER activation_requests_updated_at
  BEFORE UPDATE ON activation_code_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_activation_requests_updated_at();

-- ============================================================================
-- Comments and Documentation
-- ============================================================================

COMMENT ON TABLE activation_code_requests IS 
'Stores customer requests for activation codes. Customers (public users) can INSERT. Developers (authenticated) can READ and UPDATE.';

COMMENT ON POLICY "Allow public insert activation requests" ON activation_code_requests IS
'Allows customers to submit activation code requests with basic email/phone validation.';

COMMENT ON POLICY "Developers can read activation requests" ON activation_code_requests IS
'Allows authenticated developers to view all pending and fulfilled requests.';

COMMENT ON POLICY "Developers can update activation requests" ON activation_code_requests IS
'Allows authenticated developers to fulfill requests by updating status and activation_code.';

COMMENT ON FUNCTION update_activation_requests_updated_at() IS
'Automatically updates the updated_at timestamp on record modification. SECURITY DEFINER prevents search_path mutable warning.';

-- ============================================================================
-- Sample Query (for testing)
-- ============================================================================
/*
-- View all pending requests
SELECT 
  id, 
  business_name, 
  contact_email, 
  package_name, 
  request_type,
  requested_at,
  status
FROM activation_code_requests
WHERE status = 'pending'
ORDER BY requested_at DESC;

-- View fulfilled requests with their codes
SELECT 
  id,
  business_name,
  contact_email,
  activation_code,
  fulfilled_at
FROM activation_code_requests
WHERE status = 'fulfilled'
ORDER BY fulfilled_at DESC;

-- Count requests by status
SELECT 
  status,
  COUNT(*) as count
FROM activation_code_requests
GROUP BY status;
*/

-- ============================================================================
-- Post-Deployment Steps (Manual)
-- ============================================================================
-- 1. ENABLE LEAKED PASSWORD PROTECTION (optional but recommended):
--    Go to Supabase Dashboard > Authentication > Password & Session
--    Toggle "Enable leaked password protection" to ON
--
-- 2. VERIFY RLS is working:
--    - Try inserting as anonymous user (should work with valid data)
--    - Try reading as unauthenticated user (should fail with RLS policy denied)
--    - Try reading as authenticated developer (should work)
--
-- 3. Test Edge Function:
--    supabase functions deploy notify-activation-request
--    supabase functions logs notify-activation-request
--
-- ============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT ON activation_code_requests TO anon;
GRANT SELECT, UPDATE ON activation_code_requests TO authenticated;
