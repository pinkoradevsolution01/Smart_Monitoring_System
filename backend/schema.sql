-- MySQL schema for Smart Monitoring System backend
CREATE DATABASE IF NOT EXISTS smart_monitoring;
USE smart_monitoring;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(64) NOT NULL DEFAULT 'owner',
  full_name VARCHAR(255),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS businesses (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  owner_email VARCHAR(255) NOT NULL,
  owner_id VARCHAR(64) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS activation_codes (
  code VARCHAR(64) PRIMARY KEY,
  package_name VARCHAR(128) DEFAULT 'Standard',
  status ENUM('unused', 'used', 'revoked', 'assigned') NOT NULL DEFAULT 'unused',
  device_id VARCHAR(128),
  device_name VARCHAR(255),
  used_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(128) NOT NULL,
  activation_code VARCHAR(64) NOT NULL,
  package_name VARCHAR(128) NOT NULL,
  device_name VARCHAR(255) NOT NULL,
  activated_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  status ENUM('active', 'expired', 'cancelled') NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (activation_code) REFERENCES activation_codes(code)
);

CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  barcode VARCHAR(255),
  name VARCHAR(255) NOT NULL,
  category VARCHAR(128),
  selling_price DECIMAL(12, 2) NOT NULL DEFAULT 0.0,
  quantity INT NOT NULL DEFAULT 0,
  image_path TEXT,
  low_stock_threshold INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX idx_products_business (business_id)
);

CREATE TABLE IF NOT EXISTS suppliers (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  name VARCHAR(255) NOT NULL,
  contact_person VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(128),
  address TEXT,
  notes TEXT,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL,
  INDEX idx_suppliers_business (business_id)
);

CREATE TABLE IF NOT EXISTS sales (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  cashier_id VARCHAR(64),
  cashier_name VARCHAR(255),
  customer_name VARCHAR(255),
  payment_method VARCHAR(128),
  status VARCHAR(64),
  subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0.0,
  discount DECIMAL(12, 2) NOT NULL DEFAULT 0.0,
  total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.0,
  amount_paid DECIMAL(12, 2) NOT NULL DEFAULT 0.0,
  change_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.0,
  item_count INT NOT NULL DEFAULT 0,
  datetime DATETIME NOT NULL,
  notes TEXT,
  created_at DATETIME NOT NULL,
  INDEX idx_sales_business (business_id)
);

CREATE TABLE IF NOT EXISTS sale_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  sale_id VARCHAR(64) NOT NULL,
  business_id VARCHAR(64) NOT NULL,
  product_id VARCHAR(64) NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(12, 2) NOT NULL,
  discount DECIMAL(12, 2) NOT NULL,
  subtotal DECIMAL(12, 2) NOT NULL,
  created_at DATETIME NOT NULL,
  INDEX idx_sale_items_sale (sale_id),
  INDEX idx_sale_items_business (business_id)
);

CREATE TABLE IF NOT EXISTS purchase_orders (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  supplier_id VARCHAR(64),
  order_number VARCHAR(255),
  order_date DATETIME NOT NULL,
  expected_delivery DATETIME,
  status VARCHAR(64),
  total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.0,
  notes TEXT,
  created_by VARCHAR(255),
  created_at DATETIME NOT NULL,
  INDEX idx_purchase_orders_business (business_id)
);

CREATE TABLE IF NOT EXISTS inventory_movements (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  product_id VARCHAR(64) NOT NULL,
  product_name VARCHAR(255),
  movement_type VARCHAR(128),
  quantity INT NOT NULL,
  reference VARCHAR(255),
  notes TEXT,
  performed_by VARCHAR(255),
  timestamp DATETIME NOT NULL,
  created_at DATETIME NOT NULL,
  INDEX idx_inventory_movements_business (business_id)
);

CREATE TABLE IF NOT EXISTS damage_reports (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  product_id VARCHAR(64) NOT NULL,
  product_name VARCHAR(255),
  quantity INT NOT NULL,
  damage_type VARCHAR(128),
  description TEXT,
  reported_by VARCHAR(255),
  reported_at DATETIME NOT NULL,
  status VARCHAR(64),
  resolution_notes TEXT,
  created_at DATETIME NOT NULL,
  INDEX idx_damage_reports_business (business_id)
);
