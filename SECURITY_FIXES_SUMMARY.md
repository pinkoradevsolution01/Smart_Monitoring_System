# 🔒 Activation Code Requests - Security Fixes

## Issues Fixed

### 1. ✅ Function Search Path Mutable (FIXED)

**Issue:** The `update_activation_requests_updated_at()` function had a mutable search_path, creating a security vulnerability.

**Fix Applied:**
```sql
CREATE OR REPLACE FUNCTION update_activation_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;  -- ← FIXED
```

**What Changed:**
- Added `SECURITY DEFINER` - function runs with creator's privileges
- Added `SET search_path = public` - locks search path to prevent search_path injection attacks

---

### 2. ✅ RLS Policy Too Permissive (FIXED)

**Original Issue:** The INSERT policy used `WITH CHECK (true)` allowing unrestricted access.

**Original Code:**
```sql
CREATE POLICY "Allow insert activation requests"
  ON activation_code_requests
  FOR INSERT
  WITH CHECK (true);  -- ← TOO PERMISSIVE
```

**Fix Applied:**
```sql
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
```

**What Changed:**
- Added email format check (`LIKE '%@%'`)
- Added NOT NULL and non-empty string checks
- Prevents insertion of incomplete/invalid requests
- Still allows public (unauthenticated) insert - **INTENTIONAL** (customers need to submit requests)

---

### 3. ⚠️ Leaked Password Protection - MANUAL SETUP

**Issue:** Supabase Auth is NOT checking against compromised passwords (HaveIBeenPwned.org).

**How to Enable:**

1. **Open Supabase Dashboard** → Your Project
2. **Go to Authentication** (left sidebar) → **Providers**
3. **Click "Auth"** tab
4. **Scroll to "Leaked Password Protection"**
5. **Toggle ON** ✓

Or use Supabase CLI:
```bash
supabase set auth.security.leaked_password_protection_enabled=true --project-ref YOUR_PROJECT_REF
```

**What It Does:**
- Before login, checks password against HaveIBeenPwned database
- Blocks login if password has been compromised in data breaches
- Prevents account takeover on your system
- No password data is sent to external services (only hashed check)

---

## How to Deploy

### Option A: Upgrade Existing Table (RECOMMENDED)

Run the new secure SQL script in Supabase SQL Editor:

```bash
# Copy all contents from:
ACTIVATION_CODE_REQUESTS_TABLE_SECURE.sql

# Paste into Supabase Dashboard > SQL Editor > New Query
# Run the query
```

This will:
- ✅ Drop old insecure policies
- ✅ Recreate with new security constraints
- ✅ Add search_path fix to trigger function
- ✅ Keep all existing data

### Option B: Fresh Install

```bash
# Use the new secure SQL file:
cat ACTIVATION_CODE_REQUESTS_TABLE_SECURE.sql | supabase db push
```

---

## Verify Security

### Test 1: Function Search Path Fixed
```sql
-- Check function definition
SELECT prosecdef, proconfig 
FROM pg_proc 
WHERE proname = 'update_activation_requests_updated_at';
-- Should show: prosecdef=true, proconfig includes search_path
```

### Test 2: RLS Policies Enforced
```sql
-- Try inserting as anonymous with INVALID data
SELECT auth.jwt(); -- Should be NULL (no auth)

INSERT INTO activation_code_requests 
  (business_name, package_name, package_price, request_type, 
   contact_email, contact_phone, requested_at)
VALUES 
  ('', '', '', 'monthly', 'invalid-email', '', NOW());
-- Should FAIL: email invalid, business_name empty
```

```sql
-- Try inserting with VALID data
INSERT INTO activation_code_requests 
  (business_name, package_name, package_price, request_type, 
   contact_email, contact_phone, requested_at)
VALUES 
  ('ABC Corp', 'Basic', '₱2,500', 'monthly', 'contact@example.com', '+63 912 345 6789', NOW());
-- Should SUCCEED: all fields valid
```

### Test 3: Developer Restrictions
```sql
-- Authenticated users can read
SELECT * FROM activation_code_requests;
-- As authenticated user: should see all records
-- As anonymous: should fail with RLS policy error
```

---

## Security Summary

| Issue | Status | Fix |
|-------|--------|-----|
| Function search_path mutable | ✅ FIXED | Added `SECURITY DEFINER SET search_path = public` |
| RLS INSERT too permissive | ✅ FIXED | Added email/data validation checks |
| Leaked password protection | ⚠️ MANUAL | Enable in Auth settings (optional but recommended) |

---

## Best Practices Going Forward

1. **Validate data server-side** (✅ done in RLS policy)
2. **Use SECURITY DEFINER for triggers** (✅ done)
3. **Set search_path explicitly** (✅ done)
4. **Enable password protection** (you should do this)
5. **Regularly review RLS policies** (make it a habit)
6. **Monitor Edge Function logs** (check for errors)

---

## Files

| File | Purpose | Status |
|------|---------|--------|
| `ACTIVATION_CODE_REQUESTS_TABLE_SECURE.sql` | Updated secure schema | ✅ Ready to use |
| `ACTIVATION_CODE_REQUESTS_TABLE.sql` | Original (has security issues) | ⚠️ Replace with secure version |

---

## Next Steps

1. **Today:** Run the secure SQL in Supabase
2. **Today:** Enable leaked password protection
3. **Tomorrow:** Test with customer requests
4. **This week:** Monitor Edge Function logs

---

**Last Updated:** February 12, 2026  
**Security Status:** ✅ IMPROVED
