-- ============================================================================
-- Smart Monitoring System - Supabase Database Schema
-- ============================================================================
-- This schema supports multi-device shared data for multiple businesses/clients
-- Each business (client) can have multiple devices accessing the same data
-- Row Level Security (RLS) ensures data isolation between businesses
-- ============================================================================

-- Enable UUID extension for generating unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. BUSINESSES TABLE
-- ============================================================================
-- Stores information about each business/client
-- One business = One owner account with multiple devices

CREATE TABLE IF NOT EXISTS businesses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner_id TEXT NOT NULL,  -- Links to auth.users or User model
    owner_email TEXT NOT NULL UNIQUE,
    contact_number TEXT,
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    max_devices INTEGER DEFAULT 10,
    subscription_package TEXT,  -- basic, standard, premium, enterprise
    subscription_expires_at TIMESTAMP WITH TIME ZONE
);

-- Index for fast business lookups
CREATE INDEX IF NOT EXISTS idx_businesses_owner_email ON businesses(owner_email);
CREATE INDEX IF NOT EXISTS idx_businesses_is_active ON businesses(is_active);

-- ============================================================================
-- 2. PRODUCTS TABLE
-- ============================================================================
-- Stores all products for multi-device sync

CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    barcode TEXT,
    category TEXT,
    selling_price REAL NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 0,
    image_path TEXT,
    low_stock_threshold INTEGER DEFAULT 5,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_products_business_id ON products(business_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_low_stock ON products(business_id, quantity);

-- ============================================================================
-- 3. SALES TABLE
-- ============================================================================
-- Stores all sales transactions

CREATE TABLE IF NOT EXISTS sales (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    cashier_id TEXT NOT NULL,
    cashier_name TEXT NOT NULL,
    customer_name TEXT,
    payment_method TEXT NOT NULL,  -- cash, card, ewallet
    status TEXT NOT NULL DEFAULT 'completed',  -- completed, cancelled, refunded
    subtotal REAL NOT NULL DEFAULT 0,
    discount REAL DEFAULT 0,
    total_amount REAL NOT NULL DEFAULT 0,
    amount_paid REAL DEFAULT 0,
    change_amount REAL DEFAULT 0,
    item_count INTEGER DEFAULT 0,
    datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for sales analytics
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON sales(business_id);
CREATE INDEX IF NOT EXISTS sales_datetime ON sales(business_id, datetime DESC);
CREATE INDEX IF NOT EXISTS idx_sales_cashier ON sales(cashier_id);
CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(business_id, status);

-- ============================================================================
-- 4. SALE ITEMS TABLE
-- ============================================================================
-- Stores individual items in each sale

CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price REAL NOT NULL,
    discount REAL DEFAULT 0,
    subtotal REAL NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_business_id ON sale_items(business_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id);

-- ============================================================================
-- 5. INVENTORY MOVEMENTS TABLE
-- ============================================================================
-- Tracks all inventory changes (restocks, sales, adjustments)

CREATE TABLE IF NOT EXISTS inventory_movements (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    movement_type TEXT NOT NULL,  -- sale, restock, adjustment, return
    quantity INTEGER NOT NULL,
    reference TEXT,  -- Reference to sale_id or purchase order
    notes TEXT,
    performed_by TEXT,  -- User ID who performed the action
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_inventory_movements_business_id ON inventory_movements(business_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_id ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_timestamp ON inventory_movements(business_id, timestamp DESC);

-- ============================================================================
-- 6. DAMAGE REPORTS TABLE
-- ============================================================================
-- Tracks damaged or defective products

CREATE TABLE IF NOT EXISTS damage_reports (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    damage_type TEXT,  -- broken, expired, defective, missing
    description TEXT,
    reported_by TEXT,
    reported_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'pending',  -- pending, resolved, written_off
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_damage_reports_business_id ON damage_reports(business_id);
CREATE INDEX IF NOT EXISTS idx_damage_reports_product_id ON damage_reports(product_id);
CREATE INDEX IF NOT EXISTS idx_damage_reports_status ON damage_reports(business_id, status);

-- ============================================================================
-- 7. CAMERAS TABLE (for CCTV module)
-- ============================================================================

CREATE TABLE IF NOT EXISTS cameras (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    location TEXT,
    stream_url TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cameras_business_id ON cameras(business_id);

-- ============================================================================
-- 8. CCTV TIMESTAMPS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS cctv_timestamps (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    camera_id TEXT NOT NULL,
    label TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT,
    created_by TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cctv_timestamps_business_id ON cctv_timestamps(business_id);
CREATE INDEX IF NOT EXISTS idx_cctv_timestamps_camera_id ON cctv_timestamps(camera_id);

-- ============================================================================
-- 9. SUPPLIERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS suppliers (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_business_id ON suppliers(business_id);

-- ============================================================================
-- 10. PURCHASE ORDERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS purchase_orders (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    supplier_id TEXT REFERENCES suppliers(id),
    order_number TEXT NOT NULL,
    order_date TIMESTAMP WITH TIME ZONE NOT NULL,
    expected_delivery TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'pending',
    total_amount REAL DEFAULT 0,
    notes TEXT,
    created_by TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_business_id ON purchase_orders(business_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
-- Ensures each business can only access their own data

-- Enable RLS on all tables
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE damage_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE cameras ENABLE ROW LEVEL SECURITY;
ALTER TABLE cctv_timestamps ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- BUSINESSES POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can view their own business" ON businesses;
CREATE POLICY "Users can view their own business"
    ON businesses FOR SELECT
    USING (
        owner_id = auth.uid()::text OR 
        owner_email = auth.email()
    );

DROP POLICY IF EXISTS "Users can update their own business" ON businesses;
CREATE POLICY "Users can update their own business"
    ON businesses FOR UPDATE
    USING (
        owner_id = auth.uid()::text OR 
        owner_email = auth.email()
    );

DROP POLICY IF EXISTS "Users can insert their own business" ON businesses;
CREATE POLICY "Users can insert their own business"
    ON businesses FOR INSERT
    WITH CHECK (
        owner_id = auth.uid()::text OR 
        owner_email = auth.email()
    );

-- ============================================================================
-- PRODUCTS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business products" ON products;
CREATE POLICY "Users can only access their business products"
    ON products FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- SALES POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business sales" ON sales;
CREATE POLICY "Users can only access their business sales"
    ON sales FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- SALE ITEMS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business sale items" ON sale_items;
CREATE POLICY "Users can only access their business sale items"
    ON sale_items FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- INVENTORY MOVEMENTS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business inventory movements" ON inventory_movements;
CREATE POLICY "Users can only access their business inventory movements"
    ON inventory_movements FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- DAMAGE REPORTS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business damage reports" ON damage_reports;
CREATE POLICY "Users can only access their business damage reports"
    ON damage_reports FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- CAMERAS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business cameras" ON cameras;
CREATE POLICY "Users can only access their business cameras"
    ON cameras FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- CCTV TIMESTAMPS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business cctv timestamps" ON cctv_timestamps;
CREATE POLICY "Users can only access their business cctv timestamps"
    ON cctv_timestamps FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- SUPPLIERS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business suppliers" ON suppliers;
CREATE POLICY "Users can only access their business suppliers"
    ON suppliers FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- PURCHASE ORDERS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can only access their business purchase orders" ON purchase_orders;
CREATE POLICY "Users can only access their business purchase orders"
    ON purchase_orders FOR ALL
    USING (
        business_id IN (
            SELECT id FROM businesses 
            WHERE owner_id = auth.uid()::text OR owner_email = auth.email()
        )
    );

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = '';

-- Triggers for automatic updated_at updates
DROP TRIGGER IF EXISTS update_businesses_updated_at ON businesses;
CREATE TRIGGER update_businesses_updated_at BEFORE UPDATE ON businesses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to decrement product stock (used during sales)
CREATE OR REPLACE FUNCTION decrement_product_stock(
    product_id_param TEXT,
    quantity_param INTEGER,
    business_id_param TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE products
    SET quantity = quantity - quantity_param,
        updated_at = NOW()
    WHERE id = product_id_param 
      AND business_id = business_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Function to get total sales for a business in date range
CREATE OR REPLACE FUNCTION get_total_sales(
    business_id_param TEXT,
    start_date_param TIMESTAMP WITH TIME ZONE,
    end_date_param TIMESTAMP WITH TIME ZONE
)
RETURNS REAL AS $$
DECLARE
    total REAL;
BEGIN
    SELECT COALESCE(SUM(total_amount), 0) INTO total
    FROM sales
    WHERE business_id = business_id_param
      AND datetime >= start_date_param
      AND datetime <= end_date_param
      AND status = 'completed';
    
    RETURN total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ============================================================================
-- SAMPLE DATA (OPTIONAL - For testing only)
-- ============================================================================

-- Uncomment below to insert sample business for testing
/*
INSERT INTO businesses (id, name, owner_id, owner_email, contact_number)
VALUES (
    'biz-sample-001',
    'Sample Store',
    'test-owner-id',
    'owner@example.com',
    '+1234567890'
) ON CONFLICT (id) DO NOTHING;
*/

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify your setup

-- Check all tables created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- Check policies created
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
ORDER BY tablename, policyname;

-- ============================================================================
-- DONE! 🎉
-- ============================================================================
-- Your database is now ready for multi-device cloud sync!
-- Each business will have isolated data accessible from multiple devices.
