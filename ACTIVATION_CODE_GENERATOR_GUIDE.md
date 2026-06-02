# Activation Code Generator - User Guide

## 📋 Overview

The Activation Code Generator allows you to generate, manage, and export activation codes for your Smart Monitoring System packages directly from the Developer Dashboard.

## 🚀 How to Access

1. Launch the app and navigate to **Developer Dashboard**
2. Under **Data Management** section, click **Activation Code Generator**
3. The generator screen will open

## ✨ Features

### 1. Generate Codes

**Single Code Generation**
- Select package (Basic, Standard, or Premium)
- Click **"Generate 1"** button
- Code is immediately added to the list

**Bulk Code Generation**
- Select package (Basic, Standard, or Premium)
- Click **"Generate 100"** button
- 100 unique codes are generated automatically
- Progress updates every 10 codes for better performance

### 2. Code Format

Each generated code follows this format:
- **Length**: 20 characters
- **Characters**: Uppercase letters (A-Z) and numbers (0-9)
- **Uniqueness**: Each code is guaranteed to be unique
- **Example**: `6B67B63WSGMEOYUC0L4Y`

### 3. View Statistics

The statistics card shows:
- **Total**: Total number of generated codes
- **Basic**: Count of Basic package codes (₱1,799/month)
- **Standard**: Count of Standard package codes (₱3,799/month)
- **Premium**: Count of Premium package codes (₱6,799/month)

### 4. Manage Codes

**Copy Code**
- Click the blue **copy icon** next to any code
- Code is copied to clipboard
- Use for testing or manual distribution

**Delete Code**
- Click the red **delete icon** next to any code
- Code is removed from the list
- Cannot be undone (unless regenerated)

**Clear All**
- Click the **trash icon** in the app bar
- Confirm deletion in the dialog
- All codes are removed from the list

### 5. Export to CSV

**Export All Codes**
1. Click the **download icon** in the app bar
2. CSV file is generated with this format:
   ```csv
   code,package_name,status
   6B67B63WSGMEOYUC0L4Y,Basic,unused
   TM1KY1XTWVJKEOT2P5PA,Basic,unused
   G1W2IUMU8E5KUA9HDS9E,Standard,unused
   ```
3. Share dialog opens automatically
4. Save to device or share via email/cloud storage

**CSV Format Details**
- **Header**: `code,package_name,status`
- **code**: 20-character activation code
- **package_name**: `Basic`, `Standard`, or `Premium`
- **status**: Always `unused` for newly generated codes

## 📝 Usage Examples

### Example 1: Generate 100 Basic Codes

1. Open Activation Code Generator
2. Select **Basic** from package dropdown
3. Click **Generate 100**
4. Wait for generation to complete (~1-2 seconds)
5. Statistics show: Total: 100, Basic: 100
6. Click **Export** icon
7. Share/save `activation_codes_[timestamp].csv`

### Example 2: Generate Mixed Package Codes

**For Production Distribution**
1. Select **Basic**, click **Generate 100** → 100 Basic codes
2. Select **Standard**, click **Generate 100** → 100 Standard codes  
3. Select **Premium**, click **Generate 100** → 100 Premium codes
4. Statistics show: Total: 300, Basic: 100, Standard: 100, Premium: 100
5. Click **Export** to get all 300 codes in one CSV

### Example 3: Generate and Test Single Code

1. Select **Premium**
2. Click **Generate 1**
3. Click **copy icon** next to the new code
4. Go to Package Selection screen in the app
5. Paste code to test activation
6. Return to generator to delete test code

## 🔒 Security Recommendations

### Before Export

1. **Review Codes**: Verify correct package distribution
2. **Check Statistics**: Ensure counts match your needs
3. **Test Sample**: Test 1-2 codes before mass distribution

### After Export

1. **Secure Storage**: Store CSV in encrypted location
2. **Backup**: Keep a backup copy in secure cloud storage
3. **Version Control**: Add `activation_codes_*.csv` to `.gitignore`
4. **Clean Up**: Delete CSV from device after uploading to Supabase

### For Production

1. **Import to Supabase**: Follow `SUPABASE_SQL_COMPLETE.md` guide
2. **Delete Local CSV**: Remove from device after successful import
3. **Monitor Usage**: Track code activation in Supabase dashboard
4. **Revoke if Needed**: Update code status in database if compromised

## 📤 Integration with Supabase

After exporting CSV, import to Supabase:

### Method 1: CSV Upload (Recommended)

1. Go to **Supabase Dashboard** → **Table Editor** → `activation_codes`
2. Click **Insert** → **Import data via spreadsheet**
3. Upload your exported CSV file
4. Verify codes appear in the table

### Method 2: SQL Insert

Convert CSV to SQL using this format:
```sql
INSERT INTO activation_codes (code, package_name, status) VALUES
  ('6B67B63WSGMEOYUC0L4Y', 'Basic', 'unused'),
  ('TM1KY1XTWVJKEOT2P5PA', 'Basic', 'unused'),
  ('G1W2IUMU8E5KUA9HDS9E', 'Standard', 'unused');
```

Run in Supabase SQL Editor.

## 🛠️ Technical Details

### Code Generation Algorithm

- Uses `Random.secure()` for cryptographically secure random generation
- Checks for duplicates before adding to list
- Character set: `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789` (36 characters)
- Total possible combinations: 36^20 ≈ 1.3 × 10^31

### Performance

- **Single code**: Instant
- **100 codes**: ~1-2 seconds
- **1000 codes**: ~10-15 seconds (generate in batches of 100)
- UI updates every 10 codes to prevent freezing

### File Export

- CSV saved to temporary directory
- Filename: `activation_codes_import.csv`
- Uses platform share dialog for easy distribution
- Supports email, cloud storage, local save

## ❓ Troubleshooting

### "No codes to export"
**Solution**: Generate at least one code before attempting export.

### CSV file not opening correctly
**Solution**: Ensure you're opening with a CSV-compatible app (Excel, Google Sheets, Numbers).

### Duplicate codes generated
**Solution**: This should never happen. If it does, clear all and regenerate. Report as a bug.

### Share dialog not appearing
**Solution**: Check app permissions for file access/sharing in device settings.

### Codes not appearing in Supabase
**Solution**: 
1. Verify CSV format matches: `code,package_name,status`
2. Check for import errors in Supabase dashboard
3. Ensure RLS policies are enabled (see `SUPABASE_SQL_COMPLETE.md`)

## 📚 Related Documentation

- **Supabase Import**: [`SUPABASE_SQL_COMPLETE.md`](SUPABASE_SQL_COMPLETE.md) - Section 3B
- **Code Distribution**: [`ACTIVATION_CODES_DISTRIBUTION.md`](ACTIVATION_CODES_DISTRIBUTION.md)
- **License System**: [`LICENSE_ACTIVATION_GUIDE.md`](LICENSE_ACTIVATION_GUIDE.md)
- **Package Control**: [`PACKAGE_ACCESS_CONTROL.md`](PACKAGE_ACCESS_CONTROL.md)

## 🎯 Best Practices

1. **Generate in Batches**: Generate 100 codes at a time for better control
2. **Export Immediately**: Export CSV right after generation
3. **Verify Before Import**: Open CSV to verify format before Supabase import
4. **Track Distribution**: Keep records of which codes were distributed to which customers
5. **Monitor Usage**: Regularly check Supabase for unused/used code statistics
6. **Secure Storage**: Never commit CSV files to version control
7. **Test First**: Always test a sample code before distributing hundreds

## 🔄 Workflow Example

### Complete Code Generation → Distribution Workflow

```
1. Developer Dashboard
   ↓
2. Activation Code Generator
   ↓
3. Select Package (Basic/Standard/Premium)
   ↓
4. Generate 100 codes
   ↓
5. Verify statistics
   ↓
6. Export to CSV
   ↓
7. Save to secure location
   ↓
8. Supabase Dashboard
   ↓
9. Import CSV to activation_codes table
   ↓
10. Verify row count in Supabase
   ↓
11. Delete local CSV file
   ↓
12. Distribute codes to customers
   ↓
13. Monitor activation in Supabase
```

---

**Version**: 1.0  
**Last Updated**: February 10, 2026  
**Compatible With**: Smart Monitoring System v1.0+
