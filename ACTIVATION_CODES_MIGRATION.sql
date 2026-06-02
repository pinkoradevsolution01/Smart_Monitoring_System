-- ============================================================================
-- Activation Codes Migration - One-Click Setup
-- ============================================================================
-- Run this entire script in Supabase SQL Editor
-- Adds 'assigned' status support and proper RLS policies
-- ============================================================================

-- 1. Add assigned_at column if it doesn't exist
-- ============================================================================
ALTER TABLE IF EXISTS activation_codes
ADD COLUMN IF NOT EXISTS assigned_at timestamptz;

COMMENT ON COLUMN activation_codes.assigned_at IS 'Timestamp when code was assigned to customer by developer';

-- 2. Ensure 'assigned' status is allowed
-- ============================================================================
-- Check if status column is an ENUM or TEXT/VARCHAR
DO $$
DECLARE
    status_type text;
BEGIN
    -- Get the data type of status column
    SELECT data_type INTO status_type
    FROM information_schema.columns
    WHERE table_name = 'activation_codes'
    AND column_name = 'status';
    
    -- If it's a USER-DEFINED type (enum), try to add 'assigned'
    IF status_type = 'USER-DEFINED' THEN
        BEGIN
            -- Get the enum type name
            DECLARE enum_name text;
            BEGIN
                SELECT udt_name INTO enum_name
                FROM information_schema.columns
                WHERE table_name = 'activation_codes'
                AND column_name = 'status';
                
                -- Try to add 'assigned' value to enum
                EXECUTE format('ALTER TYPE %I ADD VALUE IF NOT EXISTS %L', enum_name, 'assigned');
                RAISE NOTICE 'Added "assigned" to enum type %', enum_name;
            END;
        EXCEPTION
            WHEN duplicate_object THEN
                RAISE NOTICE '"assigned" already exists in enum';
            WHEN OTHERS THEN
                RAISE NOTICE 'Could not modify enum, but continuing: %', SQLERRM;
        END;
    ELSE
        -- Status is TEXT/VARCHAR, no action needed
        RAISE NOTICE 'Status column is %, no enum modification needed', status_type;
    END IF;
END
$$;

-- 3. Create index for faster queries on assigned codes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_activation_codes_status_package 
ON activation_codes(status, package_name) 
WHERE status IN ('unused', 'assigned');

CREATE INDEX IF NOT EXISTS idx_activation_codes_assigned_at 
ON activation_codes(assigned_at) 
WHERE assigned_at IS NOT NULL;

-- 4. Drop existing RLS policies (if any) and recreate
-- ============================================================================
DO $$
BEGIN
    -- Drop all existing policies on activation_codes table
    DECLARE
        pol record;
    BEGIN
        FOR pol IN  
            SELECT policyname 
            FROM pg_policies 
            WHERE tablename = 'activation_codes'
        LOOP
            EXECUTE format('DROP POLICY IF EXISTS %I ON activation_codes', pol.policyname);
            RAISE NOTICE 'Dropped policy: %', pol.policyname;
        END LOOP;
    END;
END
$$;

-- 5. Enable RLS on activation_codes table
-- ============================================================================
ALTER TABLE activation_codes ENABLE ROW LEVEL SECURITY;

-- 6. Create comprehensive RLS policies
-- ============================================================================

-- Policy 1: Service role has full access (bypasses RLS anyway, but explicit is good)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'activation_codes' 
        AND policyname = 'Service role full access'
    ) THEN
        CREATE POLICY "Service role full access"
        ON activation_codes
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
        RAISE NOTICE 'Created policy: Service role full access';
    END IF;
END
$$;

-- Policy 2: Authenticated users can read codes for validation
-- (Needed when customer activates code via LicenseService)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'activation_codes' 
        AND policyname = 'Users can validate codes'
    ) THEN
        CREATE POLICY "Users can validate codes"
        ON activation_codes
        FOR SELECT
        TO authenticated
        USING (
          status IN ('unused', 'assigned', 'used')
        );
        RAISE NOTICE 'Created policy: Users can validate codes';
    END IF;
END
$$;

-- Policy 3: Public can read only unused codes (for code availability checking)
-- This is OPTIONAL - remove if you want all code queries to require auth
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'activation_codes' 
        AND policyname = 'Public can check code availability'
    ) THEN
        CREATE POLICY "Public can check code availability"
        ON activation_codes
        FOR SELECT
        TO anon
        USING (
          status = 'unused'
        );
        RAISE NOTICE 'Created policy: Public can check code availability';
    END IF;
END
$$;

-- Policy 4: Only service role can INSERT codes
-- (Developers use admin client with service role key)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'activation_codes' 
        AND policyname = 'Only service role can insert codes'
    ) THEN
        CREATE POLICY "Only service role can insert codes"
        ON activation_codes
        FOR INSERT
        TO service_role
        WITH CHECK (true);
        RAISE NOTICE 'Created policy: Only service role can insert codes';
    END IF;
END
$$;

-- Policy 5: Only service role can UPDATE codes
-- (Developers use admin client with service role key)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'activation_codes' 
        AND policyname = 'Only service role can update codes'
    ) THEN
        CREATE POLICY "Only service role can update codes"
        ON activation_codes
        FOR UPDATE
        TO service_role
        USING (true)
        WITH CHECK (true);
        RAISE NOTICE 'Created policy: Only service role can update codes';
    END IF;
END
$$;

-- Policy 6: Authenticated users can update codes when activating
-- (Allow status change from 'unused' or 'assigned' to 'used')
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'activation_codes' 
        AND policyname = 'Users can activate assigned codes'
    ) THEN
        CREATE POLICY "Users can activate assigned codes"
        ON activation_codes
        FOR UPDATE
        TO authenticated
        USING (
          status IN ('unused', 'assigned')
        )
        WITH CHECK (
          status = 'used'
          AND device_id IS NOT NULL
        );
        RAISE NOTICE 'Created policy: Users can activate assigned codes';
    END IF;
END
$$;

-- 7. Optional: Add CHECK constraint to validate status values
-- ============================================================================
-- Skip if status is already an ENUM
DO $$
DECLARE
    status_type text;
BEGIN
    SELECT data_type INTO status_type
    FROM information_schema.columns
    WHERE table_name = 'activation_codes'
    AND column_name = 'status';
    
    -- Only add constraint if status is text/varchar (not enum)
    IF status_type IN ('character varying', 'text') THEN
        ALTER TABLE activation_codes
        DROP CONSTRAINT IF EXISTS activation_codes_status_check;
        
        ALTER TABLE activation_codes
        ADD CONSTRAINT activation_codes_status_check
        CHECK (status IN ('unused', 'assigned', 'used', 'revoked'));
        
        RAISE NOTICE 'Added CHECK constraint for status values';
    END IF;
END
$$;

-- 8. Create helper function to get available codes (optional)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_available_codes_count(pkg_name text)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::integer
  FROM activation_codes
  WHERE package_name = pkg_name
  AND status = 'unused';
$$;

COMMENT ON FUNCTION get_available_codes_count IS 'Count available (unused) codes for a package';

-- 9. Grant permissions
-- ============================================================================
GRANT SELECT ON activation_codes TO authenticated;
GRANT SELECT ON activation_codes TO anon;
GRANT ALL ON activation_codes TO service_role;

-- 10. Verify setup
-- ============================================================================
DO $$
DECLARE
    rls_enabled boolean;
    policy_count integer;
BEGIN
    -- Check RLS is enabled
    SELECT relrowsecurity INTO rls_enabled
    FROM pg_class
    WHERE relname = 'activation_codes';
    
    IF rls_enabled THEN
        RAISE NOTICE '✅ RLS is enabled on activation_codes';
    ELSE
        RAISE WARNING '⚠️ RLS is NOT enabled on activation_codes';
    END IF;
    
    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'activation_codes';
    
    RAISE NOTICE '✅ Created % RLS policies on activation_codes', policy_count;
    
    -- Check if assigned_at column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'activation_codes'
        AND column_name = 'assigned_at'
    ) THEN
        RAISE NOTICE '✅ assigned_at column exists';
    ELSE
        RAISE WARNING '⚠️ assigned_at column was not created';
    END IF;
END
$$;

-- ============================================================================
-- Migration Complete!
-- ============================================================================
-- Summary of changes:
-- ✅ Added 'assigned_at' column for tracking
-- ✅ Added 'assigned' status support (enum or text)
-- ✅ Created indexes for performance
-- ✅ Set up RLS policies for secure access
-- ✅ Service role has full access (for developer operations)
-- ✅ Authenticated users can validate and activate codes
-- ✅ Public can check code availability (optional)
--
-- Next steps:
-- 1. Deploy Edge Function: supabase functions deploy send-activation-code
-- 2. Set secrets: supabase secrets set SMTP_HOST=smtp.gmail.com (etc)
-- 3. Test: Fulfill request → Check email → Activate code
-- ============================================================================
