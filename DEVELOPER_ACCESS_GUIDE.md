# Developer Access Guide

## 🔧 Developer Dashboard Access

### How to Access Developer Dashboard

1. **From Login Screen:**
   - At the bottom of the login form, find the gray text "Developer Access"
   - Click on "Developer Access"
   - Enter developer password

2. **Default Developer Credentials:**
   - **Password Option 1:** `dev123`
   - **Password Option 2:** `developer`

### Developer Dashboard Features

#### 📦 Package Management

**1. Update Package**
- Change package without losing any data
- All products, sales, and users remain intact
- Select new package from list
- Perfect for upgrading or downgrading plans

**2. Reset Package Selection**
- Clears package selection only
- Keeps ALL app data (products, sales, users)
- Returns to package selection screen
- Use this to test different package tiers

#### 💾 Data Management

**3. Clear SharedPreferences**
- Clears all app settings:
  - Package selection
  - Theme settings
  - Language preferences
  - Motion settings
- Database data remains intact
- Restart app to see fresh settings

**4. Factory Reset**
- **⚠️ DESTRUCTIVE OPERATION**
- Deletes EVERYTHING:
  - All products
  - All sales records
  - All user accounts
  - All settings
  - Package selection
- Type "DELETE" to confirm
- Returns to package selection screen
- Use only when starting completely fresh

#### 🐛 Debug Information

The dashboard shows real-time debug info:
- Has Package (true/false)
- Setup Complete (true/false)
- Feature Access Flags:
  - CCTV Access
  - E-Wallet Access
  - Cloud Sync
  - Supplier Management

## Usage Scenarios

### Scenario 1: Testing Different Packages
```
1. Login as Developer
2. Click "Update Package"
3. Select different package (e.g., Basic → Premium)
4. Check Owner Dashboard to see new features
5. Repeat to test other packages
```

### Scenario 2: Complete Package Reset
```
1. Login as Developer
2. Click "Reset Package Selection"
3. System goes back to package selection
4. Choose new package
5. All data still available
```

### Scenario 3: Clear All Settings
```
1. Login as Developer
2. Click "Clear SharedPreferences"
3. Restart app
4. Package selection shows again
5. All themes/languages reset to default
```

### Scenario 4: Fresh Start (Factory Reset)
```
1. Login as Developer
2. Click "Factory Reset"
3. Type "DELETE" exactly
4. Confirm
5. System completely clean
6. Go through package selection again
```

## Technical Details

### Current Package Card
Shows:
- Package Name (Basic/Standard/Premium/Enterprise)
- Price (₱2,999 - Custom Pricing)
- Max Users allowed
- Max Products allowed
- Setup Complete status

### PackageService Methods

**selectPackage(package)** - Initial package selection
- Sets package
- Marks setup as complete
- Saves to SharedPreferences

**updatePackage(package)** - Change package
- Updates current package
- Keeps setup complete flag
- Preserves all data
- Immediate effect

**resetSetup()** - Clear package only
- Removes package selection
- Clears setup complete flag
- Keeps all database data

### Security Note

The developer password is hardcoded for simplicity:
- Current passwords: `dev123` or `developer`
- In production, implement proper authentication
- Consider adding to environment variables
- Use secure password hashing

### Color Coding

Dashboard uses dark theme with color-coded cards:
- 🔵 Blue = Update/Modify operations
- 🟠 Orange = Reset/Clear operations  
- 🟣 Purple = Settings operations
- 🔴 Red = Destructive operations

## Tips

1. **Before Testing Packages:**
   - Use "Update Package" to preserve data
   - Check feature access in Debug Info section
   - Visit Owner Dashboard to verify features

2. **Before Presenting to Client:**
   - Use "Reset Package Selection" 
   - Let them choose their package
   - All demo data remains available

3. **After Demo/Testing:**
   - Use "Factory Reset" for clean slate
   - Remove test products and sales
   - Start fresh for next demo

4. **Troubleshooting:**
   - If package not working: Use "Reset Package"
   - If settings corrupted: Use "Clear SharedPreferences"
   - If complete mess: Use "Factory Reset"

## Quick Reference

| Action | Data Loss? | Returns To |
|--------|-----------|-----------|
| Update Package | ❌ No | Current screen |
| Reset Package | ❌ No | Package Selection |
| Clear Preferences | ❌ No (DB safe) | Current screen |
| Factory Reset | ✅ YES | Package Selection |

## Future Enhancements

Possible additions:
- Package expiration dates
- Usage analytics
- Feature usage tracking
- License key management
- Multi-tenancy support
- Backup before factory reset
