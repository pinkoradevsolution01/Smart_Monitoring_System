-- ============================================================================
-- MIGRATION: Fix missing foreign key relationship between sales and sale_items
-- ============================================================================
-- Issue: Supabase PostgREST throws PGRST200 error when trying to fetch sales
-- with related sale_items because no FK relationship is defined
-- ============================================================================

-- Step 1: Add the missing foreign key constraint
-- This creates the relationship that Supabase needs to fetch nested data

ALTER TABLE sale_items
ADD CONSTRAINT fk_sale_items_sales 
FOREIGN KEY (sale_id) 
REFERENCES sales(id) 
ON DELETE CASCADE;

-- Step 2: Verify the constraint was added
-- Query: SELECT constraint_name FROM information_schema.table_constraints WHERE table_name='sale_items';

-- Step 3: Update the schema cache (Supabase will automatically detect this)
-- Once this migration is applied, the app can fetch sales with their items via:
-- SELECT * FROM sales WITH (sale_items:sale_id!inner())

-- ============================================================================
-- EXPLANATION
-- ============================================================================
-- Before: 
--   sale_items.sale_id was just a TEXT field with no relationship
--   Supabase couldn't find the relationship in schema cache
--
-- After:
--   sale_items.sale_id now has a proper FK to sales(id)
--   Supabase recognizes the relationship
--   Can fetch sales WITH their items using PostgREST syntax
-- ============================================================================
