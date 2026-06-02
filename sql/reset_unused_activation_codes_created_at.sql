-- Reset created_at for unused activation codes
-- Use this when many unused codes were imported with old or NULL timestamps
-- IMPORTANT: Review before running. Run in Supabase SQL editor or psql as a DB admin.

BEGIN;

-- Option A: Set NULL created_at to NOW() (make codes valid from now)
UPDATE activation_codes
SET created_at = NOW()
WHERE status = 'unused' AND created_at IS NULL;

-- Option B: Optionally reset created_at for unused codes older than 24 hours
-- (use this if you want all unused codes to be valid again starting now)
UPDATE activation_codes
SET created_at = NOW()
WHERE status = 'unused' AND created_at < NOW() - INTERVAL '24 hours';

COMMIT;

-- Notes:
-- - Run Option A alone to populate missing timestamps.
-- - Run Option B to force unused codes older than 24 hours to become valid now.
-- - You can limit by package: add "AND package_name = 'Basic'" to the WHERE clause.
-- - Always test on a smaller subset first, e.g. add "AND id IN (SELECT id FROM activation_codes WHERE status='unused' LIMIT 10)".
