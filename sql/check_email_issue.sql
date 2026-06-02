-- ============================================================================
-- SUPABASE SQL QUERIES - Email Issue Troubleshooting
-- ============================================================================
-- Paste these queries in Supabase SQL Editor to check your activation system
-- Dashboard: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/sql
-- ============================================================================

-- ============================================================================
-- 1. CHECK ASSIGNED CODE THAT FAILED TO EMAIL
-- ============================================================================
-- Find the code that was assigned but email failed

SELECT 
  code,
  package_name,
  status,
  assigned_at,
  device_id,
  device_name
FROM activation_codes
WHERE code = '88VDIX91QGS5GAX4WQOJ';

-- Expected result: status = 'assigned' (ready for customer to activate)

-- ============================================================================
-- 2. VIEW ALL RECENT ACTIVATION CODE ASSIGNMENTS
-- ============================================================================
-- See last 10 codes that were assigned to customers

SELECT 
  code,
  package_name,
  status,
  assigned_at,
  device_id,
  created_at
FROM activation_codes
WHERE status IN ('assigned', 'used')
ORDER BY 
  CASE 
    WHEN assigned_at IS NOT NULL THEN assigned_at
    WHEN used_at IS NOT NULL THEN used_at
    ELSE created_at
  END DESC
LIMIT 10;

-- ============================================================================
-- 3. COUNT CODES BY STATUS
-- ============================================================================
-- Quick overview of your activation code inventory

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
-- 4. CHECK CUSTOMER ACTIVATION CODE REQUESTS
-- ============================================================================
-- View pending and fulfilled customer requests

SELECT 
  customer_email,
  business_name,
  package_name,
  status,
  request_date,
  fulfilled_at,
  assigned_code
FROM activation_code_requests
ORDER BY request_date DESC
LIMIT 20;

-- ============================================================================
-- 5. FIND CUSTOMER REQUEST THAT TRIGGERED EMAIL FAILURE
-- ============================================================================
-- Find the specific request for jay-begubot

SELECT 
  customer_email,
  business_name,
  package_name,
  status,
  request_date,
  fulfilled_at,
  assigned_code
FROM activation_code_requests
WHERE customer_email = 'jay-begubot@student.trimexcolleges.edu.ph'
ORDER BY request_date DESC
LIMIT 5;

-- ============================================================================
-- 6. MANUALLY MARK REQUEST AS EMAIL SENT (if you emailed manually)
-- ============================================================================
-- Only run this AFTER you manually send the email to the customer
-- Uncomment the UPDATE below after manual email is sent

/*
UPDATE activation_code_requests
SET notes = COALESCE(notes || ' | ', '') || 'Email sent manually on ' || NOW()::date::text
WHERE customer_email = 'jay-begubot@student.trimexcolleges.edu.ph'
  AND assigned_code = '88VDIX91QGS5GAX4WQOJ';
*/

-- ============================================================================
-- 7. CHECK IF CODE IS READY FOR CUSTOMER ACTIVATION
-- ============================================================================
-- Verify the code is in correct state for customer to use

SELECT 
  code,
  status,
  package_name,
  CASE 
    WHEN status = 'assigned' THEN 'Ready to activate'
    WHEN status = 'unused' THEN 'Not yet assigned to customer'
    WHEN status = 'used' THEN 'Already activated'
    WHEN status = 'revoked' THEN 'Code has been revoked'
    ELSE 'Unknown status'
  END as customer_can_use
FROM activation_codes
WHERE code = '88VDIX91QGS5GAX4WQOJ';

-- ============================================================================
-- 8. GET CUSTOMER'S PACKAGE INFO (for manual email)
-- ============================================================================
-- Get details to include in manual email

SELECT 
  req.customer_email,
  req.business_name,
  req.package_name,
  req.assigned_code as activation_code,
  ac.status as code_status
FROM activation_code_requests req
LEFT JOIN activation_codes ac ON ac.code = req.assigned_code
WHERE req.customer_email = 'jay-begubot@student.trimexcolleges.edu.ph'
  AND req.assigned_code = '88VDIX91QGS5GAX4WQOJ';

-- ============================================================================
-- NOTES
-- ============================================================================
-- After fixing Gmail credentials:
-- 1. Run commands in PASTE_THESE_COMMANDS.md (PowerShell)
-- 2. Test by fulfilling another customer request
-- 3. Check logs: supabase functions logs send-activation-code --follow
-- 4. Manually email customer using template in PASTE_THESE_COMMANDS.md
-- ============================================================================
