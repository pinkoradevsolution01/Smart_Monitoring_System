# Supabase Database Schema for License Activation

## Overview
This document contains the SQL schema for the Smart Monitoring System license activation and subscription management tables in Supabase.

## Tables

### 1. activation_codes
Stores all activation codes with their status and usage tracking.

```sql
-- Drop existing table if you want to start fresh
-- DROP TABLE IF EXISTS activation_codes CASCADE;

CREATE TABLE activation_codes (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(20) UNIQUE NOT NULL,
  package_name VARCHAR(50) NOT NULL,
  status VARCHAR(20) DEFAULT 'unused' CHECK (status IN ('unused', 'used', 'revoked')),
  device_id VARCHAR(100),
  device_name VARCHAR(200),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  used_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for fast lookups
CREATE INDEX idx_activation_codes_code ON activation_codes(code);
CREATE INDEX idx_activation_codes_status ON activation_codes(status);
CREATE INDEX idx_activation_codes_device_id ON activation_codes(device_id);

-- Add comments for documentation
COMMENT ON TABLE activation_codes IS 'Stores activation codes for license management';
COMMENT ON COLUMN activation_codes.code IS 'Unique 20-character activation code';
COMMENT ON COLUMN activation_codes.package_name IS 'Package tier: Basic, Standard, or Premium';
COMMENT ON COLUMN activation_codes.status IS 'Code status: unused, used, or revoked';
COMMENT ON COLUMN activation_codes.device_id IS 'Device fingerprint that activated this code';
COMMENT ON COLUMN activation_codes.device_name IS 'Human-readable device name (e.g., Windows, Android)';
```

### 2. subscriptions
Tracks active subscriptions with expiry dates and renewal history.

```sql
-- Drop existing table if you want to start fresh
-- DROP TABLE IF EXISTS subscriptions CASCADE;

CREATE TABLE subscriptions (
  id BIGSERIAL PRIMARY KEY,
  device_id VARCHAR(100) NOT NULL,
  activation_code VARCHAR(20) NOT NULL,
  package_name VARCHAR(50) NOT NULL,
  device_name VARCHAR(200),
  activated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
  last_checked_at TIMESTAMP WITH TIME ZONE,
  notes TEXT
);

-- Create indexes for fast lookups
CREATE INDEX idx_subscriptions_device_id ON subscriptions(device_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_expires_at ON subscriptions(expires_at);
CREATE INDEX idx_subscriptions_activation_code ON subscriptions(activation_code);

-- Add comments for documentation
COMMENT ON TABLE subscriptions IS 'Tracks active and expired monthly rental subscriptions';
COMMENT ON COLUMN subscriptions.device_id IS 'Device fingerprint for this subscription';
COMMENT ON COLUMN subscriptions.activation_code IS 'Code that activated this subscription';
COMMENT ON COLUMN subscriptions.package_name IS 'Subscribed package: Basic, Standard, or Premium';
COMMENT ON COLUMN subscriptions.activated_at IS 'When the subscription started';
COMMENT ON COLUMN subscriptions.expires_at IS 'When the monthly rental expires (typically 30 days)';
COMMENT ON COLUMN subscriptions.status IS 'active, expired, or cancelled';
```

### 3. subscription_renewals (Optional - for tracking payment history)
Tracks renewal payments and subscription extensions.

```sql
-- Optional table for tracking monthly renewal payments
CREATE TABLE subscription_renewals (
  id BIGSERIAL PRIMARY KEY,
  subscription_id BIGINT REFERENCES subscriptions(id) ON DELETE CASCADE,
  renewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  previous_expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  new_expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  payment_method VARCHAR(50),
  payment_amount DECIMAL(10, 2),
  transaction_id VARCHAR(100),
  notes TEXT
);

CREATE INDEX idx_renewals_subscription_id ON subscription_renewals(subscription_id);
CREATE INDEX idx_renewals_renewed_at ON subscription_renewals(renewed_at);

COMMENT ON TABLE subscription_renewals IS 'Tracks monthly renewal payments and subscription extensions';
```

## Row Level Security (RLS) Policies

**IMPORTANT**: Enable RLS to secure your data!

```sql
-- Enable Row Level Security on all tables
ALTER TABLE activation_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_renewals ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow public read access to unused codes (for validation)
CREATE POLICY "Allow public read of unused codes" ON activation_codes
  FOR SELECT
  USING (status = 'unused' OR status = 'revoked');

-- Policy 2: Allow public update of unused codes (for marking as used)
CREATE POLICY "Allow public update of unused codes" ON activation_codes
  FOR UPDATE
  USING (status = 'unused')
  WITH CHECK (status IN ('used', 'revoked'));

-- Policy 3: Allow public insert to subscriptions (for new activations)
CREATE POLICY "Allow public insert subscriptions" ON subscriptions
  FOR INSERT
  WITH CHECK (true);

-- Policy 4: Allow users to read their own subscriptions
CREATE POLICY "Allow read own subscriptions" ON subscriptions
  FOR SELECT
  USING (true);

-- Policy 5: Allow updates to subscription status (for renewals)
CREATE POLICY "Allow update subscription status" ON subscriptions
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Note: For production, you should create proper authentication policies
-- that restrict access based on authenticated users or API keys
```

## Sample Data Import

### Import Activation Codes from ACTIVATION_CODES.txt

You can import codes in bulk using the Supabase Table Editor or SQL:

```sql
-- Example: Insert codes from ACTIVATION_CODES.txt
-- Replace with your actual codes

-- Basic Package Codes (₱1,999/month → ₱1,799/month with discount)
INSERT INTO activation_codes (code, package_name, status) VALUES
  ('6B67B63WSGMEOYUC0L4Y', 'Basic', 'unused'),
  ('TM1KY1XTWVJKEOT2P5PA', 'Basic', 'unused'),
  ('G1W2IUMU8E5KUA9HDS9E', 'Basic', 'unused');
  -- ... add more codes ...

-- Standard Package Codes (₱3,999/month → ₱3,799/month with discount)
INSERT INTO activation_codes (code, package_name, status) VALUES
  ('BQAP7L5G84ELH9XHL491', 'Standard', 'unused'),
  ('7P8HIC0OV00S9LLWCPVS', 'Standard', 'unused');
  -- ... add more codes ...

-- Premium Package Codes (₱6,999/month → ₱6,799/month with discount)
INSERT INTO activation_codes (code, package_name, status) VALUES
  ('XXYT4BDVIH2W7GGMKTRI', 'Premium', 'unused'),
  ('YWJEZ45C9NC5HKLE9USD', 'Premium', 'unused');
  -- ... add more codes ...
```

### Bulk Import via CSV

1. Go to Supabase Dashboard → Table Editor → activation_codes
2. Click "Import data via spreadsheet"
3. Prepare CSV file:
   ```csv
   code,package_name,status
   6B67B63WSGMEOYUC0L4Y,Basic,unused
   TM1KY1XTWVJKEOT2P5PA,Basic,unused
   G1W2IUMU8E5KUA9HDS9E,Standard,unused
   ```
4. Upload and import

## Queries

### Check Available Codes
```sql
-- Count unused codes by package
SELECT package_name, COUNT(*) as unused_count
FROM activation_codes
WHERE status = 'unused'
GROUP BY package_name
ORDER BY package_name;
```

### View Active Subscriptions
```sql
-- Show all active subscriptions with time remaining
SELECT 
  device_id,
  device_name,
  package_name,
  activated_at,
  expires_at,
  EXTRACT(DAY FROM (expires_at - NOW())) as days_remaining,
  status
FROM subscriptions
WHERE status = 'active'
ORDER BY expires_at ASC;
```

### Find Used Codes by Device
```sql
-- Show which codes a specific device used
SELECT 
  ac.code,
  ac.package_name,
  ac.used_at,
  ac.device_name,
  s.expires_at,
  s.status
FROM activation_codes ac
LEFT JOIN subscriptions s ON s.activation_code = ac.code
WHERE ac.device_id = 'YOUR_DEVICE_ID_HERE'
ORDER BY ac.used_at DESC;
```

### Auto-Expire Subscriptions (Run Daily via Supabase Edge Function)
```sql
-- Update expired subscriptions
UPDATE subscriptions
SET status = 'expired'
WHERE status = 'active' 
  AND expires_at < NOW();
```

## API Usage Examples

### Check if Code is Valid (from Flutter app)
```dart
final response = await supabase
    .from('activation_codes')
    .select('code, package_name, status')
    .eq('code', 'ENTER_CODE_HERE')
    .eq('status', 'unused')
    .maybeSingle();

if (response != null) {
  print('Valid code for ${response['package_name']} package');
} else {
  print('Invalid or already used code');
}
```

### Mark Code as Used
```dart
await supabase.from('activation_codes').update({
  'status': 'used',
  'device_id': deviceId,
  'device_name': 'Windows PC',
  'used_at': DateTime.now().toIso8601String(),
}).eq('code', activationCode);
```

### Create Subscription
```dart
await supabase.from('subscriptions').insert({
  'device_id': deviceId,
  'activation_code': code,
  'package_name': 'Standard',
  'device_name': 'Windows PC',
  'activated_at': DateTime.now().toIso8601String(),
  'expires_at': DateTime.now().add(Duration(days: 30)).toIso8601String(),
  'status': 'active',
});
```

## Maintenance Tasks

### Weekly Cleanup
```sql
-- Mark expired subscriptions
UPDATE subscriptions
SET status = 'expired'
WHERE status = 'active' AND expires_at < NOW();
```

### Monthly Reports
```sql
-- Revenue report (count activations per package)
SELECT 
  package_name,
  COUNT(*) as activations,
  MIN(activated_at) as first_activation,
  MAX(activated_at) as last_activation
FROM subscriptions
WHERE activated_at >= DATE_TRUNC('month', NOW())
GROUP BY package_name;
```

### Revoke Stolen/Shared Codes
```sql
-- Revoke a code (prevents future use)
UPDATE activation_codes
SET status = 'revoked'
WHERE code = 'CODE_TO_REVOKE';

-- Cancel associated subscription
UPDATE subscriptions
SET status = 'cancelled'
WHERE activation_code = 'CODE_TO_REVOKE';
```

## Monitoring Dashboard Queries

### Daily Active Devices
```sql
SELECT COUNT(DISTINCT device_id) as active_devices
FROM subscriptions
WHERE status = 'active';
```

### Expiring Soon (Next 7 Days)
```sql
SELECT device_id, package_name, expires_at
FROM subscriptions
WHERE status = 'active' 
  AND expires_at BETWEEN NOW() AND NOW() + INTERVAL '7 days'
ORDER BY expires_at ASC;
```

### Unused Codes Inventory
```sql
SELECT 
  package_name,
  COUNT(*) as unused_count,
  COUNT(*) * CASE 
    WHEN package_name = 'Basic' THEN 1799
    WHEN package_name = 'Standard' THEN 3799
    WHEN package_name = 'Premium' THEN 6799
  END as potential_revenue_php
FROM activation_codes
WHERE status = 'unused'
GROUP BY package_name;
```

## Backup & Recovery

### Export All Data (Manual Backup)
```bash
# From Supabase Dashboard:
# Settings → Database → Database Backups → Create backup
# Download SQL dump for disaster recovery
```

### Restore from Backup
```sql
-- Import SQL dump via Supabase SQL Editor
-- File → Import SQL → Select backup file
```

## Security Best Practices

1. **Enable RLS**: Always enable Row Level Security on all tables
2. **Use API Keys**: Don't expose your service_role key in client apps
3. **Validate Server-Side**: Never trust client-side code validation
4. **Monitor Usage**: Set up logging and alerts for unusual activity
5. **Regular Audits**: Review activation_codes and subscriptions weekly
6. **Backup Daily**: Enable Supabase Pro for automated daily backups

## Cost Optimization

### Free Tier Usage Tracking
```sql
-- Check database size (Free tier: 500MB limit)
SELECT pg_size_pretty(pg_database_size('postgres')) as database_size;

-- Count total rows (50K MAU limit for Free tier)
SELECT 
  (SELECT COUNT(*) FROM activation_codes) as codes,
  (SELECT COUNT(*) FROM subscriptions) as subs,
  (SELECT COUNT(*) FROM subscriptions WHERE status = 'active') as active_subs;
```

## Support

For issues with this schema:
1. Check Supabase docs: https://supabase.com/docs
2. Review security policies in Supabase Dashboard
3. Enable database logs for debugging
4. Test queries in SQL Editor before production use

---

**Last Updated**: February 9, 2026  
**Schema Version**: 1.0  
**Compatible With**: Smart Monitoring System v1.0+
