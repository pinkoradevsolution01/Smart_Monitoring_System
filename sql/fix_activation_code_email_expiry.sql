-- ============================================================================
-- Fix activation codes that were given an expiry before the email was sent
-- ============================================================================
--
-- Use this if you have activation_codes rows where expires_at was set even
-- though the code was never emailed to the subscriber yet.
--
-- Safe behavior:
-- - Codes with no email_sent_at should not have an expiry clock running.
-- - Codes with email_sent_at keep a 24-hour expiry from the email timestamp.
-- ============================================================================

BEGIN;

-- Clear expiry on assigned codes that were never emailed.
UPDATE activation_codes
SET expires_at = NULL
WHERE status = 'assigned'
  AND email_sent_at IS NULL
  AND expires_at IS NOT NULL;

-- Rebuild expiry from the actual email send timestamp when it exists.
UPDATE activation_codes
SET expires_at = DATE_ADD(email_sent_at, INTERVAL 24 HOUR)
WHERE status = 'assigned'
  AND email_sent_at IS NOT NULL
  AND (expires_at IS NULL OR expires_at < email_sent_at);

COMMIT;

-- Verification:
-- SELECT code, status, assigned_at, email_sent_at, expires_at
-- FROM activation_codes
-- WHERE status = 'assigned'
-- ORDER BY COALESCE(email_sent_at, assigned_at, created_at) DESC;
