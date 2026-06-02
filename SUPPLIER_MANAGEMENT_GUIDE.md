# Supplier Management - Quick Start Guide

## Accessing Supplier Management

### From Owner Dashboard:
```
Owner Dashboard → Supplier Management Card (Indigo, Truck Icon)
```

## Screen Layout

### Tab 1: Suppliers
```
┌─────────────────────────────────────────┐
│ [Search Bar]                      [×]   │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ [A] ABC Trading Co.                 │ │
│ │     Contact: John Doe               │ │
│ │     Phone: 09123456789         [⋮]  │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ [X] XYZ Supplies (Inactive)         │ │
│ │     Contact: Jane Smith             │ │
│ │     Phone: 09198765432         [⋮]  │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
                [+] Add Supplier
```

### Tab 2: Restock History
```
┌─────────────────────────────────────────┐
│ ┌─────────────────────────────────────┐ │
│ │ [📦] Coca Cola 1L                   │ │
│ │      Quantity: 50                   │ │
│ │      Supplier: ABC Trading Co.      │ │
│ │      By: Owner Name            [📝] │ │
│ │      01/10/2026 2:30 PM             │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ [📦] Bread Loaf                     │ │
│ │      Quantity: 100                  │ │
│ │      Supplier: XYZ Supplies         │ │
│ │      By: Owner Name            [📝] │ │
│ │      01/09/2026 9:15 AM             │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Add Supplier Dialog
```
┌─────────────────────────────────────────┐
│         Add Supplier                    │
├─────────────────────────────────────────┤
│ Supplier Name *                         │
│ ┌─────────────────────────────────────┐ │
│ │ ABC Trading Co.                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Contact Person *                        │
│ ┌─────────────────────────────────────┐ │
│ │ John Doe                            │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Phone *                                 │
│ ┌─────────────────────────────────────┐ │
│ │ 09123456789                         │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Email                                   │
│ ┌─────────────────────────────────────┐ │
│ │ john@abctrading.com                 │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Address                                 │
│ ┌─────────────────────────────────────┐ │
│ │ 123 Market St, Manila               │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Notes                                   │
│ ┌─────────────────────────────────────┐ │
│ │ Delivers Monday-Friday              │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│              [Cancel]    [Add]          │
└─────────────────────────────────────────┘
```

## Restock with Supplier (Inventory Screen)
```
┌─────────────────────────────────────────┐
│      Delivery Received                  │
├─────────────────────────────────────────┤
│         Coca Cola 1L                    │
│         Stock: 20                       │
├─────────────────────────────────────────┤
│ Quantity Received                       │
│ ┌─────────────────────────────────────┐ │
│ │ 50                                  │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Supplier (Optional)                     │
│ ┌─────────────────────────────────────┐ │
│ │ ABC Trading Co.            [▼]      │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Delivery Note (Optional)                │
│ ┌─────────────────────────────────────┐ │
│ │ Invoice #12345                      │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│         [Cancel]    [Record Delivery]   │
└─────────────────────────────────────────┘
```

## Supplier Menu Options
```
┌─────────────────────────────┐
│ ✏️  Edit                    │
│ ℹ️  View Details            │
│ ✅ Deactivate (or Activate) │
│ 🗑️  Delete                  │
└─────────────────────────────┘
```

## View Supplier Details
```
┌─────────────────────────────────────────┐
│         ABC Trading Co.                 │
├─────────────────────────────────────────┤
│ Contact Person:  John Doe               │
│ Phone:          09123456789             │
│ Email:          john@abctrading.com     │
│ Address:        123 Market St, Manila   │
│ Notes:          Delivers Monday-Friday  │
│ Status:         Active                  │
│ Created At:     01/05/2026 10:00 AM     │
├─────────────────────────────────────────┤
│         Restock History                 │
│                                         │
│ • Coca Cola 1L (50) - 01/10/2026        │
│ • Pepsi 1L (30) - 01/08/2026            │
│ • 7UP 1L (25) - 01/06/2026              │
├─────────────────────────────────────────┤
│                [Close]                  │
└─────────────────────────────────────────┘
```

## Workflow Example

### Scenario: Receiving Delivery from Supplier

1. **Go to Inventory Status** (Owner Dashboard → Inventory Status)
2. **Find the product** that needs restocking
3. **Tap "Restock Item"** button
4. **Enter quantity received** (e.g., 50)
5. **Select supplier** from dropdown (e.g., ABC Trading Co.)
6. **Add notes** if needed (e.g., invoice number)
7. **Tap "Record Delivery"**
8. ✅ **Product quantity updated** (20 → 70)
9. ✅ **Restock record created** with supplier linkage
10. ✅ **History available** in Supplier Management → Restock History tab

### Scenario: Adding New Supplier

1. **Open Supplier Management** (Owner Dashboard → Supplier Management)
2. **Tap floating "Add Supplier" button**
3. **Fill required fields**:
   - Supplier Name: "DEF Distributors"
   - Contact Person: "Maria Cruz"
   - Phone: "09111222333"
4. **Fill optional fields**:
   - Email: "maria@defdist.com"
   - Address: "456 Commerce Ave"
   - Notes: "Best prices on beverages"
5. **Tap "Add"**
6. ✅ **Supplier added to system**
7. ✅ **Available in restock dropdown**

### Scenario: Viewing Supplier Performance

1. **Open Supplier Management**
2. **Find supplier in list**
3. **Tap menu (⋮) → View Details**
4. **Review restock history**:
   - See all products supplied
   - Check delivery dates
   - Verify quantities
5. **Make informed decisions** about supplier relationships

## Tips

- **Search is case-insensitive** - searches name, contact person, and phone
- **Inactive suppliers** don't appear in restock dropdown
- **Restock history** shows most recent first
- **Notes icon** in history tab indicates restock has notes
- **Color indicators**: Green circle = Active, Grey circle = Inactive
- **Required fields** are marked with asterisk (*)
- **Supplier selection is optional** during restock (backward compatible)

## Benefits

✅ **Track supplier relationships**
✅ **Monitor restocking patterns**
✅ **Identify reliable suppliers**
✅ **Maintain delivery records**
✅ **Improve inventory planning**
✅ **Audit trail for all restocks**
✅ **Quick access to supplier contact info**
✅ **Historical data for analysis**
