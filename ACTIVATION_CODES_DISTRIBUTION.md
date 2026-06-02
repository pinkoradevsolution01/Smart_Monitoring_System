# Activation Code Distribution Guide

## Overview
This guide explains how to distribute and manage the 100 activation codes across Basic, Standard, and Premium packages using Supabase.

---

## 📋 Code Distribution Strategy

### Recommended Split (Total: 100 codes)

| Package  | Price (First Activation) | Monthly Renewal | Codes Allocated | Revenue Potential |
|----------|-------------------------|-----------------|-----------------|-------------------|
| **Basic**    | ₱1,999 | ₱1,799 | 60 codes (60%) | ₱107,940/month |
| **Standard** | ₱3,999 | ₱3,799 | 30 codes (30%) | ₱113,970/month |
| **Premium**  | ₱6,999 | ₱6,799 | 10 codes (10%) | ₱67,990/month  |

**Total Monthly Revenue (if all used)**: ₱289,900/month 💰

---

## 🎯 Assigning Packages to Codes

### Method 1: Bulk SQL Import (Recommended)

Create a SQL script to import codes with specific packages:

```sql
-- Import codes from ACTIVATION_CODES.txt
-- Assumption: First 60 codes = Basic, Next 30 = Standard, Last 10 = Premium

-- BASIC PACKAGE (Codes 1-60)
INSERT INTO activation_codes (code, package_name, status) VALUES
  ('6B67B63WSGMEOYUC0L4Y', 'Basic', 'unused'),     -- 001
  ('TM1KY1XTWVJKEOT2P5PA', 'Basic', 'unused'),     -- 002
  ('G1W2IUMU8E5KUA9HDS9E', 'Basic', 'unused'),     -- 003
  ('BQAP7L5G84ELH9XHL491', 'Basic', 'unused'),     -- 004
  ('7P8HIC0OV00S9LLWCPVS', 'Basic', 'unused'),     -- 005
  -- ... add codes 006-060 with 'Basic' ...
  
-- STANDARD PACKAGE (Codes 61-90)
INSERT INTO activation_codes (code, package_name, status) VALUES
  ('2W6X0SLG2RXFPDYLCL0F', 'Standard', 'unused'),  -- 061
  ('ZGOISDT2AZCNAQFLZ7MH', 'Standard', 'unused'),  -- 062
  ('ZNBRDWSHKE8SM5K43S6C', 'Standard', 'unused'),  -- 063
  -- ... add codes 064-090 with 'Standard' ...
  
-- PREMIUM PACKAGE (Codes 91-100)
INSERT INTO activation_codes (code, package_name, status) VALUES
  ('XXYT4BDVIH2W7GGMKTRI', 'Premium', 'unused'),   -- 091
  ('CIX6Z1Q3NRA8SYYDP6NX', 'Premium', 'unused'),   -- 092
  ('72G67FJDWD8WCCUGCOYI', 'Premium', 'unused'),   -- 093
  ('CQJNM5H2407KRAMK0C5C', 'Premium', 'unused'),   -- 094
  ('YWJEZ45C9NC5HKLE9USD', 'Premium', 'unused');   -- 095
  -- ... add remaining 5 Premium codes ...
```

### Method 2: CSV Import with Package Assignment

Create CSV file: `activation_codes_with_packages.csv`

```csv
code,package_name,status
6B67B63WSGMEOYUC0L4Y,Basic,unused
TM1KY1XTWVJKEOT2P5PA,Basic,unused
G1W2IUMU8E5KUA9HDS9E,Basic,unused
...
2W6X0SLG2RXFPDYLCL0F,Standard,unused
ZGOISDT2AZCNAQFLZ7MH,Standard,unused
...
XXYT4BDVIH2W7GGMKTRI,Premium,unused
YWJEZ45C9NC5HKLE9USD,Premium,unused
```

Then import via Supabase Table Editor:
1. Go to: **Table Editor** → `activation_codes`
2. Click: **Import data via spreadsheet**
3. Upload CSV → **Import**

---

## 🔐 Code Distribution to Customers

### Option A: Email Distribution (Manual)

**Template Email:**
```
Subject: Your Smart Monitoring System Activation Code

Dear [Customer Name],

Thank you for purchasing the [PACKAGE NAME] package!

Your Activation Code: [CODE]
Package: [Basic/Standard/Premium]
Monthly Fee: ₱[AMOUNT]

HOW TO ACTIVATE:
1. Open Smart Monitoring System
2. Go to: Settings → Package Selection
3. Click "Get Started - Monthly"
4. Enter your activation code
5. Click "Activate"

Your subscription includes:
 - [List package features]
 - Monthly renewal at ₱[RENEWAL AMOUNT]
 - Cross-device protection
 - Cloud backup and sync

IMPORTANT NOTES:
⚠️ This code can only be used once
⚠️ Code is tied to your device after activation
⚠️ Subscription renews monthly automatically

Need help? Contact us at support@yourdomain.com

Best regards,
Smart Monitoring System Team
```

### Option B: Automated Distribution System (Future Feature)

**Recommended Tools:**
- **Supabase Edge Functions**: Auto-send email on purchase
- **SendGrid/Mailgun**: Email delivery service
- **Stripe/PayMongo**: Payment gateway integration

**Workflow:**
1. Customer pays via payment gateway
2. Webhook triggers Supabase Edge Function
3. Function generates/assigns unused code
4. Email sent automatically with code
5. Code marked as "issued" (prevent accidental reuse)

---

## 📊 Tracking Code Usage

### View Codes by Package

```sql
-- Count codes by package and status
SELECT 
  package_name,
  status,
  COUNT(*) as count
FROM activation_codes
GROUP BY package_name, status
ORDER BY package_name, status;
```

**Example Output:**
```
package_name | status  | count
-------------+---------+-------
Basic        | unused  | 45
Basic        | used    | 15
Standard     | unused  | 25
Standard     | used    | 5
Premium      | unused  | 9
Premium      | used    | 1
```

### Find Specific Code Details

```sql
-- Check if a code is available
SELECT 
  code,
  package_name,
  status,
  device_id,
  device_name,
  used_at
FROM activation_codes
WHERE code = 'ENTER_CODE_HERE';
```

### List Unused Codes by Package

```sql
-- Get list of unused codes for distribution
SELECT code, package_name
FROM activation_codes
WHERE status = 'unused'
  AND package_name = 'Basic'  -- Change to 'Standard' or 'Premium'
ORDER BY created_at ASC
LIMIT 10;
```

---

## 💼 Sales Tracking

### Revenue Dashboard

```sql
-- Monthly revenue by package
SELECT 
  package_name,
  COUNT(*) as activations,
  CASE 
    WHEN package_name = 'Basic' THEN COUNT(*) * 1799
    WHEN package_name = 'Standard' THEN COUNT(*) * 3799
    WHEN package_name = 'Premium' THEN COUNT(*) * 6799
  END as monthly_revenue_php
FROM subscriptions
WHERE status = 'active'
GROUP BY package_name
ORDER BY monthly_revenue_php DESC;
```

### Customer Lifetime Value (CLV)

```sql
-- Calculate average subscription duration
SELECT 
  package_name,
  AVG(EXTRACT(DAY FROM (expires_at - activated_at))) as avg_subscription_days,
  COUNT(*) as total_customers
FROM subscriptions
WHERE status IN ('active', 'expired')
GROUP BY package_name;
```

---

## 🎁 Promotional Strategies

### Strategy 1: Package Upgrades

Allow customers to upgrade from Basic → Standard → Premium:

```sql
-- Record package upgrade
UPDATE subscriptions
SET package_name = 'Standard',
    notes = 'Upgraded from Basic on 2026-02-09'
WHERE device_id = 'DEVICE_ID_HERE';

-- Mark old code as upgraded (optional tracking)
UPDATE activation_codes
SET status = 'upgraded'
WHERE device_id = 'DEVICE_ID_HERE' 
  AND package_name = 'Basic';
```

### Strategy 2: Bundle Discounts

Offer multi-device licenses by generating discount codes:

```sql
-- Create special bundle codes (20% off)
INSERT INTO activation_codes (code, package_name, status, notes) VALUES
  ('BUNDLE20OFF123456789', 'Standard', 'unused', '20% discount bundle code');
```

### Strategy 3: Referral Codes

Track referrals by adding referrer info:

```sql
-- Add referrer column (run once)
ALTER TABLE subscriptions 
ADD COLUMN referred_by VARCHAR(100);

-- When activating with referral
UPDATE subscriptions
SET referred_by = 'REFERRER_CODE_HERE'
WHERE device_id = 'NEW_CUSTOMER_DEVICE_ID';
```

---

## 🔄 Code Lifecycle Management

### 1. Initial State: UNUSED
Code is generated and imported into database.
```sql
status = 'unused'
device_id = NULL
```

### 2. Activation: USED
Customer enters code and activates subscription.
```sql
status = 'used'
device_id = 'ABC123XYZ...'
device_name = 'Windows PC'
used_at = '2026-02-09 10:30:00'
```

### 3. Renewal: ACTIVE SUBSCRIPTION
Subscription automatically renews monthly.
```sql
-- Subscription record
status = 'active'
expires_at = '2026-03-09 10:30:00'
```

### 4. Expiry: EXPIRED SUBSCRIPTION
Monthly payment not received.
```sql
-- Subscription expired
status = 'expired'
```

### 5. Revocation: REVOKED (Admin Action)
Code shared publicly or stolen.
```sql
-- Revoke code
UPDATE activation_codes
SET status = 'revoked'
WHERE code = 'CODE_TO_REVOKE';
```

---

## 📱 Multi-Device Management

### Current System (One Device per Code)
Each activation code works on **one device only**.

**How it works:**
- Code `ABC123` activated on Device A → ✅ Success
- Same code on Device B → ❌ "Already used on another device"
- Same code on Device A again → ✅ Reactivation allowed (reinstall scenario)

### Future Enhancement: Multi-Device Licenses

To allow multiple devices per code, modify schema:

```sql
-- Add device_limit column
ALTER TABLE activation_codes
ADD COLUMN device_limit INT DEFAULT 1;

-- Premium gets 3 devices
UPDATE activation_codes
SET device_limit = 3
WHERE package_name = 'Premium';

-- Track device count
ALTER TABLE activation_codes
ADD COLUMN devices_used INT DEFAULT 0;
```

Then update validation logic in `license_service.dart`:

```dart
// Check if code has available device slots
if (response['devices_used'] >= response['device_limit']) {
  return ActivationResult(
    success: false,
    message: 'This code has reached its device limit (${response['device_limit']} devices)',
  );
}
```

---

## 📧 Customer Communication Templates

### Activation Confirmation
```
Subject: ✅ Activation Successful!

Hi [Customer Name],

Your [PACKAGE] subscription is now active!

 Device: [DEVICE_NAME]
 Activated: [DATE]
 Expires: [DATE + 30 days]
 Monthly Fee: ₱[AMOUNT]

Your subscription will auto-renew on [DATE].
Manage your subscription: [DASHBOARD LINK]
```

### Renewal Reminder (7 Days Before)
```
Subject: 🔔 Subscription Renewal in 7 Days

Hi [Customer Name],

Your [PACKAGE] subscription expires on [DATE].

To continue using Smart Monitoring System:
 Pay ₱[RENEWAL_AMOUNT] before [EXPIRY_DATE]

Payment methods: [LIST METHODS]
Questions? Contact support@yourdomain.com
```

### Expiry Notice
```
Subject: ⚠️ Subscription Expired

Hi [Customer Name],

Your [PACKAGE] subscription has expired.

To reactivate your subscription:
1. Pay ₱[RENEWAL_AMOUNT]
2. Click "Renew Subscription" in Settings

All your data is safe and will be restored upon renewal.
```

---

## 🛡️ Security Best Practices

### 1. Never Expose Codes Publicly
- ❌ Don't commit `ACTIVATION_CODES.txt` to Git
- ❌ Don't share codes in public forums
- ✅ Store codes securely in Supabase
- ✅ Add `.gitignore` entry for code files

### 2. Monitor Suspicious Activity
```sql
-- Find codes used on multiple devices (potential sharing)
SELECT 
  activation_code,
  COUNT(DISTINCT device_id) as device_count
FROM subscriptions
GROUP BY activation_code
HAVING COUNT(DISTINCT device_id) > 1;
```

### 3. Regular Audits
```sql
-- Check for unusual activation patterns
SELECT 
  DATE(used_at) as date,
  COUNT(*) as activations
FROM activation_codes
WHERE used_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(used_at)
ORDER BY date DESC;
```

---

## 💡 Tips for Success

1. **Start Small**: Distribute 5-10 codes initially to test the system
2. **Monitor Closely**: Check Supabase dashboard daily for first month
3. **Gather Feedback**: Ask customers about activation experience
4. **Automate Renewals**: Integrate payment gateway for auto-renewals
5. **Provide Support**: Have FAQ ready for common activation issues
6. **Track Metrics**: Monitor conversion rate (codes distributed → activated)

---

## ✅ Pre-Launch Checklist

- [ ] All 100 codes imported to Supabase
- [ ] Codes assigned to correct packages (60 Basic, 30 Standard, 10 Premium)
- [ ] Test activation on each package type
- [ ] Email templates prepared
- [ ] Customer support email set up
- [ ] Payment renewal process documented
- [ ] Dashboard monitoring queries bookmarked
- [ ] Emergency revocation plan ready

---

## 📞 Support & Contact

**For activation issues:**
- Check: [`SUPABASE_SETUP_GUIDE.md`](SUPABASE_SETUP_GUIDE.md)
- Check: [`SUPABASE_SCHEMA.md`](SUPABASE_SCHEMA.md)
- Email: support@yourdomain.com

**For technical issues:**
- Check device compatibility
- Verify internet connection
- Review server logs in Supabase
- Test with development codes first

---

**Last Updated**: February 9, 2026  
**Total Codes**: 100  
**Distribution**: 60 Basic | 30 Standard | 10 Premium  
**Status**: Ready for Production ✅
