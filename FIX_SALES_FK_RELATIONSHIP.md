# Fix: Missing Foreign Key Relationship Between Sales and Sale Items

## Problem
Error when syncing data from cloud:
```
PostgrestException: Could not find a relationship between 'sales' and 'sale_items' 
in the schema cache (PGRST200)
```

## Root Cause
The `sale_items` table was missing a foreign key constraint to the `sales` table. Supabase PostgREST needs this relationship to fetch nested data using the `select('*, sale_items(*)')` query.

## Solution

### Step 1: Go to Supabase Dashboard
1. Navigate to your Supabase project: https://app.supabase.com
2. Open the **SQL Editor**

### Step 2: Run Migration Script
Copy and paste this SQL script into the SQL Editor:

```sql
-- Add missing foreign key constraint between sale_items and sales
ALTER TABLE sale_items
ADD CONSTRAINT fk_sale_items_sales 
FOREIGN KEY (sale_id) 
REFERENCES sales(id) 
ON DELETE CASCADE;
```

### Step 3: Execute
Click "Run" button to execute the migration.

You should see: `Success. No rows returned`

### Step 4: Verify (Optional)
To verify the constraint was added, run:
```sql
SELECT constraint_name 
FROM information_schema.table_constraints 
WHERE table_name='sale_items';
```

Expected output includes: `fk_sale_items_sales`

## What This Does
- ✅ Creates relationship between `sales` and `sale_items` tables
- ✅ Allows Supabase to fetch sales WITH their related items
- ✅ Enables cascading deletes (when a sale is deleted, its items are too)
- ✅ Fixes PGRST200 error when syncing data

## Testing
After applying the migration:
1. Close the app completely
2. Reopen the app
3. Go to Owner Dashboard → Settings → Cloud Sync & Backup
4. Click "Restore from Cloud" to test the sync

The data should sync without errors!

## If You Still Get Errors
1. Clear app data and restart
2. Check Supabase dashboard → SQL Editor to ensure migration ran
3. Common issue: If you added data before the FK was created, try:
   ```sql
   -- Delete invalid references (if sale_id doesn't exist in sales table)
   DELETE FROM sale_items 
   WHERE sale_id NOT IN (SELECT id FROM sales);
   
   -- Then run the ALTER TABLE command above
   ```

## Files Updated
- ✅ `SUPABASE_SCHEMA.sql` - Schema now includes FK constraint
- ✅ `MIGRATION_FIX_SALE_ITEMS_FK.sql` - Migration script with instructions
- ✅ `supabase_sync_service.dart` - Code unchanged (it already expects the FK)

---

**Date:** March 8, 2026  
**Status:** Ready to deploy  
**Impact:** Fixes cloud sync for sales/items data
