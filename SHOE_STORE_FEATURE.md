# Shoe Store Feature Implementation

## Overview
This feature adds specialized shoe size management for businesses registered as "Shoe Store" type. When this business type is selected, the system enables product-level shoe size variants with individual quantity tracking based on Common Shoe Size Conversions (US, UK, EU, CM).

## Implementation Summary

### 1. Business Type Selection
**File Modified**: `lib/screens/admin/business_registration_screen.dart`
- Added "Shoe Store" to the business type dropdown
- Available business types now include:
  - Retail Store
  - Grocery
  - Convenience Store
  - Pharmacy
  - Restaurant
  - Cafe
  - Boutique
  - Electronics Shop
  - Hardware Store
  - Department Store
  - **Shoe Store** (NEW)
  - Other

### 2. Data Models

#### ShoeSize Model
**File Created**: `lib/models/shoe_size.dart`
```dart
class ShoeSize {
  final String usSize;
  final String ukSize;
  final String euSize;
  final String cmSize;
  final int quantity;
}
```

**Common Shoe Size Conversions Included**:
- **Men's Sizes**: US 6-14 (39 variations including half sizes)
- **Women's Sizes**: US 5-12 (35 variations including half sizes)
- **Unisex Sizes**: US 5-12 (standardized conversions)

#### Product Model Updates
**File Modified**: `lib/models/product.dart`
- Added `shoeSizes` field (List<ShoeSize>?)
- Added `sizeType` field (String? - 'men', 'women', 'unisex')
- Added `hasShoeVariants` getter to check if product has size variants
- Added `totalQuantity` getter to calculate total stock across all sizes
- Updated `toMap()` and `fromMap()` to serialize/deserialize shoe sizes as JSON

### 3. Database Schema
**File Modified**: `lib/services/database_service_io.dart`
- Database version bumped to **16**
- Added two new columns to `products` table:
  - `shoeSizes TEXT` - JSON-encoded array of shoe size objects
  - `sizeType TEXT` - Type of sizing chart used

**Migration Path**: Existing installations will automatically upgrade when app launches.

### 4. Product Management UI
**File Modified**: `lib/screens/admin/manage_products.dart`

**New Features**:
- Conditional UI section "Shoe Size Information" (only visible when business type = "Shoe Store")
- Size type dropdown (Men's / Women's / Unisex)
- Scrollable list of all size conversions with quantity input fields
- Display format: `US: 8.5 | UK: 8 | EU: 42 | CM: 26.5` with quantity field
- Quantity field for standard products is disabled when shoe sizes are active
- Total quantity auto-calculated from all size quantities on save

### 5. Owner Inventory Display
**File Modified**: `lib/screens/shared/inventory_screen.dart`

**Updates**:
- Product cards show total quantity across all sizes
- Added "👟 Tap to view sizes" indicator for shoe products
- Product details modal displays comprehensive size breakdown:
  - Each size shown with US/UK/EU/CM conversions
  - Color-coded quantity badges (green = in stock, red = out of stock)
  - Individual size quantities visible at a glance

### 6. POS Terminal Integration
**File Modified**: `lib/screens/cashier/cashier_pos.dart`

**New Functionality**:
- Product tiles display "Stock: XX (Multiple Sizes)" for shoe products
- Tapping a shoe product opens a **Size Selection Dialog**
- Dialog shows all available sizes with:
  - Full size conversions (US/UK/EU/CM)
  - Current stock quantity for each size
  - Disabled state for out-of-stock sizes
- Cashier selects size before adding to cart
- Confirmation message includes selected size

### 7. Localization
**File Modified**: `lib/utils/app_localizations.dart`

**New Strings Added** (English & Filipino):
- `shoe_size_section` - "Shoe Size Information" / "Impormasyon ng Laki ng Sapatos"
- `size_type` - "Size Type" / "Uri ng Laki"
- `men_sizes` - "Men Sizes" / "Laki para sa Lalaki"
- `women_sizes` - "Women Sizes" / "Laki para sa Babae"
- `unisex_sizes` - "Unisex Sizes" / "Unisex na Laki"
- `enter_quantity_per_size` - "Enter quantity for each size:" / "Ilagay ang dami para sa bawat laki:"
- `shoe_sizes_available` - "Shoe Sizes Available" / "Mga Available na Laki ng Sapatos"
- `tap_to_view_sizes` - "👟 Tap to view sizes" / "👟 I-tap upang tingnan ang mga laki"
- `select_size` - "Select Size" / "Pumili ng Laki"
- `multiple_sizes` - "Multiple Sizes" / "Maraming Laki"
- `added_to_cart` - "added to cart" / "naidagdag sa cart"

## Usage Workflow

### For Admin (Business Setup)
1. Navigate to **Admin Dashboard → Business Registration**
2. Select **"Shoe Store"** from Business Type dropdown
3. Complete store information and save
4. System now enables shoe size features for all product management

### For Admin/Owner (Adding Shoe Products)
1. Navigate to **Manage Products → Add Product**
2. Fill in basic product information (name, barcode, prices, category)
3. Select **Size Type** from dropdown (Men's / Women's / Unisex)
4. Scroll through size list and enter quantity for each available size
5. Leave quantity as 0 for sizes not in stock
6. Save product
7. Total quantity is automatically calculated and stored

### For Owner (Inventory Monitoring)
1. Navigate to **Inventory Screen**
2. Shoe products display with total quantity
3. Tap any shoe product to view **Size Breakdown Modal**
4. View individual stock levels per size with color indicators
5. Use for restock planning and size availability tracking

### For Cashier (POS Sales)
1. Open **POS Terminal**
2. Browse products (shoe products marked with "Multiple Sizes")
3. Tap desired shoe product
4. **Size Selection Dialog** appears
5. Tap available size (grayed-out sizes are out of stock)
6. Product added to cart with selected size information
7. Proceed with checkout as normal

## Technical Notes

### Data Storage
- Shoe sizes stored as JSON string in database for flexibility
- Parsing handled automatically by Product model
- Backward compatible: non-shoe products work as before

### Quantity Management
- For shoe products: `product.quantity` reflects total across all sizes
- Individual size quantities tracked separately in `shoeSizes` array
- Cart operations and stock deductions work with total quantity
- Future enhancement: Track size-specific sales in sale_items table

### Performance Considerations
- JSON encoding/decoding happens only during save/load operations
- Size selection dialog uses ListView for efficient rendering
- No impact on products without shoe sizes (optional fields)

### Business Logic Constraints
- Shoe size UI **only** appears when:
  - Business type is "Shoe Store"
  - User is adding/editing a product
- Size type must be selected before entering quantities
- Quantities default to 0 if not specified

## Future Enhancements

### Potential Improvements
1. **Size-Specific Cart Management**: Track which specific size is in cart (currently uses total quantity)
2. **Size-Based Analytics**: Report which sizes sell fastest
3. **Low Stock Alerts by Size**: Alert when specific sizes run low
4. **Size Transfer**: Move stock between sizes for adjustments
5. **Custom Size Charts**: Allow business to define their own size conversions
6. **Barcode per Size**: Generate unique barcodes for each size variant
7. **Size-Specific Pricing**: Different prices for different sizes (e.g., larger sizes cost more)

## Testing Checklist

- [x] Business type selection includes "Shoe Store"
- [x] Shoe size UI appears only when business is "Shoe Store"
- [x] All three size types (Men/Women/Unisex) display correct conversions
- [x] Product saves with shoe sizes to database
- [x] Product loads with shoe sizes from database
- [x] Inventory screen shows total quantity for shoe products
- [x] Inventory details modal shows size breakdown
- [x] POS terminal shows size selection dialog for shoe products
- [x] Out-of-stock sizes are disabled in POS
- [x] Localization works for both English and Filipino
- [x] Non-shoe products continue to work normally
- [x] Database migration from v15 to v16 works without data loss

## Files Modified/Created

### Created
- `lib/models/shoe_size.dart` (168 lines)

### Modified
- `lib/screens/admin/business_registration_screen.dart`
- `lib/models/product.dart`
- `lib/services/database_service_io.dart`
- `lib/screens/admin/manage_products.dart`
- `lib/screens/shared/inventory_screen.dart`
- `lib/screens/cashier/cashier_pos.dart`
- `lib/utils/app_localizations.dart`

**Total Lines Added**: ~450 lines
**Total Lines Modified**: ~200 lines

## Conclusion

The Shoe Store feature provides a complete solution for footwear retailers to manage inventory with size-specific tracking while maintaining seamless integration with the existing POS system. The implementation is business-type aware, meaning it only activates when needed and does not impact other retail operations.
