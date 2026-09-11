import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../models/chat_message.dart';
import '../models/sale.dart';
import '../services/pos_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/locale_controller.dart';

/// Service to handle AI help assistant interactions
class AIHelpService extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isThinking = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isThinking => _isThinking;

  // Bilingual knowledge base - English
  final Map<String, String> _knowledgeBaseEn = {
    // General System
    'what is this system':
        'This is a Smart Store Monitoring System - a comprehensive POS (Point of Sale) and inventory management solution with CCTV monitoring capabilities. It supports three user roles: Admin, Owner, and Cashier, each with specific permissions and features.',
    'what can this system do':
        'The system can: 1) Process sales transactions at POS, 2) Manage inventory and products, 3) Track damage reports, 4) Monitor CCTV feeds, 5) Generate sales reports and analytics, 6) Manage users and permissions, 7) Handle multi-method authentication.',
    'user roles':
        'There are three user roles:\n• Admin - Full system access, manages users, products, and settings\n• Owner - Views reports, monitors CCTV, manages inventory, can access POS\n• Cashier - Primarily operates POS terminal for customer transactions',

    // Admin Features
    'admin features':
        'Admin can: 1) Manage user accounts (create/edit/deactivate owners and cashiers), 2) Manage products (add/edit/delete/restock), 3) View comprehensive reports (sales, inventory, damage), 4) Configure system settings, 5) Export data to CSV/PDF, 6) Manage admin account details.',
    'how to add user':
        'To add a user (Admin only): 1) Go to Admin Dashboard, 2) Click "Manage Users", 3) Click the "+" icon in top-right, 4) Fill in name, email, password, pin, and select role (Owner/Cashier), 5) Click Save. The new user can then login with their credentials.',
    'how to add product':
        'To add a product (Admin only): 1) Go to Admin Dashboard, 2) Click "Manage Products", 3) Click "Add Product" button, 4) Enter product name, barcode, category, buying price, selling price, quantity, and reorder level, 5) Optionally add product image, 6) Click Save.',
    'admin reports':
        'Admin can view 4 types of reports: 1) Sales Reports - transaction history and totals, 2) Product Reports - inventory levels and movements, 3) User Activity - user actions and timestamps, 4) Damage Reports - damaged items with value calculations. All reports can be exported to CSV or PDF.',

    // Owner Features
    'owner features':
        'Owner can: 1) View detailed sales reports and analytics, 2) Monitor CCTV feeds in real-time, 3) Check and manage inventory, 4) Report damaged items, 5) Access POS terminal if needed, 6) View sales charts and trends.',
    'sales reports':
        'Sales reports show: Daily summaries with total sales, transaction count, and average transaction value. You can select date ranges, view individual transaction details, and export reports. Access from Owner Dashboard → "View Sales Reports".',
    'cctv monitoring':
        'CCTV monitoring allows real-time video feed viewing. Access from Owner Dashboard → "Monitor CCTV". Configure camera URLs in settings. Supports RTSP/HTTP streams or local video files.',
    'inventory management':
        'Inventory screen shows all products with: current stock levels, low stock warnings (≤5 items), product details, and damage reports. You can search by name/barcode, update stock, and view movement history.',

    // Cashier Features
    'cashier features':
        'Cashier can: 1) Process customer transactions at POS, 2) Add items to cart by scanning barcode or manual selection, 3) Search products using search bar, 4) Apply discounts, 5) Complete sales and generate receipts, 6) Handle multiple payment methods, 7) View sales log history, 8) Access CCTV footage with owner password verification.',
    'how to use pos':
        'To process a sale: 1) Open POS from Cashier Dashboard, 2) Use search bar to quickly find products or tap product tiles, 3) Scan barcodes for faster checkout, 4) Long-press product images to view enlarged version, 5) Adjust quantities with +/- buttons, 6) Apply discounts if needed, 7) Review cart total, 8) Click "Checkout" to complete sale. Receipt is generated automatically.',
    'pos checkout':
        'During checkout: System validates stock availability, reduces product quantities, records the sale with timestamp and cashier name, generates sale number, and clears the cart. Low stock warnings appear if items fall below reorder level.',
    'pos search':
        'The POS screen has a search bar at the top. Type product name or barcode to filter products in real-time. Search works with category filters - you can search within a selected category or across all products. Clear button appears when searching.',
    'cctv from sales log':
        'Cashiers can view CCTV footage from sales log, but it requires owner password verification. In the sales log, click the camera icon next to any sale. A dialog will appear asking for owner password. Only active owner accounts can authorize access.',
    'view product images':
        'Product images are displayed as 80x80 thumbnails on POS tiles. To see a larger view: Long-press any product tile with an image. An enlarged, zoomable view appears in a dialog. Use pinch/scroll to zoom 0.5x to 4x. Interactive viewer allows panning and zooming.',

    // Authentication
    'how to login':
        'Login options: 1) Admin - login with email/Gmail OR contact number + password, 2) Owner/Cashier - login with email + password. Password visibility can be toggled using the eye icon. First-time admins can create account using "Create Admin Account" button.',
    'forgot password':
        'For admin password reset: Click "Forgot Password?" → Enter admin email → Verify OTP sent to email → Enter phone number → Verify SMS code → Set new password. This multi-step verification ensures security.',
    'create admin account':
        'To create admin account: 1) Click "Create Admin Account" on login screen, 2) Enter name, email, contact number, and password, 3) System validates email format and phone number (must start with +63), 4) Click "Create Account". You can then login with these credentials.',
    'show password':
        'On the login screen, you can toggle password visibility by clicking the eye icon at the right of the password field. Click the eye to show password text, click again to hide it. This helps verify you typed correctly.',

    // Damage Reports
    'damage reports':
        'Damage reports track inventory losses. To report damage: 1) Go to Inventory → Damage Reports tab, 2) Click "Report Damage", 3) Select product, enter quantity damaged and reason, 4) Submit. Reports show total items damaged, total value lost, and can be exported.',
    'how to report damage':
        'From Inventory screen: 1) Go to "Damage Reports" tab, 2) Click "Report Damage" button, 3) Select the damaged product from dropdown, 4) Enter quantity damaged, 5) Select or enter damage reason (Expired, Broken, Contaminated, etc.), 6) Click Submit. The report is timestamped with your name.',

    // Settings & Theme
    'change theme':
        'To change theme: 1) Click Settings icon (gear) in app bar, 2) Scroll to "Theme" section, 3) Select from honeycomb color picker (9 preset colors), OR click "+" to choose custom color from 24 options. Theme applies system-wide instantly.',
    'change language':
        'To change language: 1) Open Settings, 2) Under "Language" section, select English (EN) or Filipino (FIL) from dropdown. Language changes apply immediately to all screens including this AI assistant.',
    'reduce motion':
        'Reduce Motion is an accessibility feature that minimizes animations. Enable it in Settings → toggle "Reduce Motion" switch. When enabled: Login screen background stops moving, splash screen navigates immediately, and other animations are minimized.',
    'settings':
        'Settings include: 1) Language selection (English/Filipino), 2) Theme customization with honeycomb picker and custom colors, 3) Reduce Motion toggle for accessibility. Access settings via gear icon in app bar.',

    // Product Management
    'low stock':
        'Low stock warnings appear when product quantity ≤ 5 items. Products are highlighted in red on inventory screen. Reorder level can be customized per product. Admin sees low stock count badge in Manage Products.',
    'restock product':
        'To restock (Admin only): 1) Go to Manage Products, 2) Click product to edit, 3) Update quantity field to new stock level, 4) Click Save. The system records inventory movement with timestamp.',
    'product barcode':
        'Products can have barcodes for quick scanning. When adding/editing products, enter barcode manually or scan using device camera. At POS, cashiers can scan barcodes to add items to cart instantly.',

    // System Navigation
    'dashboard navigation':
        'Each role has a dedicated dashboard:\n• Admin Dashboard - Manage users, products, reports, settings\n• Owner Dashboard - Sales reports, CCTV, inventory, POS access, backup & restore\n• Cashier Dashboard - POS terminal access\nUse menu cards to navigate to different features.',
    'logout':
        'To logout: Click the logout icon (arrow with door) in the top-right corner of any dashboard. You\'ll return to the login screen. Your session data is cleared for security.',

    // Backup & Restore
    'backup':
        'Backup & Restore protects your data. Access from Owner Dashboard → "Backup & Restore". Features: 1) Create manual backups, 2) Restore from previous backups, 3) Export database to external location, 4) Import database from external file. Backups include all products, sales, users, and inventory data.',
    'restore':
        'To restore a backup (Owner only): 1) Go to Backup & Restore screen, 2) View list of available backups with timestamps, 3) Click "Restore" button on desired backup, 4) Confirm restoration warning (current data will be replaced), 5) System restores data, 6) Restart app to see restored data. CAUTION: Restoration overwrites current database.',
    'backup restore':
        'Backup & Restore protects your data. Access from Owner Dashboard → "Backup & Restore". Features: 1) Create manual backups, 2) Restore from previous backups, 3) Export database to external location, 4) Import database from external file. Backups include all products, sales, users, and inventory data.',
    'how to backup':
        'To create a backup (Owner only): 1) Go to Owner Dashboard, 2) Click "Backup & Restore", 3) Click "Create Backup" button at the top, 4) System creates timestamped backup automatically, 5) Success message confirms backup creation. Backups are stored in the app\'s backup directory.',
    'create backup':
        'To create a backup (Owner only): 1) Go to Owner Dashboard, 2) Click "Backup & Restore", 3) Click "Create Backup" button at the top, 4) System creates timestamped backup automatically, 5) Success message confirms backup creation. Backups are stored in the app\'s backup directory.',
    'backup data':
        'To create a backup (Owner only): 1) Go to Owner Dashboard, 2) Click "Backup & Restore", 3) Click "Create Backup" button at the top, 4) System creates timestamped backup automatically, 5) Success message confirms backup creation. Backups include all products, sales, users, and inventory data.',
    'how to restore':
        'To restore a backup (Owner only): 1) Go to Backup & Restore screen, 2) View list of available backups with timestamps, 3) Click "Restore" button on desired backup, 4) Confirm restoration warning (current data will be replaced), 5) System restores data, 6) Restart app to see restored data. CAUTION: Restoration overwrites current database.',
    'restore data':
        'To restore a backup (Owner only): 1) Go to Backup & Restore screen, 2) View list of available backups with timestamps, 3) Click "Restore" button on desired backup, 4) Confirm restoration warning (current data will be replaced), 5) System restores data, 6) Restart app to see restored data. CAUTION: Restoration overwrites current database.',
    'restore database':
        'To restore a backup (Owner only): 1) Go to Backup & Restore screen, 2) View list of available backups with timestamps, 3) Click "Restore" button on desired backup, 4) Confirm restoration warning (current data will be replaced), 5) System restores data, 6) Restart app to see restored data. CAUTION: Restoration overwrites current database.',
    'export database':
        'To export database (Owner only): 1) Open Backup & Restore, 2) Click "Export Database" button, 3) Choose save location and filename (defaults to pos_system_export_YYYY-MM-DD_HHmmss.db), 4) System exports complete database to selected location. Use this to save backups to external drives or cloud storage.',
    'export':
        'To export database (Owner only): 1) Open Backup & Restore, 2) Click "Export Database" button, 3) Choose save location and filename (defaults to pos_system_export_YYYY-MM-DD_HHmmss.db), 4) System exports complete database to selected location. Use this to save backups to external drives or cloud storage.',
    'import database':
        'To import database (Owner only): 1) Open Backup & Restore, 2) Click "Import Database" button, 3) Select .db file from file picker, 4) Confirm import warning, 5) System imports and replaces current database, 6) Restart app. Use this to restore from external backup files.',
    'import':
        'To import database (Owner only): 1) Open Backup & Restore, 2) Click "Import Database" button, 3) Select .db file from file picker, 4) Confirm import warning, 5) System imports and replaces current database, 6) Restart app. Use this to restore from external backup files.',
    'automatic backup':
        'Currently, backups are manual - you must create them via Backup & Restore screen. It\'s recommended to create backups: Daily (end of business), Before major changes (bulk product updates), Before system updates. Store exported backups in multiple locations (cloud storage, external drive) for safety.',
    'data protection':
        'Protect your data using Backup & Restore: 1) Create regular backups (daily recommended), 2) Export backups to external storage (USB drive, cloud), 3) Test restore process periodically, 4) Keep backups in multiple locations. Backups include all products, sales, users, and inventory data - essential for business continuity and disaster recovery.',
    'save data':
        'To save/backup your data: 1) Go to Owner Dashboard → "Backup & Restore", 2) Click "Create Backup" to save current database, 3) Click "Export Database" to save backup file to external location (USB, cloud). Regular backups protect against data loss from hardware failure, user error, or system issues.',
    'recover data':
        'To recover data: 1) Go to Owner Dashboard → "Backup & Restore", 2) If restoring from internal backup: Click "Restore" on desired backup from list, 3) If restoring from external file: Click "Import Database" and select .db file, 4) Confirm restoration, 5) Restart app. CAUTION: Restoration replaces all current data.',

    // Technical
    'export data':
        'Export options (Admin/Owner): Sales reports, inventory data, and damage reports can be exported to CSV (spreadsheet) or PDF (document) format. Click export buttons in respective report screens.',
    'search products':
        'Search products by: 1) Product name (partial match), 2) Barcode (exact match), 3) Category. Search is available in inventory screen and product management. Results update in real-time as you type.',
    'user manual': '''# Smart Store Monitoring System
## User Manual

**Version 1.1**  
**Last Updated: January 28, 2026**

---

## Table of Contents

1. [Installation Instructions](#installation-instructions)
2. [Getting Started](#getting-started)
3. [User Roles & Permissions](#user-roles--permissions)
4. [How to Create Admin Account](#how-to-create-admin-account)
5. [Admin Features](#admin-features)
6. [Owner Features](#owner-features)
7. [Cashier Features](#cashier-features)
8. [Backup & Restore Guide](#backup--restore-guide)
9. [Quick Start Guide](#quick-start-guide)
10. [Troubleshooting FAQ](#troubleshooting-faq)
11. [Support Information](#support-information)

---

## Recent Feature Updates (Jan 28, 2026)

- **E‑Wallet Transfers enabled for Basic plan**: The in-app E‑Wallet transfer (cash-in / cash-out) feature is now available for stores on the Basic plan. See the `Owner Features` → E‑wallet section for usage and fees.
- **Backup & Restore available for Basic plan**: Owners on the Basic plan can now create local backups and restore the database from device storage. See `Backup & Restore Guide` for step-by-step instructions.
- **Improved Receipt & Printing UX**: After checkout the app now opens the receipt preview and print dialog automatically (you can cancel the print dialog and keep the preview open). A new `Thermal 48mm` paper option is supported for common thermal printers.
- **Keyboard shortcut for Checkout**: On desktop, pressing the `Enter` key in the POS/cart sheet will trigger checkout and open the receipt preview/print flow.
- **Responsive / Centered Desktop Layouts**: Many admin, owner, and cashier screens have improved desktop layouts — content is centered and constrained for large screens for better readability.
- **Price Checker & Large Price Display**: The Price Checker screen and large price readouts are now responsive and will scale to fit on narrow and wide screens.

Refer to the sections below for detailed instructions for each feature.


## Installation Instructions

### System Requirements

**For Windows Desktop:**
- Windows 10 or later (64-bit)
- Minimum 4GB RAM
- 500MB free disk space
- Screen resolution: 1280x720 or higher

**For Android:**
- Android 7.0 (Nougat) or later
- Minimum 2GB RAM
- 200MB free storage

**For iOS:**
- iOS 12.0 or later
- iPhone 6s or newer
- iPad Air 2 or newer

### Windows Installation Steps

1. **Download the installer**
    - Locate the `smart_monitoring_system.exe` file
    - Or run from `build/windows/x64/runner/Release/` directory

2. **Run the application**
    - Double-click the executable file
    - Windows Defender may show a warning on first run
    - Click "More info" → "Run anyway" (first time only)

3. **Grant permissions**
    - Allow camera access (for barcode scanning)
    - Allow file access (for backup/restore and image uploads)

4. **Verify installation**
    - The login screen should appear
    - The system is ready to use

### Android/iOS Installation

1. **Install APK (Android)**
    - Transfer the `.apk` file to your device
    - Enable "Install from Unknown Sources" in Settings
    - Tap the APK file and follow installation prompts

2. **Install from App Store (iOS)**
    - Search for "Smart Store Monitoring System" (if published)
    - Or install via TestFlight for beta testing

3. **Grant permissions**
    - Camera (for barcode scanning)
    - Storage (for backup/restore)
    - Notifications (optional)

### Database Setup

The system automatically creates a local database on first launch. No manual database configuration is required.

**Database Location:**
- **Windows:** `C:\\Users\\[YourUsername]\\AppData\\Local\\smart_monitoring_system\\databases\\`
- **Android:** `/data/data/com.example.smart_monitoring_system/databases/`
- **iOS:** Application Documents directory

---

## Getting Started

### First Launch

1. **Open the application**
    - Launch the Smart Store Monitoring System

2. **You'll see the login screen with three options:**
    - Admin Login
    - Owner Login
    - Cashier Login

3. **First-time setup requires creating an Admin account**

---

## User Roles & Permissions

### Admin (Full System Access)
- ✅ Manage user accounts (create/edit/deactivate owners and cashiers)
- ✅ Manage products (add/edit/delete/restock)
- ✅ View all reports (sales, inventory, user activity, damage)
- ✅ Export data (CSV/PDF)
- ✅ Configure system settings
- ✅ Access all features

### Owner (Business Management)
- ✅ View detailed sales reports
- ✅ Monitor CCTV feeds
- ✅ Manage inventory
- ✅ Report damaged items
- ✅ Access POS terminal
- ✅ Backup & Restore database
- ✅ View analytics and charts
- ❌ Cannot manage users
- ❌ Cannot delete products

### Cashier (Point of Sale Operations)
- ✅ Process customer transactions
- ✅ Add items to cart
- ✅ Apply discounts
- ✅ Complete sales
- ✅ View sales log
- ✅ Access CCTV (with owner password)
- ✅ Attendance (clock-in / clock-out)
- ❌ Cannot manage products
- ❌ Cannot view reports
- ❌ Cannot manage inventory

---

### Attendance

#### Clock In / Clock Out (Cashier)

1. **Open the POS (Cashier) screen**
2. Tap the **Profile / Attendance** icon (top-right) or use the `Attendance` action
3. **Clock In** to start your shift; the app records timestamp and device
4. **Clock Out** when you finish; supervisors can edit entries if needed
5. Owners/Admins can export attendance logs (CSV) from the Admin → Manage Attendance screen

---

## How to Create Admin Account

### Step 1: Click "Create Admin Account"

On the login screen:
1. Click the **"Create Admin Account"** button at the bottom
2. A registration form will appear

### Step 2: Fill in Account Details

**Required Information:**
- **Full Name:** Your complete name
- **Email Address:** Valid email (e.g., admin@store.com)
- **Contact Number:** Must start with +63 (Philippine format)
  - Example: +639171234567
- **Password:** Minimum 8 characters
  - Must contain: letters, numbers, and symbols
  - Example: `Admin@2025`

### Step 3: Verify Information

- Double-check all entered information
- Ensure email is correct (for password recovery)
- Ensure phone number includes country code (+63)

### Step 4: Create Account

1. Click **"Create Account"** button
2. Wait for success confirmation
3. You'll be redirected to the login screen

### Step 5: Login as Admin

1. Select **Admin Login** tab
2. **Choose login method:**
    - **Email + Password** OR
    - **Contact Number + Password** OR
    - **Gmail Sign-In** (if configured)
3. Click **"Login"** button

**First Login Checklist:**
- ✅ Admin account created successfully
- ✅ Can login to Admin Dashboard
- ✅ All admin features accessible

---

## Admin Features

### 1. Managing User Accounts

#### Add a New User (Owner or Cashier)

1. **Navigate to User Management**
    - From Admin Dashboard → Click **"Manage Users"**
2. **Add New User**
    - Click the **"+"** icon (top-right corner)
    - Fill in user details:
      - Full Name
      - Email Address
      - Password
      - 4-digit PIN (for quick login)
      - Select Role: **Owner** or **Cashier**

3. **Save User**
    - Click **"Save"** button
    - User can now login with their credentials

#### Edit Existing User

1. In User Management screen
2. Tap the user card you want to edit
3. Modify details as needed
4. Click **"Update"** to save changes

#### Deactivate User

1. In User Management screen
2. Tap the user card
3. Toggle **"Active Status"** switch to OFF
4. Deactivated users cannot login

### 2. Managing Products

#### Add a New Product

1. **Navigate to Product Management**
    - Admin Dashboard → **"Manage Products"**
2. **Click "Add Product" button**
3. **Fill in Product Information:**
    - **Product Name:** Descriptive name (e.g., "Coca-Cola 1.5L")
    - **Barcode:** Scan or enter manually
    - **Category:** Select from dropdown or create new
    - **Buying Price:** Cost price (₱)
    - **Selling Price:** Retail price (₱)
    - **Quantity:** Current stock level
    - **Reorder Level:** Minimum stock threshold (default: 5)
    - **Product Image:** Click camera icon to add photo

4. **Save Product**
    - Click **"Save"** button
    - Product is now available in POS

***
''',
  };

  // Bilingual knowledge base - Filipino
  final Map<String, String> _knowledgeBaseFil = {
    // General System
    'ano ang system':
        'Ito ay Smart Store Monitoring System - isang komprehensibong POS (Point of Sale) at inventory management solution na may CCTV monitoring. Sumusuporta ito ng tatlong user roles: Admin, Owner, at Cashier, bawat isa ay may kani-kanilang permissions at features.',
    'ano ang magagawa ng system':
        'Ang sistema ay maaaring: 1) Magproseso ng sales transactions sa POS, 2) Mag-manage ng inventory at products, 3) Mag-track ng damage reports, 4) Mag-monitor ng CCTV feeds, 5) Gumawa ng sales reports at analytics, 6) Mag-manage ng users at permissions, 7) Humawak ng multi-method authentication.',
    'user roles':
        'May tatlong user roles:\n• Admin - Buong access sa sistema, nag-manage ng users, products, at settings\n• Owner - Nakakapag-view ng reports, nag-monitor ng CCTV, nag-manage ng inventory, pwedeng mag-access ng POS\n• Cashier - Pangunahing nag-operate ng POS terminal para sa customer transactions',

    // Admin Features
    'admin features':
        'Ang Admin ay maaaring: 1) Mag-manage ng user accounts (create/edit/deactivate ng owners at cashiers), 2) Mag-manage ng products (add/edit/delete/restock), 3) Mag-view ng comprehensive reports (sales, inventory, damage), 4) Mag-configure ng system settings, 5) Mag-export ng data sa CSV/PDF, 6) Mag-manage ng admin account details.',
    'paano magdagdag ng user':
        'Para magdagdag ng user (Admin lang): 1) Pumunta sa Admin Dashboard, 2) I-click ang "Manage Users", 3) I-click ang "+" icon sa top-right, 4) Punan ang name, email, password, pin, at piliin ang role (Owner/Cashier), 5) I-click ang Save. Ang bagong user ay makakapag-login gamit ang credentials.',
    'paano magdagdag ng product':
        'Para magdagdag ng product (Admin lang): 1) Pumunta sa Admin Dashboard, 2) I-click ang "Manage Products", 3) I-click ang "Add Product" button, 4) I-enter ang product name, barcode, category, buying price, selling price, quantity, at reorder level, 5) Optional na magdagdag ng product image, 6) I-click ang Save.',
    'admin reports':
        'Ang Admin ay makakakita ng 4 uri ng reports: 1) Sales Reports - transaction history at totals, 2) Product Reports - inventory levels at movements, 3) User Activity - user actions at timestamps, 4) Damage Reports - damaged items na may value calculations. Lahat ng reports ay pwedeng i-export sa CSV o PDF.',

    // Owner Features
    'owner features':
        'Ang Owner ay maaaring: 1) Mag-view ng detalyadong sales reports at analytics, 2) Mag-monitor ng CCTV feeds in real-time, 3) Mag-check at mag-manage ng inventory, 4) Mag-report ng damaged items, 5) Mag-access ng POS terminal kung kailangan, 6) Mag-view ng sales charts at trends.',
    'sales reports':
        'Ang Sales reports ay nagpapakita ng: Daily summaries na may total sales, transaction count, at average transaction value. Maaari kang pumili ng date ranges, mag-view ng individual transaction details, at mag-export ng reports. Ma-access mula sa Owner Dashboard → "View Sales Reports".',
    'cctv monitoring':
        'Ang CCTV monitoring ay nagbibigay-daan sa real-time video feed viewing. Ma-access mula sa Owner Dashboard → "Monitor CCTV". I-configure ang camera URLs sa settings. Sumusuporta ng RTSP/HTTP streams o local video files.',
    'inventory management':
        'Ang Inventory screen ay nagpapakita ng lahat ng products na may: current stock levels, low stock warnings (≤5 items), product details, at damage reports. Maaari kang mag-search sa pamamagitan ng name/barcode, mag-update ng stock, at mag-view ng movement history.',

    // Cashier Features
    'cashier features':
        'Ang Cashier ay maaaring: 1) Magproseso ng customer transactions sa POS, 2) Magdagdag ng items sa cart sa pamamagitan ng pag-scan ng barcode o manual selection, 3) Gumamit ng search bar para maghanap ng products, 4) Mag-apply ng discounts, 5) Kumpletuhin ang sales at gumawa ng receipts, 6) Humawak ng multiple payment methods, 7) Mag-view ng sales log history, 8) Mag-access ng CCTV footage na may owner password verification.',
    'paano gamitin ang pos':
        'Para magproseso ng sale: 1) Buksan ang POS mula sa Cashier Dashboard, 2) Gumamit ng search bar para mabilis na maghanap ng products o mag-tap sa product tiles, 3) Mag-scan ng barcodes para sa mas mabilis na checkout, 4) Long-press ang product images para makita ang mas malaking version, 5) Ayusin ang quantities gamit ang +/- buttons, 6) Mag-apply ng discounts kung kailangan, 7) I-review ang cart total, 8) I-click ang "Checkout" para kumpletuhin ang sale. Ang receipt ay awtomatikong na-generate.',
    'pos checkout':
        'Sa panahon ng checkout: Vina-validate ng system ang stock availability, binabawasan ang product quantities, nire-record ang sale na may timestamp at cashier name, ginu-generate ang sale number, at kina-clear ang cart. Lumalabas ang low stock warnings kung ang items ay bumaba sa reorder level.',
    'pos search':
        'Ang POS screen ay may search bar sa itaas. I-type ang product name o barcode para i-filter ang products in real-time. Gumagana ang search kasama ang category filters - maaari kang maghanap sa loob ng selected category o sa lahat ng products. Lumalabas ang clear button kapag nag-search.',
    'cctv mula sa sales log':
        'Ang mga Cashiers ay maaaring mag-view ng CCTV footage mula sa sales log, ngunit kailangan ng owner password verification. Sa sales log, i-click ang camera icon sa tabi ng anumang sale. Lalabas ang dialog na humihingi ng owner password. Ang mga active owner accounts lang ang makakapag-authorize ng access.',
    'tingnan ang product images':
        'Ang Product images ay ipinapakita bilang 80x80 thumbnails sa POS tiles. Para makita ang mas malaking view: Long-press ang anumang product tile na may image. Lalabas ang enlarged, zoomable view sa isang dialog. Gumamit ng pinch/scroll para mag-zoom 0.5x hanggang 4x. Ang interactive viewer ay nagbibigay-daan sa panning at zooming.',

    // Authentication
    'paano mag-login':
        'Login options: 1) Admin - mag-login gamit ang email/Gmail O contact number + password, 2) Owner/Cashier - mag-login gamit ang email + password. Ang password visibility ay maaaring i-toggle gamit ang eye icon. Ang first-time admins ay maaaring gumawa ng account gamit ang "Create Admin Account" button.',
    'nakalimutan ang password':
        'Para sa admin password reset: I-click ang "Forgot Password?" → I-enter ang admin email → I-verify ang OTP na ipinadala sa email → I-enter ang phone number → I-verify ang SMS code → Mag-set ng bagong password. Ang multi-step verification na ito ay nagsisiguro ng seguridad.',
    'gumawa ng admin account':
        'Para gumawa ng admin account: 1) I-click ang "Create Admin Account" sa login screen, 2) I-enter ang name, email, contact number, at password, 3) Vina-validate ng system ang email format at phone number (dapat magsimula sa +63), 4) I-click ang "Create Account". Maaari ka na ngayong mag-login gamit ang mga credentials na ito.',
    'ipakita ang password':
        'Sa login screen, maaari mong i-toggle ang password visibility sa pamamagitan ng pag-click sa eye icon sa kanan ng password field. I-click ang eye para ipakita ang password text, i-click ulit para itago ito. Nakakatulong ito para ma-verify na tama ang na-type mo.',

    // Damage Reports
    'damage reports':
        'Ang Damage reports ay nag-track ng inventory losses. Para mag-report ng damage: 1) Pumunta sa Inventory → Damage Reports tab, 2) I-click ang "Report Damage", 3) Piliin ang product, i-enter ang quantity damaged at reason, 4) I-submit. Ang reports ay nagpapakita ng total items damaged, total value lost, at pwedeng i-export.',
    'paano mag-report ng damage':
        'Mula sa Inventory screen: 1) Pumunta sa "Damage Reports" tab, 2) I-click ang "Report Damage" button, 3) Piliin ang damaged product mula sa dropdown, 4) I-enter ang quantity damaged, 5) Piliin o i-enter ang damage reason (Expired, Broken, Contaminated, etc.), 6) I-click ang Submit. Ang report ay may timestamp na may pangalan mo.',

    // Settings & Theme
    'palitan ang theme':
        'Para palitan ang theme: 1) I-click ang Settings icon (gear) sa app bar, 2) Mag-scroll sa "Theme" section, 3) Pumili mula sa honeycomb color picker (9 preset colors), O i-click ang "+" para pumili ng custom color mula sa 24 options. Ang theme ay nag-aaply sa buong sistema kaagad.',
    'palitan ang wika':
        'Para palitan ang wika: 1) Buksan ang Settings, 2) Sa ilalim ng "Language" section, piliin ang English (EN) o Filipino (FIL) mula sa dropdown. Ang language changes ay nag-aaply kaagad sa lahat ng screens kasama ang AI assistant na ito.',
    'bawasan ang galaw':
        'Ang Reduce Motion ay isang accessibility feature na binabawasan ang animations. I-enable ito sa Settings → i-toggle ang "Reduce Motion" switch. Kapag naka-enable: Ang login screen background ay tumitigil sa paggalaw, ang splash screen ay nag-navigate kaagad, at ang ibang animations ay minimized.',
    'settings':
        'Ang Settings ay may: 1) Language selection (English/Filipino), 2) Theme customization na may honeycomb picker at custom colors, 3) Reduce Motion toggle para sa accessibility. Ma-access ang settings sa pamamagitan ng gear icon sa app bar.',

    // Product Management
    'low stock':
        'Ang Low stock warnings ay lumalabas kapag ang product quantity ay ≤ 5 items. Ang mga products ay na-highlight sa pula sa inventory screen. Ang reorder level ay maaaring i-customize kada product. Ang Admin ay nakakakita ng low stock count badge sa Manage Products.',
    'restock product':
        'Para mag-restock (Admin lang): 1) Pumunta sa Manage Products, 2) I-click ang product para i-edit, 3) I-update ang quantity field sa bagong stock level, 4) I-click ang Save. Nire-record ng system ang inventory movement na may timestamp.',
    'product barcode':
        'Ang mga Products ay maaaring magkaroon ng barcodes para sa mabilis na pag-scan. Kapag nagdadagdag/nag-eedit ng products, i-enter ang barcode manually o i-scan gamit ang device camera. Sa POS, ang mga cashiers ay maaaring mag-scan ng barcodes para magdagdag ng items sa cart kaagad.',

    // System Navigation
    'dashboard navigation':
        'Bawat role ay may dedicated dashboard:\n• Admin Dashboard - Mag-manage ng users, products, reports, settings\n• Owner Dashboard - Sales reports, CCTV, inventory, POS access, backup & restore\n• Cashier Dashboard - POS terminal access\nGamitin ang menu cards para mag-navigate sa iba\'t ibang features.',
    'logout':
        'Para mag-logout: I-click ang logout icon (arrow na may pinto) sa top-right corner ng anumang dashboard. Babalik ka sa login screen. Ang iyong session data ay kina-clear para sa seguridad.',

    // Backup & Restore
    'backup':
        'Ang Backup & Restore ay nagpoprotekta sa iyong datos. Ma-access mula sa Owner Dashboard → "Backup & Restore". Features: 1) Gumawa ng manual backups, 2) Mag-restore mula sa nakaraang backups, 3) Mag-export ng database sa external location, 4) Mag-import ng database mula sa external file. Kasama sa backups ang lahat ng products, sales, users, at inventory data.',
    'restore':
        'Para mag-restore ng backup (Owner lang): 1) Pumunta sa Backup & Restore screen, 2) Tingnan ang listahan ng available backups na may timestamps, 3) I-click ang "Restore" button sa gustong backup, 4) Kumpirmahin ang restoration warning (papalitan ang current data), 5) Nire-restore ng system ang data, 6) I-restart ang app para makita ang restored data. BABALA: Ang restoration ay nag-o-overwrite ng current database.',
    'backup restore':
        'Ang Backup & Restore ay nagpoprotekta sa iyong datos. Ma-access mula sa Owner Dashboard → "Backup & Restore". Features: 1) Gumawa ng manual backups, 2) Mag-restore mula sa nakaraang backups, 3) Mag-export ng database sa external location, 4) Mag-import ng database mula sa external file. Kasama sa backups ang lahat ng products, sales, users, at inventory data.',
    'paano mag-backup':
        'Para gumawa ng backup (Owner lang): 1) Pumunta sa Owner Dashboard, 2) I-click ang "Backup & Restore", 3) I-click ang "Create Backup" button sa itaas, 4) Awtomatikong gumagawa ang system ng timestamped backup, 5) Kumpirma ng success message ang backup creation. Ang mga backups ay nakaimbak sa backup directory ng app.',
    'gumawa ng backup':
        'Para gumawa ng backup (Owner lang): 1) Pumunta sa Owner Dashboard, 2) I-click ang "Backup & Restore", 3) I-click ang "Create Backup" button sa itaas, 4) Awtomatikong gumagawa ang system ng timestamped backup, 5) Kumpirma ng success message ang backup creation. Ang mga backups ay nakaimbak sa backup directory ng app.',
    'backup data':
        'Para gumawa ng backup (Owner lang): 1) Pumunta sa Owner Dashboard, 2) I-click ang "Backup & Restore", 3) I-click ang "Create Backup" button sa itaas, 4) Awtomatikong gumagawa ang system ng timestamped backup, 5) Kumpirma ng success message ang backup creation. Kasama sa backups ang lahat ng products, sales, users, at inventory data.',
    'paano mag-restore':
        'Para mag-restore ng backup (Owner lang): 1) Pumunta sa Backup & Restore screen, 2) Tingnan ang listahan ng available backups na may timestamps, 3) I-click ang "Restore" button sa gustong backup, 4) Kumpirmahin ang restoration warning (papalitan ang current data), 5) Nire-restore ng system ang data, 6) I-restart ang app para makita ang restored data. BABALA: Ang restoration ay nag-o-overwrite ng current database.',
    'ibalik ang data':
        'Para mag-restore ng backup (Owner lang): 1) Pumunta sa Backup & Restore screen, 2) Tingnan ang listahan ng available backups na may timestamps, 3) I-click ang "Restore" button sa gustong backup, 4) Kumpirmahin ang restoration warning (papalitan ang current data), 5) Nire-restore ng system ang data, 6) I-restart ang app para makita ang restored data. BABALA: Ang restoration ay nag-o-overwrite ng current database.',
    'restore database':
        'Para mag-restore ng backup (Owner lang): 1) Pumunta sa Backup & Restore screen, 2) Tingnan ang listahan ng available backups na may timestamps, 3) I-click ang "Restore" button sa gustong backup, 4) Kumpirmahin ang restoration warning (papalitan ang current data), 5) Nire-restore ng system ang data, 6) I-restart ang app para makita ang restored data. BABALA: Ang restoration ay nag-o-overwrite ng current database.',
    'mag-export ng database':
        'Para mag-export ng database (Owner lang): 1) Buksan ang Backup & Restore, 2) I-click ang "Export Database" button, 3) Piliin ang save location at filename (default: pos_system_export_YYYY-MM-DD_HHmmss.db), 4) Ine-export ng system ang complete database sa napiling location. Gamitin ito para mag-save ng backups sa external drives o cloud storage.',
    'export':
        'Para mag-export ng database (Owner lang): 1) Buksan ang Backup & Restore, 2) I-click ang "Export Database" button, 3) Piliin ang save location at filename (default: pos_system_export_YYYY-MM-DD_HHmmss.db), 4) Ine-export ng system ang complete database sa napiling location. Gamitin ito para mag-save ng backups sa external drives o cloud storage.',
    'mag-import ng database':
        'Para mag-import ng database (Owner lang): 1) Buksan ang Backup & Restore, 2) I-click ang "Import Database" button, 3) Piliin ang .db file mula sa file picker, 4) Kumpirmahin ang import warning, 5) Ini-import at pinapalitan ng system ang current database, 6) I-restart ang app. Gamitin ito para mag-restore mula sa external backup files.',
    'import':
        'Para mag-import ng database (Owner lang): 1) Buksan ang Backup & Restore, 2) I-click ang "Import Database" button, 3) Piliin ang .db file mula sa file picker, 4) Kumpirmahin ang import warning, 5) Ini-import at pinapalitan ng system ang current database, 6) I-restart ang app. Gamitin ito para mag-restore mula sa external backup files.',
    'automatic backup':
        'Sa kasalukuyan, manual ang mga backups - dapat mong gawin ang mga ito sa pamamagitan ng Backup & Restore screen. Inirerekomenda na gumawa ng backups: Araw-araw (katapusan ng negosyo), Bago ang malalaking pagbabago (bulk product updates), Bago ang system updates. I-store ang exported backups sa maraming lokasyon (cloud storage, external drive) para sa kaligtasan.',
    'proteksyon ng data':
        'Protektahan ang iyong datos gamit ang Backup & Restore: 1) Gumawa ng regular backups (araw-araw ay inirerekomenda), 2) Mag-export ng backups sa external storage (USB drive, cloud), 3) Subukan ang restore process pana-panahon, 4) Panatilihin ang backups sa maraming lokasyon. Kasama sa backups ang lahat ng products, sales, users, at inventory data - mahalaga para sa business continuity at disaster recovery.',
    'i-save ang data':
        'Para i-save/backup ang iyong datos: 1) Pumunta sa Owner Dashboard → "Backup & Restore", 2) I-click ang "Create Backup" para i-save ang current database, 3) I-click ang "Export Database" para i-save ang backup file sa external location (USB, cloud). Ang regular backups ay nagpoprotekta laban sa data loss mula sa hardware failure, user error, o system issues.',
    'bawiin ang data':
        'Para mabawi ang datos: 1) Pumunta sa Owner Dashboard → "Backup & Restore", 2) Kung nag-restore mula sa internal backup: I-click ang "Restore" sa gustong backup mula sa listahan, 3) Kung nag-restore mula sa external file: I-click ang "Import Database" at piliin ang .db file, 4) Kumpirmahin ang restoration, 5) I-restart ang app. BABALA: Ang restoration ay pinapalitan ang lahat ng current data.',

    // Technical
    'export data':
        'Export options (Admin/Owner): Ang Sales reports, inventory data, at damage reports ay maaaring i-export sa CSV (spreadsheet) o PDF (document) format. I-click ang export buttons sa respective report screens.',
    'search products':
        'Mag-search ng products sa pamamagitan ng: 1) Product name (partial match), 2) Barcode (exact match), 3) Category. Ang search ay available sa inventory screen at product management. Ang results ay nag-uupdate in real-time habang ikaw ay nagte-type.',
  };

  AIHelpService() {
    // SmartPlus is the only user-facing assistant. The existing system-help
    // knowledge base is retained below and used as part of its responses.
    _addWelcomeMessage();

    // Listen to locale changes and update welcome message
    LocaleController.locale.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    // Clear and re-add welcome message in new language
    if (_messages.length == 1 && !_messages.first.isUser) {
      _messages.clear();
      _addWelcomeMessage();
      notifyListeners();
    }
  }

  void _addWelcomeMessage() {
    final isFilipino = LocaleController.locale.value.languageCode == 'fil';
    _messages.add(
      ChatMessage(
        text: isFilipino
            ? 'Ako ang SmartPlus — ang business assistant mo. Ginagamit ko ang available na sales at inventory records para magbigay ng malinaw na suggestions.\n\nMaaari mong itanong:\n• Top 5 products noong nakaraang buwan\n• Low-stock at reorder suggestions\n• Sales performance nitong linggo\n• Product pairs para sa upsell\n• Unusual discounts na kailangang i-review\n• Paano gamitin ang POS, reports, inventory, settings, at user roles\n\nHindi ako gumagawa ng supplier orders, checkout, o voice commands nang walang hiwalay na approved integration.'
            : 'I am SmartPlus — your business assistant. I use the available sales and inventory records to provide clear suggestions.\n\nAsk about:\n• Top 5 products last month\n• Low stock and reorder suggestions\n• Sales performance this week\n• Product pairs for upsells\n• Unusual discounts to review\n• How to use POS, reports, inventory, settings, and user roles\n\nI do not place supplier orders, complete checkout, or execute voice commands without a separate approved integration.',
        isUser: false,
      ),
    );
  }

  /// Starts a fresh, data-backed SmartPlus conversation. This remains
  /// deterministic and local: it never sends business records to an AI vendor.
  void startSmartPlus() {
    _messages.clear();
    _addWelcomeMessage();
    notifyListeners();
  }

  @override
  void dispose() {
    LocaleController.locale.removeListener(_onLocaleChanged);
    super.dispose();
  }

  /// Send a user message and get AI response
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || _isThinking) return;

    // Add user message
    _messages.add(ChatMessage(text: userMessage.trim(), isUser: true));
    _isThinking = true;
    notifyListeners();

    try {
      // Keep a short, honest thinking state so the response does not appear
      // abruptly while data rules are evaluated.
      await Future.delayed(const Duration(milliseconds: 650));
      final query = userMessage.toLowerCase().trim();
      final response = _generateSmartPlusResponse(query);
      _messages.add(ChatMessage(text: response, isUser: false));
    } finally {
      _isThinking = false;
      notifyListeners();
    }
  }

  /// Generate response based on user query and current language
  String _generateResponse(String query) {
    final isFilipino = LocaleController.locale.value.languageCode == 'fil';
    final knowledgeBase = isFilipino ? _knowledgeBaseFil : _knowledgeBaseEn;

    // Check for exact or partial matches in knowledge base
    for (final entry in knowledgeBase.entries) {
      if (query.contains(entry.key) || entry.key.contains(query)) {
        return entry.value;
      }
    }

    // Check for keywords with localized responses
    if (query.contains('help') ||
        query.contains('how') ||
        query.contains('tulong') ||
        query.contains('paano')) {
      return isFilipino
          ? 'Makakatulong ako sa iyo sa:\n\n'
                '📊 Sales & Reports - sales reports, analytics, export data\n'
                '📦 Inventory - stock management, products, damage reports\n'
                '🛒 POS System - checkout process, transactions\n'
                '👥 User Management - roles, permissions, accounts\n'
                '📹 CCTV - monitoring, camera setup\n'
                '⚙️ Settings - themes, language, preferences\n\n'
                'Subukang magtanong ng tulad ng "paano gamitin ang pos" o "ano ang damage report"'
          : 'I can help you with:\n\n'
                '📊 Sales & Reports - sales reports, analytics, export data\n'
                '📦 Inventory - stock management, products, damage reports\n'
                '🛒 POS System - checkout process, transactions\n'
                '👥 User Management - roles, permissions, accounts\n'
                '📹 CCTV - monitoring, camera setup\n'
                '⚙️ Settings - themes, language, preferences\n\n'
                'Try asking something like "how to use pos" or "what is damage report"';
    }

    if (query.contains('thank') || query.contains('salamat')) {
      return isFilipino
          ? 'Walang anuman! Huwag mag-atubiling magtanong kung mayroon kang iba pang katanungan tungkol sa sistema. 😊'
          : 'You\'re welcome! Feel free to ask if you have any other questions about the system. 😊';
    }

    if (query.contains('hi') ||
        query.contains('hello') ||
        query.contains('hey') ||
        query.contains('kumusta')) {
      return isFilipino
          ? 'Kumusta! Paano kita matutulungan ngayon? Maaari mo akong tanungin tungkol sa anumang feature ng Smart Store Monitoring System.'
          : 'Hello! How can I help you today? You can ask me about any feature of the Smart Store Monitoring System.';
    }

    // Default response with suggestions
    return isFilipino
        ? 'Hindi ako sigurado sa partikular na tanong na iyan. Narito ang ilang mga paksa na makakatulong ako:\n\n'
              '• "ano ang system" - System overview\n'
              '• "user roles" - Maintindihan ang Admin, Owner, Cashier roles\n'
              '• "paano gamitin ang pos" - POS terminal guide\n'
              '• "admin features" - Ano ang magagawa ng admins\n'
              '• "damage reports" - Paano mag-report ng damaged items\n'
              '• "palitan ang theme" - Customize appearance\n'
              '• "sales reports" - Mag-view at mag-export ng reports\n\n'
              'Subukang muling i-phrase ang iyong tanong o magtanong tungkol sa isa sa mga paksang ito!'
        : 'I\'m not sure about that specific question. Here are some topics I can help with:\n\n'
              '• "what is this system" - System overview\n'
              '• "user roles" - Understand Admin, Owner, Cashier roles\n'
              '• "how to use pos" - POS terminal guide\n'
              '• "admin features" - What admins can do\n'
              '• "damage reports" - How to report damaged items\n'
              '• "change theme" - Customize appearance\n'
              '• "sales reports" - View and export reports\n\n'
              'Try rephrasing your question or ask about one of these topics!';
  }

  String _generateSmartPlusResponse(String query) {
    final pos = GetIt.I<POSService>();
    final products = pos.products;
    final completedSales = pos.recentSales
        .where((sale) => sale.status == SaleStatus.completed)
        .toList();

    if (query.contains('voice') || query.contains('checkout') || query.contains('add 2')) {
      return 'Voice-enabled checkout is not enabled in this system yet. SmartPlus can explain a checkout instruction, but it cannot add items, apply discounts, or complete a sale automatically.';
    }

    if (query.contains('reorder') || query.contains('low stock') || query.contains('stock')) {
      final lowStock = products.where((product) => product.lowStock).toList()
        ..sort((a, b) => a.quantity.compareTo(b.quantity));
      if (lowStock.isEmpty) {
        return 'No products are currently at or below their reorder level. Keep reviewing stock after each delivery and sale.';
      }
      final suggestions = lowStock.take(5).map((product) {
        final suggestedQuantity = (product.reorderLevel * 2 - product.quantity)
            .clamp(product.reorderLevel, 999999);
        return '• ${product.name}: ${product.quantity} in stock (reorder level ${product.reorderLevel}) — suggest ordering $suggestedQuantity';
      }).join('\n');
      return 'Smart reordering suggestion (recommended target: roughly twice the reorder level):\n$suggestions\n\nReview the quantities and supplier availability before creating an order. SmartPlus does not place supplier orders automatically.';
    }

    if (query.contains('discount') || query.contains('fraud') || query.contains('suspicious')) {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final flagged = completedSales.where((sale) {
        return sale.saleDate.isAfter(cutoff) &&
            sale.subtotal > 0 &&
            sale.discountAmount / sale.subtotal >= 0.20;
      }).toList();
      if (flagged.isEmpty) {
        return 'No completed sale in the last 30 days has a discount of 20% or more. This is a review rule, not a fraud determination.';
      }
      final samples = flagged.take(5).map(
        (sale) => '• ${sale.saleNumber}: ${AppCurrency.peso(sale.discountAmount)} discount on ${AppCurrency.peso(sale.subtotal)}',
      ).join('\n');
      return '${flagged.length} completed sale(s) in the last 30 days meet the 20% discount review threshold:\n$samples\n\nAsk the cashier or manager for the approved discount reason before taking action.';
    }

    if (query.contains('upsell') || query.contains('pair') || query.contains('often buy')) {
      final pairCounts = <String, int>{};
      for (final sale in completedSales) {
        final names = sale.items.map((item) => item.productName).toSet().toList()
          ..sort();
        for (var first = 0; first < names.length; first++) {
          for (var second = first + 1; second < names.length; second++) {
            final key = '${names[first]}|${names[second]}';
            pairCounts[key] = (pairCounts[key] ?? 0) + 1;
          }
        }
      }
      final pairs = pairCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (pairs.isEmpty) {
        return 'There are not enough completed sales with multiple items to identify product pairs yet. Complete more multi-item transactions, then ask again.';
      }
      return 'Best current cross-sell pair(s), based on completed transactions:\n${pairs.take(3).map((pair) => '• ${pair.key.replaceFirst('|', ' + ')} — bought together ${pair.value} time(s)').join('\n')}\n\nUse these as cashier suggestions, not automatic cart changes.';
    }

    if (query.contains('forecast') || query.contains('christmas') || query.contains('season')) {
      final quantities = _salesQuantities(completedSales, days: 90);
      final ranked = quantities.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (ranked.isEmpty) {
        return 'There is not enough completed-sale history to create a forecast. Add at least several weeks of sales data and try again.';
      }
      return 'Demand signal from the last 90 days (not a true seasonal forecast):\n${ranked.take(5).map((entry) => '• ${entry.key}: ${entry.value} unit(s) sold').join('\n')}\n\nFor a Christmas forecast, retain data from prior Christmas periods. SmartPlus will not claim seasonal demand without that history.';
    }

    if (query.contains('top') || query.contains('selling') || query.contains('last month')) {
      final quantities = _salesQuantities(completedSales, days: 31);
      final ranked = quantities.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (ranked.isEmpty) {
        return 'No completed item-level sales were found in the last 31 days.';
      }
      return 'Top selling products from the last 31 days:\n${ranked.take(5).toList().asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value.key} — ${entry.value.value} unit(s)').join('\n')}';
    }

    if (query.contains('sales') || query.contains('insight') || query.contains('week')) {
      final now = DateTime.now();
      final recentStart = now.subtract(const Duration(days: 7));
      final previousStart = now.subtract(const Duration(days: 14));
      final recent = completedSales.where((sale) => sale.saleDate.isAfter(recentStart));
      final previous = completedSales.where(
        (sale) => sale.saleDate.isAfter(previousStart) && !sale.saleDate.isAfter(recentStart),
      );
      final recentTotal = recent.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
      final previousTotal = previous.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
      final change = previousTotal == 0 ? null : ((recentTotal - previousTotal) / previousTotal) * 100;
      final comparison = change == null
          ? 'There is no previous-week baseline yet.'
          : '${change >= 0 ? 'up' : 'down'} ${change.abs().toStringAsFixed(1)}% from the prior 7 days.';
      return 'Sales insight: ${AppCurrency.peso(recentTotal)} from ${recent.length} completed transaction(s) in the last 7 days — $comparison\n\nSmartPlus can identify the change in sales records, but it cannot determine the cause (such as foot traffic) without that data.';
    }

    // SmartPlus also carries the previous system-help knowledge, so owners can
    // ask operational questions such as POS, roles, reports, or settings.
    return _generateResponse(query);
  }

  Map<String, int> _salesQuantities(List<Sale> sales, {required int days}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final quantities = <String, int>{};
    for (final sale in sales.where((sale) => sale.saleDate.isAfter(cutoff))) {
      for (final item in sale.items) {
        quantities[item.productName] = (quantities[item.productName] ?? 0) + item.quantity;
      }
    }
    return quantities;
  }

  /// Clear conversation history
  void clearMessages() {
    _messages.clear();
    _addWelcomeMessage();
    notifyListeners();
  }

  /// Get suggested questions based on current language
  List<String> getSuggestedQuestions() {
    final isFilipino = LocaleController.locale.value.languageCode == 'fil';
    return isFilipino
        ? [
            'Ano ang system?',
            'Paano gamitin ang POS?',
            'Ano ang user roles?',
            'Paano magdagdag ng product?',
            'Paano mag-report ng damage?',
            'Palitan ang theme',
            'Sales reports',
            'CCTV monitoring',
          ]
        : [
            'What is this system?',
            'How to use POS?',
            'What are user roles?',
            'How to add product?',
            'How to report damage?',
            'Change theme',
            'View sales reports',
            'CCTV monitoring',
          ];
  }
}
