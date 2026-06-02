# Debugging Shoe Size Display - Step by Step

## CRITICAL: Make a NEW Sale After App Restart!

**⚠️ IMPORTANT:** Old sales (before you restarted the app) will NOT have shoe sizes because the database column didn't exist yet.

## Step-by-Step Testing Process

### Step 1: Inspect Database
1. Open the app
2. Login as **Owner**
3. Go to **Sales Reports**
4. **Click the bug icon (🐛) in the top-right corner**
5. Check the **console output** - you should see:

```
═══════════════════════════════════════
📊 DATABASE INSPECTION REPORT
═══════════════════════════════════════
✅ Database Version: 17
📋 sale_items TABLE SCHEMA:
   Column: shoeSize | Type: TEXT | Nullable: YES
✅ shoeSize column EXISTS
```

If you see `❌ shoeSize column MISSING`, the database migration didn't run. You need to:
- Close the app completely
- Delete the database file (or let it migrate)
- Restart the app

### Step 2: Check Existing Sales
The inspection report will show your recent sales:

```
📦 RECENT SALES WITH ITEMS:
   Sale #SAL123456 (ID: 1)
   Date: 2026-01-17
   Items: 2
      ❌ Regular Product x1 - NO SIZE
      ❌ Shoe Product x1 - NO SIZE   ← OLD SALE!
```

If all your sales show `❌ NO SIZE`, they were created before v17. **You need to make a NEW sale.**

### Step 3: Create a Shoe Product (If Not Done)
1. Login as **Admin**
2. Go to **Manage Products**
3. **Business Type:** Select "Shoe Store"
4. **Add Product:**
   - Name: Test Sneakers
   - Category: Shoes
   - Price: 1500
   - **Size Type:** Select "Men's" or "Women's" or "Unisex"
   - **Add Sizes:** Enter quantities for different sizes
     - US 7: Qty 5
     - US 8: Qty 5
     - US 9: Qty 5
5. **Save Product**

### Step 4: Make a NEW Test Sale
1. Login as **Cashier**
2. Go to **POS Terminal**
3. Tap on your shoe product
4. **⚠️ VERIFY:** A size selection dialog should appear
5. Select a size (e.g., US 8)
6. **Check console:** You should see:
   ```
   💾 Creating SaleItem: Test Sneakers, shoeSize: 8
   ```
7. Complete the checkout

### Step 5: Verify Display - Owner Sales Report
1. Login as **Owner**
2. Go to **Sales Reports**
3. **Check console output:**
   ```
   🔍 Sales Report: Displaying X sales
      👟 Sale #SAL789 has shoe items:
         - Test Sneakers Size 8
      Total sales with shoes: 1/X
   ```

4. **Look at the screen:**
   - Main sales list should show: `👟 Test Sneakers (8)` badge
   - Tap the sale to see detail dialog
   - Detail dialog should show `Size 8` badge

### Step 6: Verify Display - Cashier Sales History
1. Login as **Cashier**
2. Go to **Sales History** tab
3. Expand the recent sale
4. You should see `Size 8` badge next to the product

### Step 7: Verify Receipt
1. Complete a sale with shoe product
2. Generate receipt (PDF)
3. Receipt should show:
   ```
   Test Sneakers x1
     (Size: 8)
   ```

## Troubleshooting by Error Type

### Error 1: "No size selection dialog appears"
**Problem:** Product is not configured as shoe product
**Fix:**
- Go to Manage Products
- Edit the product
- Verify Business Type is "Shoe Store"
- Verify Size Type is selected (Men's/Women's/Unisex)
- Verify sizes have quantities > 0

### Error 2: "Console shows NO SIZE for all sales"
**Problem:** All your sales are OLD (before v17)
**Fix:**
- Make a NEW sale with a shoe product
- The new sale will have shoe size data

### Error 3: "Database version is less than 17"
**Problem:** Migration didn't run
**Fix:**
- Close app completely
- Restart app
- Click bug icon to inspect again
- Version should now be 17

### Error 4: "shoeSize column MISSING"
**Problem:** Database migration failed
**Fix:**
- Find database file: `C:\Users\PC\AppData\Local\<app_name>\pos_system.db`
- Delete the database file (or rename it for backup)
- Restart app (will create new database with v17 schema)
- Re-add products and make new sales

### Error 5: "Console shows 'Total sales with shoes: 0/X'"
**Problem:** No sales have shoe size data
**Fix:**
- Click bug icon and check inspection report
- Look at the sale items - do they show SIZE or NO SIZE?
- If NO SIZE: Make a NEW sale
- If you made a new sale but still NO SIZE:
  - Check console for `💾 Creating SaleItem` message
  - Verify it shows `shoeSize: 8` (not null)

## What Success Looks Like

### Console Output (Bug Icon Click):
```
✅ Database Version: 17
✅ shoeSize column EXISTS

📦 RECENT SALES WITH ITEMS:
   Sale #SAL789 (ID: 5)
   Items: 1
      ✅ Test Sneakers x1 - Size: 8

👟 PRODUCTS WITH SHOE SIZES:
   Test Sneakers (ID: 10)
      Type: mens
      Sizes: [{"usSize":7,...},{"usSize":8,...}]
```

### Screen Display:
- Main list: `👟 Test Sneakers (8)` in colored badge
- Detail dialog: `Size 8` badge next to product name
- Sales history: Same size badges
- Receipt: `(Size: 8)` below product name

## Quick Diagnostic Checklist

Run through this checklist:

1. [ ] Clicked bug icon (🐛) in Sales Reports
2. [ ] Database version is 17
3. [ ] shoeSize column EXISTS
4. [ ] Made a BRAND NEW sale (after seeing v17)
5. [ ] Console shows `💾 Creating SaleItem: ..., shoeSize: X`
6. [ ] Console shows `📦 Loaded X items` with shoeSize values
7. [ ] Console shows `👟 Sale #XXX has shoe items`
8. [ ] Screen shows 👟 emoji badge in sales list
9. [ ] Detail dialog shows size badge
10. [ ] Receipt shows size

If you check all these boxes and STILL don't see sizes, there may be a code issue. Share the console output with me.
