-- MySQL schema for Smart Monitoring System
-- Mirrors the Supabase/Postgres tables used by the app and backend.

CREATE DATABASE IF NOT EXISTS smart_monitoring
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE smart_monitoring;

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS businesses (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  owner_id VARCHAR(64) NOT NULL,
  owner_email VARCHAR(255) NOT NULL,
  contact_number VARCHAR(64),
  address TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  max_devices INT NOT NULL DEFAULT 10,
  subscription_package VARCHAR(64),
  subscription_expires_at DATETIME NULL,
  UNIQUE KEY uq_businesses_owner_email (owner_email),
  KEY idx_businesses_owner_id (owner_id),
  KEY idx_businesses_is_active (is_active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NULL,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(64) NOT NULL DEFAULT 'owner',
  full_name VARCHAR(255) NOT NULL,
  contact_number VARCHAR(64),
  auth_method VARCHAR(32) NOT NULL DEFAULT 'password',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_business_email (business_id, email),
  KEY idx_users_business (business_id),
  KEY idx_users_business_role (business_id, role),
  CONSTRAINT fk_users_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS activation_codes (
  code VARCHAR(64) PRIMARY KEY,
  package_name VARCHAR(128) NOT NULL DEFAULT 'Standard',
  status ENUM('unused', 'used', 'revoked', 'assigned') NOT NULL DEFAULT 'unused',
  device_id VARCHAR(128),
  device_name VARCHAR(255),
  assigned_at DATETIME NULL,
  email_sent_at DATETIME NULL,
  expires_at DATETIME NULL,
  notes TEXT,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_activation_codes_status (status),
  KEY idx_activation_codes_device_id (device_id),
  KEY idx_activation_codes_package_name (package_name),
  KEY idx_activation_codes_expires_at (expires_at),
  KEY idx_activation_codes_available (package_name, status, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS activation_code_requests (
  id CHAR(36) NOT NULL PRIMARY KEY DEFAULT (UUID()),
  business_name VARCHAR(255) NOT NULL,
  package_name VARCHAR(128) NOT NULL,
  package_price VARCHAR(64) NOT NULL,
  request_type ENUM('monthly', 'one_time_license', 'trial', 'trial_upgrade') NOT NULL,
  contact_email VARCHAR(255) NOT NULL,
  contact_phone VARCHAR(64) NOT NULL,
  additional_notes TEXT,
  status ENUM('pending', 'fulfilled', 'cancelled') NOT NULL DEFAULT 'pending',
  activation_code VARCHAR(64) NULL,
  requested_at DATETIME NOT NULL,
  fulfilled_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_activation_requests_status (status),
  KEY idx_activation_requests_email (contact_email),
  KEY idx_activation_requests_code (activation_code),
  KEY idx_activation_requests_requested_at (requested_at),
  KEY idx_activation_requests_status_requested_at (status, requested_at),
  CONSTRAINT fk_activation_requests_code
    FOREIGN KEY (activation_code) REFERENCES activation_codes(code)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS email_otps (
  id CHAR(36) NOT NULL PRIMARY KEY DEFAULT (UUID()),
  email VARCHAR(255) NOT NULL,
  otp VARCHAR(128) NOT NULL,
  expires_at DATETIME NOT NULL,
  used TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_email_otps_email (email),
  KEY idx_email_otps_expires_at (expires_at),
  KEY idx_email_otps_lookup (email, otp, used, expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS developer_notification_settings (
  id CHAR(36) NOT NULL PRIMARY KEY DEFAULT (UUID()),
  notification_email VARCHAR(255) NOT NULL,
  webhook_url TEXT,
  email_enabled TINYINT(1) NOT NULL DEFAULT 1,
  webhook_enabled TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS developer_accounts (
  id VARCHAR(32) PRIMARY KEY,
  display_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NULL,
  auth_method VARCHAR(32) NOT NULL DEFAULT 'password',
  google_sub VARCHAR(255) NULL,
  avatar_url TEXT,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS subscriptions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(128) NOT NULL,
  activation_code VARCHAR(64) NOT NULL,
  package_name VARCHAR(128) NOT NULL,
  device_name VARCHAR(255) NOT NULL,
  activated_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  status ENUM('active', 'expired', 'cancelled') NOT NULL DEFAULT 'active',
  last_checked_at DATETIME NULL,
  notes TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_subscriptions_activation_code (activation_code),
  KEY idx_subscriptions_device_id (device_id),
  KEY idx_subscriptions_status (status),
  KEY idx_subscriptions_expires_at (expires_at),
  CONSTRAINT fk_subscriptions_activation_code
    FOREIGN KEY (activation_code) REFERENCES activation_codes(code)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS subscription_records (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(128) NOT NULL,
  activation_code VARCHAR(64) NOT NULL,
  package_name VARCHAR(128) NOT NULL,
  device_name VARCHAR(255),
  activated_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  status ENUM('active', 'expired', 'cancelled') NOT NULL DEFAULT 'active',
  last_checked_at DATETIME NULL,
  notes TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_subscription_records_activation_code (activation_code),
  KEY idx_subscription_records_device_id (device_id),
  KEY idx_subscription_records_status (status),
  KEY idx_subscription_records_expires_at (expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS subscription_renewals (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  subscription_id BIGINT NOT NULL,
  renewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  previous_expires_at DATETIME NOT NULL,
  new_expires_at DATETIME NOT NULL,
  payment_method VARCHAR(50),
  payment_amount DECIMAL(10, 2),
  transaction_id VARCHAR(100),
  notes TEXT,
  KEY idx_subscription_renewals_subscription_id (subscription_id),
  KEY idx_subscription_renewals_renewed_at (renewed_at),
  CONSTRAINT fk_subscription_renewals_subscription
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  barcode VARCHAR(255),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  buying_price DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  category VARCHAR(128),
  selling_price DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  quantity INT NOT NULL DEFAULT 0,
  image_path TEXT,
  low_stock_threshold INT NOT NULL DEFAULT 5,
  shoe_sizes JSON NULL,
  size_type VARCHAR(32) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_products_business (business_id),
  KEY idx_products_barcode (barcode),
  KEY idx_products_category (category),
  KEY idx_products_low_stock (business_id, quantity),
  CONSTRAINT fk_products_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

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
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_suppliers_business (business_id),
  CONSTRAINT fk_suppliers_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sales (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  cashier_id VARCHAR(64) NOT NULL,
  cashier_name VARCHAR(255) NOT NULL,
  customer_name VARCHAR(255),
  customer_id BIGINT NULL,
  payment_method VARCHAR(128) NOT NULL,
  status VARCHAR(64) NOT NULL DEFAULT 'completed',
  subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  discount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  amount_paid DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  change_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  item_count INT NOT NULL DEFAULT 0,
  datetime DATETIME NOT NULL,
  notes TEXT,
  reference_code VARCHAR(255),
  image_path TEXT,
  cancelled_reason TEXT,
  cancelled_by VARCHAR(255),
  cancelled_at DATETIME NULL,
  transaction_type VARCHAR(32) NOT NULL DEFAULT 'pos',
  reservation_fee DECIMAL(12, 2) NULL,
  courier VARCHAR(255),
  delivery_status VARCHAR(64),
  loyalty_points_earned INT NOT NULL DEFAULT 0,
  loyalty_points_redeemed INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_sales_business (business_id),
  KEY idx_sales_business_datetime (business_id, datetime),
  KEY idx_sales_cashier (cashier_id),
  KEY idx_sales_customer (customer_id),
  KEY idx_sales_status (business_id, status),
  CONSTRAINT fk_sales_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_sales_cashier
    FOREIGN KEY (cashier_id) REFERENCES users(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sale_items (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  sale_id VARCHAR(64) NOT NULL,
  business_id VARCHAR(64) NOT NULL,
  product_id VARCHAR(64) NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(12, 2) NOT NULL,
  discount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  subtotal DECIMAL(12, 2) NOT NULL,
  shoe_size VARCHAR(32) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_sale_items_sale (sale_id),
  KEY idx_sale_items_business (business_id),
  KEY idx_sale_items_product (product_id),
  UNIQUE KEY uq_sale_items_sync (sale_id, product_id),
  CONSTRAINT fk_sale_items_sale
    FOREIGN KEY (sale_id) REFERENCES sales(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_sale_items_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS purchase_orders (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  supplier_id VARCHAR(64),
  order_number VARCHAR(255),
  order_date DATETIME NOT NULL,
  expected_delivery DATETIME,
  status VARCHAR(64) NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  notes TEXT,
  created_by VARCHAR(255),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_purchase_orders_business (business_id),
  KEY idx_purchase_orders_supplier (supplier_id),
  CONSTRAINT fk_purchase_orders_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_purchase_orders_supplier
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB;

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
  `timestamp` DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_inventory_movements_business (business_id),
  KEY idx_inventory_movements_product (product_id),
  KEY idx_inventory_movements_timestamp (business_id, `timestamp`),
  CONSTRAINT fk_inventory_movements_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

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
  status VARCHAR(64) DEFAULT 'pending',
  resolution_notes TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_damage_reports_business (business_id),
  KEY idx_damage_reports_product (product_id),
  KEY idx_damage_reports_status (business_id, status),
  CONSTRAINT fk_damage_reports_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_damage_reports_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cameras (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  name VARCHAR(255) NOT NULL,
  location TEXT,
  stream_url TEXT NOT NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'http',
  position INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  username VARCHAR(255),
  password VARCHAR(255),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_cameras_business (business_id),
  KEY idx_cameras_position (position),
  CONSTRAINT fk_cameras_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cctv_timestamps (
  id VARCHAR(64) PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  camera_id VARCHAR(64) NOT NULL,
  label VARCHAR(255) NOT NULL,
  description TEXT,
  `timestamp` DATETIME NOT NULL,
  notes TEXT,
  video_path TEXT,
  created_by VARCHAR(255),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_cctv_timestamps_business (business_id),
  KEY idx_cctv_timestamps_camera (camera_id),
  CONSTRAINT fk_cctv_timestamps_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_cctv_timestamps_camera
    FOREIGN KEY (camera_id) REFERENCES cameras(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customers (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  customer_code VARCHAR(64) NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(64),
  email VARCHAR(255),
  address TEXT,
  points_balance INT NOT NULL DEFAULT 0,
  lifetime_points INT NOT NULL DEFAULT 0,
  barcode_value VARCHAR(128) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_customers_business_code (business_id, customer_code),
  UNIQUE KEY uq_customers_business_barcode (business_id, barcode_value),
  KEY idx_customers_business (business_id),
  KEY idx_customers_full_name (full_name),
  KEY idx_customers_email (email),
  CONSTRAINT fk_customers_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

ALTER TABLE sales
  ADD CONSTRAINT fk_sales_customer
  FOREIGN KEY (customer_id) REFERENCES customers(id)
  ON DELETE SET NULL
  ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS loyalty_ledger (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  customer_id BIGINT NOT NULL,
  sale_id VARCHAR(64) NULL,
  entry_type ENUM('earn', 'redeem', 'adjust') NOT NULL,
  points INT NOT NULL,
  balance_after INT NOT NULL,
  notes TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_loyalty_ledger_business (business_id),
  KEY idx_loyalty_ledger_customer (customer_id),
  KEY idx_loyalty_ledger_sale (sale_id),
  KEY idx_loyalty_ledger_created_at (created_at),
  CONSTRAINT fk_loyalty_ledger_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_loyalty_ledger_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_loyalty_ledger_sale
    FOREIGN KEY (sale_id) REFERENCES sales(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_entries (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  time DATETIME NOT NULL,
  type VARCHAR(16) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_attendance_entries_business (business_id),
  KEY idx_attendance_entries_user (user_id),
  KEY idx_attendance_entries_time (business_id, time),
  CONSTRAINT fk_attendance_entries_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_leaves (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  date_key VARCHAR(16) NOT NULL,
  payload LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_attendance_leaves_business (business_id),
  KEY idx_attendance_leaves_user (user_id),
  KEY idx_attendance_leaves_date (business_id, date_key),
  CONSTRAINT fk_attendance_leaves_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_schedule (
  business_id VARCHAR(64) NOT NULL,
  `key` VARCHAR(64) NOT NULL,
  value LONGTEXT NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (business_id, `key`),
  CONSTRAINT fk_attendance_schedule_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_archive (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  date_key VARCHAR(16) NOT NULL,
  entries LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_attendance_archive_business (business_id),
  KEY idx_attendance_archive_user (user_id),
  UNIQUE KEY uq_attendance_archive_business_user_date (business_id, user_id, date_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS restock_records (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  product_id VARCHAR(64) NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  quantity INT NOT NULL,
  supplier_id VARCHAR(64) NULL,
  supplier_name VARCHAR(255),
  delivery_receipt_no VARCHAR(128),
  damage_quantity INT NOT NULL DEFAULT 0,
  damage_reason TEXT,
  notes TEXT,
  referenced_by VARCHAR(255) NOT NULL,
  restock_date DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_restock_records_business (business_id),
  KEY idx_restock_records_product (product_id),
  KEY idx_restock_records_supplier (supplier_id),
  KEY idx_restock_records_date (business_id, restock_date),
  CONSTRAINT fk_restock_records_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_restock_records_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT fk_restock_records_supplier
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS purchase_order_items (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  order_id VARCHAR(64) NOT NULL,
  product_id VARCHAR(64) NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(12, 2) NOT NULL,
  total_price DECIMAL(12, 2) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_purchase_order_items_business (business_id),
  KEY idx_purchase_order_items_order (order_id),
  KEY idx_purchase_order_items_product (product_id),
  KEY idx_purchase_order_items_sync (order_id, product_id),
  CONSTRAINT fk_purchase_order_items_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_purchase_order_items_order
    FOREIGN KEY (order_id) REFERENCES purchase_orders(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_purchase_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS activity_logs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  business_id VARCHAR(64) NOT NULL,
  type VARCHAR(128) NOT NULL,
  message TEXT NOT NULL,
  meta LONGTEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent TINYINT(1) NOT NULL DEFAULT 0,
  KEY idx_activity_logs_business (business_id),
  KEY idx_activity_logs_type (type),
  KEY idx_activity_logs_created_at (business_id, created_at),
  KEY idx_activity_logs_sent (sent),
  CONSTRAINT fk_activity_logs_business
    FOREIGN KEY (business_id) REFERENCES businesses(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;
