-- Run once on existing MySQL databases.
ALTER TABLE subscriptions MODIFY COLUMN expires_at DATETIME NULL;
ALTER TABLE subscription_records MODIFY COLUMN expires_at DATETIME NULL;

-- Backfill the historical records table from the authoritative subscriptions
-- table so existing cancellations are visible in Subscription Records.
INSERT INTO subscription_records
  (device_id, activation_code, package_name, device_name, activated_at, expires_at, status, last_checked_at, notes, created_at)
SELECT device_id, activation_code, package_name, device_name, activated_at, expires_at, status, last_checked_at, notes, created_at
FROM subscriptions
ON DUPLICATE KEY UPDATE
  package_name = VALUES(package_name),
  device_name = VALUES(device_name),
  expires_at = VALUES(expires_at),
  status = VALUES(status),
  last_checked_at = VALUES(last_checked_at),
  notes = VALUES(notes);
