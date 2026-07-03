-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jun 30, 2026 at 05:59 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `smart_monitoring`
--

-- --------------------------------------------------------

--
-- Table structure for table `activation_codes`
--

CREATE TABLE `activation_codes` (
  `code` varchar(64) NOT NULL,
  `package_name` varchar(128) NOT NULL DEFAULT 'Standard',
  `status` enum('unused','used','revoked','assigned') NOT NULL DEFAULT 'unused',
  `device_id` varchar(128) DEFAULT NULL,
  `device_name` varchar(255) DEFAULT NULL,
  `assigned_at` datetime DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `email_sent_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `activation_codes`
--

INSERT INTO `activation_codes` (`code`, `package_name`, `status`, `device_id`, `device_name`, `assigned_at`, `notes`, `used_at`, `created_at`, `email_sent_at`, `expires_at`) VALUES
('129HE3EZQRQSZCXFNK4R', 'Standard', 'assigned', NULL, NULL, '2026-06-20 18:07:21', NULL, NULL, '2026-06-20 11:46:09', NULL, NULL),
('4WI273VOJLW6C1FDMKGH', 'Basic', 'unused', NULL, NULL, NULL, NULL, NULL, '2026-06-20 11:35:21', NULL, NULL),
('72EISNBL4TX4XVZFR3ZK', 'Basic', 'unused', NULL, NULL, NULL, NULL, NULL, '2026-06-22 13:56:36', NULL, NULL),
('78P6P64VLCFOP8YYTETS', 'Basic', 'unused', NULL, NULL, NULL, NULL, NULL, '2026-06-22 14:21:06', NULL, NULL),
('8YHB3RGF7VGRQNDPIQTE', 'Basic', 'used', 'A934F6B1DB6A11B2D9908075BCC0AFE4', 'RTW Orly', '2026-06-20 18:13:37', NULL, '2026-06-20 18:15:34', '2026-06-20 11:35:21', NULL, NULL),
('B6LXI5THA6TD7OI5VGWC', 'Basic', 'unused', NULL, NULL, NULL, NULL, NULL, '2026-06-22 13:36:05', NULL, NULL),
('D7E49K8X6EN0VD8WNWHI', 'Standard', 'assigned', NULL, NULL, '2026-06-20 11:46:34', NULL, NULL, '2026-06-20 11:46:09', NULL, NULL),
('DL1UUAIYPWOS6VXR93LN', 'Basic', 'unused', NULL, NULL, NULL, NULL, NULL, '2026-06-22 13:14:01', NULL, NULL),
('VTG142UN5WACEJ8GMJHW', 'Basic', 'unused', NULL, NULL, NULL, NULL, NULL, '2026-06-22 13:28:02', NULL, NULL),
('YXMYSS4RPOO7A2ZC9V70', 'Standard', 'used', 'A934F6B1DB6A11B2D9908075BCC0AFE4', 'RTW Orly Store', '2026-06-23 10:58:27', NULL, '2026-06-23 11:09:01', '2026-06-22 13:21:57', '2026-06-23 10:58:27', '2026-06-24 10:58:27');

-- --------------------------------------------------------

--
-- Table structure for table `activation_code_requests`
--

CREATE TABLE `activation_code_requests` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `business_name` varchar(255) NOT NULL,
  `package_name` varchar(128) NOT NULL,
  `package_price` varchar(64) NOT NULL,
  `request_type` enum('monthly','trial','trial_upgrade') NOT NULL,
  `contact_email` varchar(255) NOT NULL,
  `contact_phone` varchar(64) NOT NULL,
  `additional_notes` text DEFAULT NULL,
  `status` enum('pending','fulfilled','cancelled') NOT NULL DEFAULT 'pending',
  `activation_code` varchar(64) DEFAULT NULL,
  `requested_at` datetime NOT NULL,
  `fulfilled_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `activation_code_requests`
--

INSERT INTO `activation_code_requests` (`id`, `business_name`, `package_name`, `package_price`, `request_type`, `contact_email`, `contact_phone`, `additional_notes`, `status`, `activation_code`, `requested_at`, `fulfilled_at`, `created_at`, `updated_at`) VALUES
('8afe7eed-4b71-46ce-9c5a-6c77395d144e', 'RTW Orly', 'Basic', '₱1,999', 'monthly', 'rtworly.store@gmail.com', '+639604279947', 'Done', 'fulfilled', '8YHB3RGF7VGRQNDPIQTE', '2026-06-20 18:12:48', '2026-06-20 18:13:36', '2026-06-20 18:12:50', '2026-06-20 18:13:38'),
('8b9c8ff4-ce26-445a-929d-7eeda11c124c', 'RTW Orly Store', 'Standard', '₱3,999', 'monthly', 'rtworly.store@gmail.com', '+639687120740', 'Done Payment, requesting for codes. Thank you', 'fulfilled', 'YXMYSS4RPOO7A2ZC9V70', '2026-06-23 10:57:36', '2026-06-23 10:58:27', '2026-06-23 10:57:39', '2026-06-23 10:58:27'),
('a420bef4-ad82-4da3-b89b-86914beffed8', 'RTW Orly Store', 'Standard', '₱3,999', 'monthly', 'rtworly.store@gmail.com', '+369604279947', 'Done Payment po', 'fulfilled', 'D7E49K8X6EN0VD8WNWHI', '2026-06-20 11:43:23', '2026-06-20 11:46:33', '2026-06-20 11:43:25', '2026-06-20 11:46:35'),
('e0b166ab-7fe3-4aae-bd15-84e380a3d400', 'RTW Orly Store', 'Standard', '₱3,999', 'monthly', 'rtworly.store@gmail.com', '+639604279947', 'Done Payment, requesting for code', 'fulfilled', '129HE3EZQRQSZCXFNK4R', '2026-06-20 18:06:25', '2026-06-20 18:07:20', '2026-06-20 18:06:28', '2026-06-20 18:07:22');

-- --------------------------------------------------------

--
-- Table structure for table `activity_logs`
--

CREATE TABLE `activity_logs` (
  `id` bigint(20) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `type` varchar(128) NOT NULL,
  `message` text NOT NULL,
  `meta` longtext DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `sent` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_entries`
--

CREATE TABLE `attendance_entries` (
  `id` bigint(20) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `user_id` varchar(64) NOT NULL,
  `time` datetime NOT NULL,
  `type` varchar(16) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_leaves`
--

CREATE TABLE `attendance_leaves` (
  `id` bigint(20) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `user_id` varchar(64) NOT NULL,
  `date_key` varchar(16) NOT NULL,
  `payload` longtext NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_schedule`
--

CREATE TABLE `attendance_schedule` (
  `business_id` varchar(64) NOT NULL,
  `key` varchar(64) NOT NULL,
  `value` longtext NOT NULL,
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `attendance_schedule`
--

INSERT INTO `attendance_schedule` (`business_id`, `key`, `value`, `updated_at`) VALUES
('b-1782183323044-11znzx', 'global', '{\"start\":\"09:00\",\"end\":\"18:00\",\"requiredMinutes\":480,\"lunchMinutes\":60,\"snackMinutes\":15}', '2026-06-25 17:44:28');

-- --------------------------------------------------------

--
-- Table structure for table `businesses`
--

CREATE TABLE `businesses` (
  `id` varchar(64) NOT NULL,
  `name` varchar(255) NOT NULL,
  `owner_id` varchar(64) NOT NULL,
  `owner_email` varchar(255) NOT NULL,
  `contact_number` varchar(64) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `max_devices` int(11) NOT NULL DEFAULT 10,
  `subscription_package` varchar(64) DEFAULT NULL,
  `subscription_expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `businesses`
--

INSERT INTO `businesses` (`id`, `name`, `owner_id`, `owner_email`, `contact_number`, `address`, `created_at`, `updated_at`, `is_active`, `max_devices`, `subscription_package`, `subscription_expires_at`) VALUES
('b-1782183323044-11znzx', 'Florida Gubot', '102659419145450316584', 'rtworly.store@gmail.com', NULL, NULL, '2026-06-23 10:55:23', '2026-06-23 10:55:23', 1, 10, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `cameras`
--

CREATE TABLE `cameras` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `name` varchar(255) NOT NULL,
  `location` text DEFAULT NULL,
  `stream_url` text NOT NULL,
  `type` varchar(32) NOT NULL DEFAULT 'http',
  `position` int(11) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cctv_timestamps`
--

CREATE TABLE `cctv_timestamps` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `camera_id` varchar(64) NOT NULL,
  `label` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `timestamp` datetime NOT NULL,
  `notes` text DEFAULT NULL,
  `video_path` text DEFAULT NULL,
  `created_by` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `customers`
--

CREATE TABLE `customers` (
  `id` bigint(20) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `customer_code` varchar(64) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `phone_number` varchar(64) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `points_balance` int(11) NOT NULL DEFAULT 0,
  `lifetime_points` int(11) NOT NULL DEFAULT 0,
  `barcode_value` varchar(128) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `customers`
--

INSERT INTO `customers` (`id`, `business_id`, `customer_code`, `full_name`, `phone_number`, `email`, `address`, `points_balance`, `lifetime_points`, `barcode_value`, `created_at`, `updated_at`, `is_active`) VALUES
(1, 'b-1782183323044-11znzx', 'b26eeeeb-c471-4bbc-a62f-9f50655a1236', 'Joyce Balacano', NULL, 'jaybe.gubot@gmail.com', NULL, 11, 11, 'SMS-CUST-C3304C588D01', '2026-06-20 20:36:38', '2026-06-25 17:44:27', 1);

-- --------------------------------------------------------

--
-- Table structure for table `damage_reports`
--

CREATE TABLE `damage_reports` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `product_id` varchar(64) NOT NULL,
  `product_name` varchar(255) DEFAULT NULL,
  `quantity` int(11) NOT NULL,
  `damage_type` varchar(128) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `reported_by` varchar(255) DEFAULT NULL,
  `reported_at` datetime NOT NULL,
  `status` varchar(64) DEFAULT 'pending',
  `resolution_notes` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `developer_accounts`
--

CREATE TABLE `developer_accounts` (
  `id` varchar(32) NOT NULL,
  `display_name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) DEFAULT NULL,
  `auth_method` varchar(32) NOT NULL DEFAULT 'password',
  `google_sub` varchar(255) DEFAULT NULL,
  `avatar_url` text DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `developer_accounts`
--

INSERT INTO `developer_accounts` (`id`, `display_name`, `email`, `password_hash`, `auth_method`, `google_sub`, `avatar_url`, `is_active`, `created_at`, `updated_at`) VALUES
('primary', 'Jay-Be Gubot', 'jaybe.gubot01@gmail.com', '$2a$10$gMf2Hy2I3sAtewP0TIN.F.s0BEaQrKgE5lhRnZhBWf.W/QSBXmnZi', 'google', '118358434147987996271', 'https://lh3.googleusercontent.com/a/ACg8ocLzCErOdI7giazCb_Up6j9kFA6N9Fz2Yg39OGM0jf3iYPyk6g=s96-c', 1, '2026-06-22 22:57:41', '2026-06-25 17:38:02');

-- --------------------------------------------------------

--
-- Table structure for table `developer_notification_settings`
--

CREATE TABLE `developer_notification_settings` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `notification_email` varchar(255) NOT NULL,
  `webhook_url` text DEFAULT NULL,
  `email_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `webhook_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `email_otps`
--

CREATE TABLE `email_otps` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `email` varchar(255) NOT NULL,
  `otp` varchar(128) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `inventory_movements`
--

CREATE TABLE `inventory_movements` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `product_id` varchar(64) NOT NULL,
  `product_name` varchar(255) DEFAULT NULL,
  `movement_type` varchar(128) DEFAULT NULL,
  `quantity` int(11) NOT NULL,
  `reference` varchar(255) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `performed_by` varchar(255) DEFAULT NULL,
  `timestamp` datetime NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `inventory_movements`
--

INSERT INTO `inventory_movements` (`id`, `business_id`, `product_id`, `product_name`, `movement_type`, `quantity`, `reference`, `notes`, `performed_by`, `timestamp`, `created_at`) VALUES
('1', 'b-1782183323044-11znzx', '1', '', 'sale', -1, 'SAL1781959140739', 'Sold via POS', 'system', '2026-06-20 20:39:00', '2026-06-20 20:39:00'),
('2', 'b-1782183323044-11znzx', '4', '', 'sale', -1, 'SAL1781959302383', 'Sold via POS', 'system', '2026-06-20 20:41:42', '2026-06-20 20:41:42'),
('3', 'b-1782183323044-11znzx', '1', '', 'sale', -1, 'SAL1781959368229', 'Sold via POS', 'system', '2026-06-20 20:42:48', '2026-06-20 20:42:48'),
('4', 'b-1782183323044-11znzx', '1', '', 'sale', -2, 'SAL1782028460759', 'Sold via POS', 'system', '2026-06-21 15:54:20', '2026-06-21 15:54:20'),
('5', 'b-1782183323044-11znzx', '1', '', 'sale', -1, 'SAL1782186146268', 'Sold via POS', 'system', '2026-06-23 11:42:26', '2026-06-23 11:42:26'),
('6', 'b-1782183323044-11znzx', '5', '', 'sale', -1, 'SAL1782193138623', 'Sold via POS', 'system', '2026-06-23 13:38:58', '2026-06-23 13:38:58'),
('7', 'b-1782183323044-11znzx', '2', '', 'sale', -1, 'SAL1782193184588', 'Sold via POS', 'system', '2026-06-23 13:39:44', '2026-06-23 13:39:44'),
('8', 'b-1782183323044-11znzx', '8', '', 'sale', -1, 'SAL1782193505798', 'Sold via POS', 'system', '2026-06-23 13:45:05', '2026-06-23 13:45:05');

-- --------------------------------------------------------

--
-- Table structure for table `loyalty_ledger`
--

CREATE TABLE `loyalty_ledger` (
  `id` bigint(20) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `customer_id` bigint(20) NOT NULL,
  `sale_id` varchar(64) DEFAULT NULL,
  `entry_type` enum('earn','redeem','adjust') NOT NULL,
  `points` int(11) NOT NULL,
  `balance_after` int(11) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `barcode` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `category` varchar(128) DEFAULT NULL,
  `selling_price` decimal(12,2) NOT NULL DEFAULT 0.00,
  `quantity` int(11) NOT NULL DEFAULT 0,
  `image_path` text DEFAULT NULL,
  `low_stock_threshold` int(11) NOT NULL DEFAULT 5,
  `shoe_sizes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`shoe_sizes`)),
  `size_type` varchar(32) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`id`, `business_id`, `barcode`, `name`, `category`, `selling_price`, `quantity`, `image_path`, `low_stock_threshold`, `shoe_sizes`, `size_type`, `created_at`, `updated_at`) VALUES
('1', 'b-1782183323044-11znzx', 'ROS-0000000001', '3D Facemask - Black/White,etc', 'Facemask', 10.00, 5, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_f70d1572-31af-4a2f-9efe-16ebaeb891238887384576021056920.jpg', 2, NULL, NULL, '2026-06-20 20:15:36', '2026-06-25 17:44:28'),
('2', 'b-1782183323044-11znzx', 'ROS-0000000002', 'KF94 Facemask white and more', 'Facemask', 20.00, 10, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_18988dbe-c1d4-4d69-8dae-97eaeea9afc34779101651682831014.jpg', 2, NULL, NULL, '2026-06-20 20:17:14', '2026-06-25 17:44:28'),
('3', 'b-1782183323044-11znzx', 'ROS-0000000003', 'KN95 5D FACEMASK WHITE AND MANY MORE', 'Facemask', 40.00, 20, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_ee6b03d7-a686-4170-9a58-268790d5e4724512873585787997391.jpg', 5, NULL, NULL, '2026-06-20 20:21:27', '2026-06-25 17:44:28'),
('4', 'b-1782183323044-11znzx', 'ROS-0000000004', 'KN95 3D PRO FACEMASK WHITE AND MANY MORE', 'Facemask', 25.00, 19, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_1827c523-27ea-4af7-97be-ef64bf553f4a7990922296382313234.jpg', 5, NULL, NULL, '2026-06-20 20:23:46', '2026-06-25 17:44:28'),
('5', 'b-1782183323044-11znzx', 'ROS-0000000005', 'SUN GLASS STANDARD', 'SALAMIN - SUNGLASS', 55.00, 99, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_9b3fd5b5-afd5-4f60-842b-9a1681e4b3694248718778885012601.jpg', 50, NULL, NULL, '2026-06-23 13:17:02', '2026-06-25 17:44:28'),
('6', 'b-1782183323044-11znzx', 'ROS-0000000006', 'SUN GLASS PREMIUM', 'SUN GLASS', 50.00, 70, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_169d149c-db06-46e9-86ce-b345041fb2e05890785539647890908.jpg', 50, NULL, NULL, '2026-06-23 13:21:10', '2026-06-25 17:44:28'),
('7', 'b-1782183323044-11znzx', 'ROS-0000000007', 'JERSEY SHORT', 'SHORTS', 150.00, 12, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_2394995f-abf9-40a2-b245-0f9b7bc490fb8489958727067448786.jpg', 8, NULL, NULL, '2026-06-23 13:28:18', '2026-06-25 17:44:28'),
('8', 'b-1782183323044-11znzx', 'ROS-0000000008', 'SUMMER SHORTS', 'SHORTS', 100.00, 15, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_8d1bca1c-9aab-4b02-8a30-375c4265f7d2270579205717788637.jpg', 8, NULL, NULL, '2026-06-23 13:31:42', '2026-06-25 17:44:28'),
('9', 'b-1782183323044-11znzx', 'ROS-0000000009', 'RANDOM SHORT', 'SHORTS', 100.00, 10, '/data/user/0/com.pinkoradev.smart_monitoring_system/cache/scaled_5910992d-88c4-40f5-8a08-b145878df5991765289962896749832.jpg', 5, NULL, NULL, '2026-06-23 13:34:45', '2026-06-25 17:44:28');

-- --------------------------------------------------------

--
-- Table structure for table `purchase_orders`
--

CREATE TABLE `purchase_orders` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `supplier_id` varchar(64) DEFAULT NULL,
  `order_number` varchar(255) DEFAULT NULL,
  `order_date` datetime NOT NULL,
  `expected_delivery` datetime DEFAULT NULL,
  `status` varchar(64) NOT NULL DEFAULT 'pending',
  `total_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `notes` text DEFAULT NULL,
  `created_by` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `purchase_order_items`
--

CREATE TABLE `purchase_order_items` (
  `id` bigint(20) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `order_id` varchar(64) NOT NULL,
  `product_id` varchar(64) NOT NULL,
  `product_name` varchar(255) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(12,2) NOT NULL,
  `total_price` decimal(12,2) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `restock_records`
--

CREATE TABLE `restock_records` (
  `id` bigint(20) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `product_id` varchar(64) NOT NULL,
  `product_name` varchar(255) NOT NULL,
  `quantity` int(11) NOT NULL,
  `supplier_id` varchar(64) DEFAULT NULL,
  `supplier_name` varchar(255) DEFAULT NULL,
  `delivery_receipt_no` varchar(128) DEFAULT NULL,
  `damage_quantity` int(11) NOT NULL DEFAULT 0,
  `damage_reason` text DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `referenced_by` varchar(255) NOT NULL,
  `restock_date` datetime NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sales`
--

CREATE TABLE `sales` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `cashier_id` varchar(64) NOT NULL,
  `cashier_name` varchar(255) NOT NULL,
  `customer_name` varchar(255) DEFAULT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `payment_method` varchar(128) NOT NULL,
  `status` varchar(64) NOT NULL DEFAULT 'completed',
  `subtotal` decimal(12,2) NOT NULL DEFAULT 0.00,
  `discount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `total_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `amount_paid` decimal(12,2) NOT NULL DEFAULT 0.00,
  `change_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `item_count` int(11) NOT NULL DEFAULT 0,
  `datetime` datetime NOT NULL,
  `notes` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sales`
--

INSERT INTO `sales` (`id`, `business_id`, `cashier_id`, `cashier_name`, `customer_name`, `customer_id`, `payment_method`, `status`, `subtotal`, `discount`, `total_amount`, `amount_paid`, `change_amount`, `item_count`, `datetime`, `notes`, `created_at`) VALUES
('EWT1782194832992', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'Cash-In', 'completed', 30.00, 0.00, 30.00, 30.00, 0.00, 1, '2026-06-23 14:07:12', 'Transfer: ₱2000.00 | Fee: ₱30.00 | Ref: 49645452222', '2026-06-23 14:07:12'),
('S0', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 100.00, 0.00, 100.00, 100.00, 0.00, 1, '2026-06-23 13:45:05', NULL, '2026-06-23 11:42:26'),
('SAL1781959140739', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 10.00, 0.00, 10.00, 10.00, 0.00, 1, '2026-06-20 20:39:00', NULL, '2026-06-20 20:39:00'),
('SAL1781959302383', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 25.00, 0.00, 25.00, 25.00, 0.00, 1, '2026-06-20 20:41:42', NULL, '2026-06-20 20:41:42'),
('SAL1781959368229', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 10.00, 0.00, 10.00, 10.00, 0.00, 1, '2026-06-20 20:42:48', NULL, '2026-06-20 20:42:48'),
('SAL1782028460759', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 20.00, 0.00, 20.00, 20.00, 0.00, 2, '2026-06-21 15:54:20', NULL, '2026-06-21 15:54:20'),
('SAL1782186146268', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 10.00, 0.00, 10.00, 10.00, 0.00, 1, '2026-06-23 11:42:26', NULL, '2026-06-23 11:42:26'),
('SAL1782193138623', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 55.00, 0.00, 55.00, 55.00, 0.00, 1, '2026-06-23 13:38:58', NULL, '2026-06-23 13:38:58'),
('SAL1782193184588', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 20.00, 0.00, 20.00, 20.00, 0.00, 1, '2026-06-23 13:39:44', NULL, '2026-06-23 13:39:44'),
('SAL1782193505798', 'b-1782183323044-11znzx', '102659419145450316584', 'Florida Gubot', NULL, NULL, 'cash', 'completed', 100.00, 0.00, 100.00, 100.00, 0.00, 1, '2026-06-23 13:45:05', NULL, '2026-06-23 13:45:05');

-- --------------------------------------------------------

--
-- Table structure for table `sale_items`
--

CREATE TABLE `sale_items` (
  `id` bigint(20) NOT NULL,
  `sale_id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `product_id` varchar(64) NOT NULL,
  `product_name` varchar(255) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(12,2) NOT NULL,
  `discount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `subtotal` decimal(12,2) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sale_items`
--

INSERT INTO `sale_items` (`id`, `sale_id`, `business_id`, `product_id`, `product_name`, `quantity`, `unit_price`, `discount`, `subtotal`, `created_at`) VALUES
(5763, 'SAL1782186146268', 'b-1782183323044-11znzx', '1', '3D Facemask - Black/White,etc', 1, 10.00, 0.00, 10.00, '2026-06-23 11:43:34'),
(5764, 'SAL1782028460759', 'b-1782183323044-11znzx', '1', '3D Facemask - Black/White,etc', 2, 10.00, 0.00, 20.00, '2026-06-23 11:43:34'),
(5765, 'SAL1781959368229', 'b-1782183323044-11znzx', '1', '3D Facemask - Black/White,etc', 1, 10.00, 0.00, 10.00, '2026-06-23 11:43:34'),
(5766, 'SAL1781959302383', 'b-1782183323044-11znzx', '4', 'KN95 3D PRO FACEMASK WHITE AND MANY MORE', 1, 25.00, 0.00, 25.00, '2026-06-23 11:43:34'),
(5767, 'SAL1781959140739', 'b-1782183323044-11znzx', '1', '3D Facemask - Black/White,etc', 1, 10.00, 0.00, 10.00, '2026-06-23 11:43:34'),
(5769, 'S0', 'b-1782183323044-11znzx', '1', '3D Facemask - Black/White,etc', 1, 10.00, 0.00, 10.00, '2026-06-23 11:44:05'),
(6428, 'EWT1782194832992', 'b-1782183323044-11znzx', '0', 'Transfer Fee (Cash-In)', 1, 30.00, 0.00, 30.00, '2026-06-24 00:39:07'),
(6429, 'SAL1782193505798', 'b-1782183323044-11znzx', '8', 'SUMMER SHORTS', 1, 100.00, 0.00, 100.00, '2026-06-24 00:39:07'),
(6430, 'SAL1782193184588', 'b-1782183323044-11znzx', '2', 'KF94 Facemask white and more', 1, 20.00, 0.00, 20.00, '2026-06-24 00:39:07'),
(6431, 'SAL1782193138623', 'b-1782183323044-11znzx', '5', 'SUN GLASS STANDARD', 1, 55.00, 0.00, 55.00, '2026-06-24 00:39:07'),
(6440, 'S0', 'b-1782183323044-11znzx', '8', 'SUMMER SHORTS', 1, 100.00, 0.00, 100.00, '2026-06-24 00:39:35');

-- --------------------------------------------------------

--
-- Table structure for table `subscriptions`
--

CREATE TABLE `subscriptions` (
  `id` bigint(20) NOT NULL,
  `device_id` varchar(128) NOT NULL,
  `activation_code` varchar(64) NOT NULL,
  `package_name` varchar(128) NOT NULL,
  `device_name` varchar(255) NOT NULL,
  `activated_at` datetime NOT NULL,
  `expires_at` datetime NOT NULL,
  `status` enum('active','expired','cancelled') NOT NULL DEFAULT 'active',
  `last_checked_at` datetime DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `subscriptions`
--

INSERT INTO `subscriptions` (`id`, `device_id`, `activation_code`, `package_name`, `device_name`, `activated_at`, `expires_at`, `status`, `last_checked_at`, `notes`, `created_at`) VALUES
(2, 'A934F6B1DB6A11B2D9908075BCC0AFE4', 'YXMYSS4RPOO7A2ZC9V70', 'Standard', 'RTW Orly Store', '2026-06-23 11:09:01', '2026-07-23 03:09:01', 'active', NULL, NULL, '2026-06-23 11:09:01');

-- --------------------------------------------------------

--
-- Table structure for table `subscription_records`
--

CREATE TABLE `subscription_records` (
  `id` bigint(20) NOT NULL,
  `device_id` varchar(128) NOT NULL,
  `activation_code` varchar(64) NOT NULL,
  `package_name` varchar(128) NOT NULL,
  `device_name` varchar(255) DEFAULT NULL,
  `activated_at` datetime NOT NULL,
  `expires_at` datetime NOT NULL,
  `status` enum('active','expired','cancelled') NOT NULL DEFAULT 'active',
  `last_checked_at` datetime DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `subscription_renewals`
--

CREATE TABLE `subscription_renewals` (
  `id` bigint(20) NOT NULL,
  `subscription_id` bigint(20) NOT NULL,
  `renewed_at` datetime NOT NULL DEFAULT current_timestamp(),
  `previous_expires_at` datetime NOT NULL,
  `new_expires_at` datetime NOT NULL,
  `payment_method` varchar(50) DEFAULT NULL,
  `payment_amount` decimal(10,2) DEFAULT NULL,
  `transaction_id` varchar(100) DEFAULT NULL,
  `notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `suppliers`
--

CREATE TABLE `suppliers` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) NOT NULL,
  `name` varchar(255) NOT NULL,
  `contact_person` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(128) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` varchar(64) NOT NULL,
  `business_id` varchar(64) DEFAULT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` varchar(64) NOT NULL DEFAULT 'owner',
  `full_name` varchar(255) NOT NULL,
  `contact_number` varchar(64) DEFAULT NULL,
  `auth_method` varchar(32) NOT NULL DEFAULT 'password',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `last_login_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `business_id`, `email`, `password_hash`, `role`, `full_name`, `contact_number`, `auth_method`, `is_active`, `last_login_at`, `created_at`, `updated_at`) VALUES
('102659419145450316584', 'b-1782183323044-11znzx', 'rtworly.store@gmail.com', '$2a$10$pjV2AERDl2rzxj8HOYciXOKYvP5lStyAC2KFJqL9Rr.CM0q9Tf2LW', 'owner', 'Florida Gubot', '2708', 'google', 1, NULL, '2026-06-23 10:55:22', '2026-06-25 17:44:28');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `activation_codes`
--
ALTER TABLE `activation_codes`
  ADD PRIMARY KEY (`code`),
  ADD KEY `idx_activation_codes_status` (`status`),
  ADD KEY `idx_activation_codes_device_id` (`device_id`),
  ADD KEY `idx_activation_codes_package_name` (`package_name`),
  ADD KEY `idx_activation_codes_available` (`package_name`,`status`,`created_at`);

--
-- Indexes for table `activation_code_requests`
--
ALTER TABLE `activation_code_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_activation_requests_status` (`status`),
  ADD KEY `idx_activation_requests_email` (`contact_email`),
  ADD KEY `idx_activation_requests_code` (`activation_code`),
  ADD KEY `idx_activation_requests_requested_at` (`requested_at`),
  ADD KEY `idx_activation_requests_status_requested_at` (`status`,`requested_at`);

--
-- Indexes for table `activity_logs`
--
ALTER TABLE `activity_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_activity_logs_business` (`business_id`),
  ADD KEY `idx_activity_logs_type` (`type`),
  ADD KEY `idx_activity_logs_created_at` (`business_id`,`created_at`),
  ADD KEY `idx_activity_logs_sent` (`sent`);

--
-- Indexes for table `attendance_entries`
--
ALTER TABLE `attendance_entries`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_attendance_entries_business` (`business_id`),
  ADD KEY `idx_attendance_entries_user` (`user_id`),
  ADD KEY `idx_attendance_entries_time` (`business_id`,`time`);

--
-- Indexes for table `attendance_leaves`
--
ALTER TABLE `attendance_leaves`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_attendance_leaves_business` (`business_id`),
  ADD KEY `idx_attendance_leaves_user` (`user_id`),
  ADD KEY `idx_attendance_leaves_date` (`business_id`,`date_key`);

--
-- Indexes for table `attendance_schedule`
--
ALTER TABLE `attendance_schedule`
  ADD PRIMARY KEY (`business_id`,`key`);

--
-- Indexes for table `businesses`
--
ALTER TABLE `businesses`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_businesses_owner_email` (`owner_email`),
  ADD KEY `idx_businesses_owner_id` (`owner_id`),
  ADD KEY `idx_businesses_is_active` (`is_active`);

--
-- Indexes for table `cameras`
--
ALTER TABLE `cameras`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_cameras_business` (`business_id`),
  ADD KEY `idx_cameras_position` (`position`);

--
-- Indexes for table `cctv_timestamps`
--
ALTER TABLE `cctv_timestamps`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_cctv_timestamps_business` (`business_id`),
  ADD KEY `idx_cctv_timestamps_camera` (`camera_id`);

--
-- Indexes for table `customers`
--
ALTER TABLE `customers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_customers_business_code` (`business_id`,`customer_code`),
  ADD UNIQUE KEY `uq_customers_business_barcode` (`business_id`,`barcode_value`),
  ADD KEY `idx_customers_business` (`business_id`),
  ADD KEY `idx_customers_full_name` (`full_name`),
  ADD KEY `idx_customers_email` (`email`);

--
-- Indexes for table `damage_reports`
--
ALTER TABLE `damage_reports`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_damage_reports_business` (`business_id`),
  ADD KEY `idx_damage_reports_product` (`product_id`),
  ADD KEY `idx_damage_reports_status` (`business_id`,`status`);

--
-- Indexes for table `developer_accounts`
--
ALTER TABLE `developer_accounts`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `developer_notification_settings`
--
ALTER TABLE `developer_notification_settings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `email_otps`
--
ALTER TABLE `email_otps`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_email_otps_email` (`email`),
  ADD KEY `idx_email_otps_expires_at` (`expires_at`),
  ADD KEY `idx_email_otps_lookup` (`email`,`otp`,`used`,`expires_at`);

--
-- Indexes for table `inventory_movements`
--
ALTER TABLE `inventory_movements`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_inventory_movements_business` (`business_id`),
  ADD KEY `idx_inventory_movements_product` (`product_id`),
  ADD KEY `idx_inventory_movements_timestamp` (`business_id`,`timestamp`);

--
-- Indexes for table `loyalty_ledger`
--
ALTER TABLE `loyalty_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_loyalty_ledger_business` (`business_id`),
  ADD KEY `idx_loyalty_ledger_customer` (`customer_id`),
  ADD KEY `idx_loyalty_ledger_sale` (`sale_id`),
  ADD KEY `idx_loyalty_ledger_created_at` (`created_at`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_products_business` (`business_id`),
  ADD KEY `idx_products_barcode` (`barcode`),
  ADD KEY `idx_products_category` (`category`),
  ADD KEY `idx_products_low_stock` (`business_id`,`quantity`);

--
-- Indexes for table `purchase_orders`
--
ALTER TABLE `purchase_orders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_purchase_orders_business` (`business_id`),
  ADD KEY `idx_purchase_orders_supplier` (`supplier_id`);

--
-- Indexes for table `purchase_order_items`
--
ALTER TABLE `purchase_order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_purchase_order_items_business` (`business_id`),
  ADD KEY `idx_purchase_order_items_order` (`order_id`),
  ADD KEY `idx_purchase_order_items_product` (`product_id`),
  ADD KEY `idx_purchase_order_items_sync` (`order_id`,`product_id`);

--
-- Indexes for table `restock_records`
--
ALTER TABLE `restock_records`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_restock_records_business` (`business_id`),
  ADD KEY `idx_restock_records_product` (`product_id`),
  ADD KEY `idx_restock_records_supplier` (`supplier_id`),
  ADD KEY `idx_restock_records_date` (`business_id`,`restock_date`);

--
-- Indexes for table `sales`
--
ALTER TABLE `sales`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_sales_business` (`business_id`),
  ADD KEY `idx_sales_business_datetime` (`business_id`,`datetime`),
  ADD KEY `idx_sales_cashier` (`cashier_id`),
  ADD KEY `idx_sales_customer` (`customer_id`),
  ADD KEY `idx_sales_status` (`business_id`,`status`);

--
-- Indexes for table `sale_items`
--
ALTER TABLE `sale_items`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_sale_items_sync` (`sale_id`,`product_id`),
  ADD KEY `idx_sale_items_sale` (`sale_id`),
  ADD KEY `idx_sale_items_business` (`business_id`),
  ADD KEY `idx_sale_items_product` (`product_id`);

--
-- Indexes for table `subscriptions`
--
ALTER TABLE `subscriptions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_subscriptions_activation_code` (`activation_code`),
  ADD KEY `idx_subscriptions_device_id` (`device_id`),
  ADD KEY `idx_subscriptions_status` (`status`),
  ADD KEY `idx_subscriptions_expires_at` (`expires_at`);

--
-- Indexes for table `subscription_records`
--
ALTER TABLE `subscription_records`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_subscription_records_activation_code` (`activation_code`),
  ADD KEY `idx_subscription_records_device_id` (`device_id`),
  ADD KEY `idx_subscription_records_status` (`status`),
  ADD KEY `idx_subscription_records_expires_at` (`expires_at`);

--
-- Indexes for table `subscription_renewals`
--
ALTER TABLE `subscription_renewals`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_subscription_renewals_subscription_id` (`subscription_id`),
  ADD KEY `idx_subscription_renewals_renewed_at` (`renewed_at`);

--
-- Indexes for table `suppliers`
--
ALTER TABLE `suppliers`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_suppliers_business` (`business_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_users_business_email` (`business_id`,`email`),
  ADD KEY `idx_users_business` (`business_id`),
  ADD KEY `idx_users_business_role` (`business_id`,`role`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `activity_logs`
--
ALTER TABLE `activity_logs`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendance_entries`
--
ALTER TABLE `attendance_entries`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendance_leaves`
--
ALTER TABLE `attendance_leaves`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `customers`
--
ALTER TABLE `customers`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `loyalty_ledger`
--
ALTER TABLE `loyalty_ledger`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `purchase_order_items`
--
ALTER TABLE `purchase_order_items`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `restock_records`
--
ALTER TABLE `restock_records`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sale_items`
--
ALTER TABLE `sale_items`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8108;

--
-- AUTO_INCREMENT for table `subscriptions`
--
ALTER TABLE `subscriptions`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `subscription_records`
--
ALTER TABLE `subscription_records`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `subscription_renewals`
--
ALTER TABLE `subscription_renewals`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `activation_code_requests`
--
ALTER TABLE `activation_code_requests`
  ADD CONSTRAINT `fk_activation_requests_code` FOREIGN KEY (`activation_code`) REFERENCES `activation_codes` (`code`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `activity_logs`
--
ALTER TABLE `activity_logs`
  ADD CONSTRAINT `fk_activity_logs_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `attendance_entries`
--
ALTER TABLE `attendance_entries`
  ADD CONSTRAINT `fk_attendance_entries_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `attendance_leaves`
--
ALTER TABLE `attendance_leaves`
  ADD CONSTRAINT `fk_attendance_leaves_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `attendance_schedule`
--
ALTER TABLE `attendance_schedule`
  ADD CONSTRAINT `fk_attendance_schedule_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `cameras`
--
ALTER TABLE `cameras`
  ADD CONSTRAINT `fk_cameras_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `cctv_timestamps`
--
ALTER TABLE `cctv_timestamps`
  ADD CONSTRAINT `fk_cctv_timestamps_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_cctv_timestamps_camera` FOREIGN KEY (`camera_id`) REFERENCES `cameras` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `customers`
--
ALTER TABLE `customers`
  ADD CONSTRAINT `fk_customers_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `damage_reports`
--
ALTER TABLE `damage_reports`
  ADD CONSTRAINT `fk_damage_reports_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_damage_reports_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `inventory_movements`
--
ALTER TABLE `inventory_movements`
  ADD CONSTRAINT `fk_inventory_movements_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `loyalty_ledger`
--
ALTER TABLE `loyalty_ledger`
  ADD CONSTRAINT `fk_loyalty_ledger_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_loyalty_ledger_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_loyalty_ledger_sale` FOREIGN KEY (`sale_id`) REFERENCES `sales` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `products`
--
ALTER TABLE `products`
  ADD CONSTRAINT `fk_products_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `purchase_orders`
--
ALTER TABLE `purchase_orders`
  ADD CONSTRAINT `fk_purchase_orders_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_purchase_orders_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `purchase_order_items`
--
ALTER TABLE `purchase_order_items`
  ADD CONSTRAINT `fk_purchase_order_items_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_purchase_order_items_order` FOREIGN KEY (`order_id`) REFERENCES `purchase_orders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_purchase_order_items_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `restock_records`
--
ALTER TABLE `restock_records`
  ADD CONSTRAINT `fk_restock_records_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_restock_records_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_restock_records_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `sales`
--
ALTER TABLE `sales`
  ADD CONSTRAINT `fk_sales_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_sales_cashier` FOREIGN KEY (`cashier_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_sales_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `sale_items`
--
ALTER TABLE `sale_items`
  ADD CONSTRAINT `fk_sale_items_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_sale_items_sale` FOREIGN KEY (`sale_id`) REFERENCES `sales` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `subscriptions`
--
ALTER TABLE `subscriptions`
  ADD CONSTRAINT `fk_subscriptions_activation_code` FOREIGN KEY (`activation_code`) REFERENCES `activation_codes` (`code`) ON UPDATE CASCADE;

--
-- Constraints for table `subscription_renewals`
--
ALTER TABLE `subscription_renewals`
  ADD CONSTRAINT `fk_subscription_renewals_subscription` FOREIGN KEY (`subscription_id`) REFERENCES `subscriptions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `suppliers`
--
ALTER TABLE `suppliers`
  ADD CONSTRAINT `fk_suppliers_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `fk_users_business` FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
