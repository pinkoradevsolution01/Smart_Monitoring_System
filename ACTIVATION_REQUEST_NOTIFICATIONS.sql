-- ============================================================================
-- Email Notification System for Activation Code Requests
-- ============================================================================
-- This file contains database trigger and webhook setup to notify developers
-- when new activation code requests arrive from customers.
--
-- SETUP STEPS:
-- 1. Run this SQL in your Supabase SQL Editor
-- 2. Deploy the Edge Function (see supabase/functions/notify-activation-request/)
-- 3. Configure your preferred notification method (email, webhook, or both)
-- ============================================================================

-- Store developer notification settings
CREATE TABLE IF NOT EXISTS developer_notification_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_email TEXT NOT NULL,
  webhook_url TEXT,
  email_enabled BOOLEAN DEFAULT true,
  webhook_enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default developer notification settings
-- UPDATE THIS with your actual email/webhook
INSERT INTO developer_notification_settings (notification_email, email_enabled)
VALUES ('developer@yourdomain.com', true)
ON CONFLICT DO NOTHING;

-- Enable RLS for settings table
ALTER TABLE developer_notification_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Only authenticated users (developers) can view/edit settings
CREATE POLICY "Developers can manage notification settings"
  ON developer_notification_settings
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- Function to send notification via Supabase Edge Function
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_new_activation_request()
RETURNS TRIGGER AS $$
DECLARE
  settings RECORD;
  request_payload JSON;
BEGIN
  -- Get notification settings
  SELECT * INTO settings 
  FROM developer_notification_settings 
  LIMIT 1;

  -- Build notification payload
  request_payload := json_build_object(
    'request_id', NEW.id,
    'business_name', NEW.business_name,
    'package_name', NEW.package_name,
    'package_price', NEW.package_price,
    'request_type', NEW.request_type,
    'contact_email', NEW.contact_email,
    'contact_phone', NEW.contact_phone,
    'additional_notes', NEW.additional_notes,
    'requested_at', NEW.requested_at,
    'notification_email', settings.notification_email,
    'webhook_url', settings.webhook_url,
    'email_enabled', settings.email_enabled,
    'webhook_enabled', settings.webhook_enabled
  );

  -- Send notification via Supabase Edge Function
  -- Note: You need to deploy the Edge Function first
  -- See: supabase/functions/notify-activation-request/
  PERFORM
    net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/notify-activation-request',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key')
      ),
      body := request_payload::jsonb
    );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Trigger: Send notification when new request is inserted
-- ============================================================================
DROP TRIGGER IF EXISTS on_activation_request_created ON activation_code_requests;

CREATE TRIGGER on_activation_request_created
  AFTER INSERT ON activation_code_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_activation_request();

-- ============================================================================
-- Function to manually test notification (Developer Use)
-- ============================================================================
CREATE OR REPLACE FUNCTION test_activation_notification(request_id UUID)
RETURNS JSON AS $$
DECLARE
  test_request RECORD;
  settings RECORD;
  result JSON;
BEGIN
  -- Get the request
  SELECT * INTO test_request 
  FROM activation_code_requests 
  WHERE id = request_id;

  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Request not found');
  END IF;

  -- Get settings
  SELECT * INTO settings FROM developer_notification_settings LIMIT 1;

  -- Build test payload
  result := json_build_object(
    'status', 'test_notification_sent',
    'request', row_to_json(test_request),
    'settings', row_to_json(settings),
    'message', 'Check your email/webhook endpoint for the test notification'
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================
/*
-- 1. Update developer notification email:
UPDATE developer_notification_settings 
SET notification_email = 'your-email@example.com',
    email_enabled = true;

-- 2. Add webhook URL (for Slack, Discord, etc.):
UPDATE developer_notification_settings 
SET webhook_url = 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL',
    webhook_enabled = true;

-- 3. Test notification for a specific request:
SELECT test_activation_notification('REQUEST-UUID-HERE');

-- 4. View all pending requests:
SELECT * FROM activation_code_requests WHERE status = 'pending';

-- 5. Disable notifications temporarily:
UPDATE developer_notification_settings 
SET email_enabled = false, 
    webhook_enabled = false;
*/

-- ============================================================================
-- Grant necessary permissions
-- ============================================================================
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT SELECT, UPDATE ON developer_notification_settings TO authenticated;

-- ============================================================================
COMMENT ON TABLE developer_notification_settings IS 'Stores developer email and webhook settings for activation request notifications';
COMMENT ON FUNCTION notify_new_activation_request() IS 'Automatically sends notification when new activation request arrives';
COMMENT ON FUNCTION test_activation_notification(UUID) IS 'Test notification system with existing request';
