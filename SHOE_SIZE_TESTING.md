# Testing Shoe Size Display

## Important Notes

**⚠️ Old sales created before database v17 will NOT have shoe size data.**

You need to make a NEW sale with shoe products to see the shoe sizes.

## How to Test

### 1. Verify Database Version
- The app should automatically upgrade to database v17 when you run it
- Check the console output for migration messages

### 2. Create/View Shoe Products

#### As Admin:
1. Go to Admin Dashboard → Manage Products
2. Select "Shoe Store" as business type
3. Add a shoe product with sizes (e.g., Nike Sneakers)
4. Enter quantities for different sizes (US 7, 8, 9, etc.)
5. Save the product

### 3. Make a Test Sale

#### As Cashier:
1. Go to POS Terminal
2. Tap on a shoe product
3. **You should see a size selection dialog**
4. Select a size (e.g., US 8)
5. Product should be added to cart with size badge
6. Complete the checkout
7. **Look for debug output:** `💾 Creating SaleItem: [Product Name], shoeSize: 8`

### 4. Verify Shoe Size Display

#### In Cashier POS:
1. Go to Sales History tab
2. Expand a sale that includes shoes
3. **You should see:** `Size 8` badge next to the shoe product name

#### In Owner Sales Report:
1. Go to Sales Reports
2. **You should see:** 
   - 👟 emoji badges in the main sales list showing "Nike Sneakers (8)"
   - Tap any sale with shoes to see detailed dialog
   - Detail dialog shows "Size 8" badge for each shoe item
3. Check Daily Sales summary
   - Same shoe size badges in the list
4. Generate a receipt (PDF)
   - Receipt should show "(Size: 8)" below shoe product names

### 5. Debug Output

Watch the console for these messages:

```
💾 Creating SaleItem: Nike Sneakers, shoeSize: 8
📦 Loaded 2 items for sale 123
   - Nike Sneakers, shoeSize: 8
   - Regular Product, shoeSize: null
```

## What Should Be Displayed

### ✅ Sales List (Main View)
- Shoe products appear with 👟 emoji
- Product name and size in colored badge: `👟 Nike Sneakers (8)`

### ✅ Detail Dialog (Tap on Sale)
- "Size 8" badge next to shoe product name
- Colored badge with primary theme color

### ✅ PDF Receipt
- Under product name: `(Size: 8)` in small gray text

### ✅ Cashier Sales History
- Expandable list shows "Size 8" badge in primary theme color

## Troubleshooting

### "I don't see shoe sizes"

**Check:**
1. Is the sale NEW? (created after v17 database upgrade)
2. Did you select a size when adding to cart?
3. Check debug console for `💾 Creating SaleItem` messages
4. Restart the app to ensure database migration runs

### "Size selection dialog doesn't appear"

**Check:**
1. Is the product type "Shoe Store"?
2. Does the product have sizes defined?
3. Are there quantities > 0 for at least one size?

### "Old sales don't show sizes"

**This is expected!** Old sales (before v17) don't have shoe size data in the database.
- The `shoeSize` column was added in v17
- Only NEW sales (after migration) will have shoe size data
- Old sales will show products without size badges

## Expected Behavior

| Location | Display Format | Example |
|----------|----------------|---------|
| POS Cart | Badge after name | "Nike Sneakers **Size 8**" |
| Sales List | 👟 with size | "👟 Nike Sneakers (8)" |
| Detail Dialog | Colored badge | "Nike Sneakers **Size 8**" |
| Receipt PDF | Text below name | "Nike Sneakers x1<br>  _(Size: 8)_" |
| Sales History | Primary colored badge | "Nike Sneakers **Size 8**" |

## Database Schema (v17)

```sql
CREATE TABLE sale_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  saleId INTEGER NOT NULL,
  productId INTEGER NOT NULL,
  productName TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unitPrice REAL NOT NULL,
  discount REAL NOT NULL DEFAULT 0,
  subtotal REAL NOT NULL,
  shoeSize TEXT,  -- Added in v17
  FOREIGN KEY (saleId) REFERENCES sales (id)
);
```

## Quick Test Checklist

- [ ] Database upgraded to v17
- [ ] Created shoe product with sizes
- [ ] Selected specific size during checkout
- [ ] Saw "💾 Creating SaleItem" debug message with shoeSize
- [ ] Cart shows size badge
- [ ] Receipt shows size
- [ ] Cashier sales history shows size badge
- [ ] Owner sales report main list shows 👟 badge
- [ ] Detail dialog shows size badge
- [ ] Old sales (if any) correctly show NO size

## Notes

- Shoe size is stored as US size (string) in database
- Display shows only US size for simplicity
- Size selection dialog shows full conversion (US/UK/EU/CM)
- Cart and receipts show only US size
- Color scheme follows theme primary color
