-- Run once on existing MySQL databases.
ALTER TABLE subscriptions MODIFY COLUMN expires_at DATETIME NULL;
ALTER TABLE subscription_records MODIFY COLUMN expires_at DATETIME NULL;

CREATE TABLE IF NOT EXISTS cancelled_subscribers (
  id CHAR(36) NOT NULL PRIMARY KEY DEFAULT (UUID()),
  email VARCHAR(255) NOT NULL,
  activation_code VARCHAR(64) NULL,
  reason TEXT,
  cancelled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_cancelled_subscribers_email (email),
  KEY idx_cancelled_subscribers_activation_code (activation_code)
) ENGINE=InnoDB;

INSERT INTO cancelled_subscribers (email, activation_code, reason)
SELECT contact_email, MAX(activation_code), 'Recovered from cancelled activation request'
FROM activation_code_requests
WHERE status = 'cancelled'
GROUP BY contact_email
ON DUPLICATE KEY UPDATE
  activation_code = COALESCE(VALUES(activation_code), activation_code),
  reason = VALUES(reason);

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
