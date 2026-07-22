-- Allow activation requests from the one-time license pricing model.
-- Run this once against the production smart_monitoring database.
ALTER TABLE activation_code_requests
  MODIFY COLUMN request_type
  ENUM('monthly', 'one_time_license', 'trial', 'trial_upgrade') NOT NULL;
