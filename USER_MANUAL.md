# Smart Store Monitoring System
## User Manual

**Version 2.0**  
**Last Updated: February 5, 2026**

---

## Table of Contents

1. [Installation Instructions](#installation-instructions)
2. [Getting Started](#getting-started)
3. [User Roles & Permissions](#user-roles--permissions)
4. [How to Create Admin Account](#how-to-create-admin-account)
5. [Admin Features](#admin-features)
6. [Owner Features](#owner-features)
7. [Manager Features](#manager-features)
8. [Sales Promoter Features](#sales-promoter-features)
9. [Inventory Clerk Features](#inventory-clerk-features)
10. [Delivery Receiver Features](#delivery-receiver-features)
11. [Cashier Features](#cashier-features)
12. [Backup & Restore Guide](#backup--restore-guide)
13. [Quick Start Guide](#quick-start-guide)
14. [Troubleshooting FAQ](#troubleshooting-faq)
15. [Support Information](#support-information)

---

## Recent Feature Updates (Feb 5, 2026)

- **NEW: 4 Additional User Roles**: The system now supports 7 distinct user roles for better organizational structure:
  - **Manager**: Full business oversight with attendance tracking, sales reports, POS access, CCTV monitoring, inventory management, supplier management, and backup/restore
  - **Sales Promoter**: Dedicated POS access, price checking, and delivery order management
  - **Inventory Clerk**: Specialized inventory management, supplier coordination, and delivery processing
  - **Delivery Receiver**: Focused on receiving deliveries and supplier management with personal attendance tracking
- **Welcome Cards**: All dashboards now display personalized welcome messages showing the user's name and a friendly greeting
- **Personal Attendance Tracking**: Every role (Owner, Manager, Cashier, Sales Promoter, Inventory Clerk, Delivery Receiver) can now clock in/out with timestamp tracking
- **Complete Filipino Translations**: All new roles and features fully translated to Filipino ('fil') language
- **Modern Vibrant Theme**: Updated color palette with vibrant blue (#2563EB), teal accents (#06B6D4), improved card designs with rounded corners, and better visual hierarchy
- **Role-Specific Dashboards**: Each role has a dedicated dashboard with features tailored to their responsibilities
- **Separated Manager Role**: Manager now has their own dashboard separate from Owner with appropriate feature access

## Previous Feature Updates (Jan 28, 2026)

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
- **Windows:** `C:\Users\[YourUsername]\AppData\Local\smart_monitoring_system\databases\`
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
- ✅ Manage user accounts (create/edit/deactivate all user types)
- ✅ Manage products (add/edit/delete/restock)
- ✅ View all reports (sales, inventory, user activity, damage)
- ✅ Export data (CSV/PDF)
- ✅ Configure system settings
- ✅ Access all features
- ✅ Manage attendance records for all users

### Owner (Business Management)
- ✅ View detailed sales reports
- ✅ Monitor CCTV feeds
- ✅ Manage inventory
- ✅ Report damaged items
- ✅ Access POS terminal
- ✅ Backup & Restore database
- ✅ View analytics and charts
- ✅ Personal attendance tracking (clock in/out)
- ✅ E-Wallet management
- ❌ Cannot manage users
- ❌ Cannot delete products

### Manager (Business Operations & Oversight)
- ✅ Personal attendance tracking (clock in/out)
- ✅ View sales reports and analytics
- ✅ Access POS terminal
- ✅ Price checker access
- ✅ E-Wallet transfers (Premium/Enterprise package)
- ✅ Monitor CCTV feeds (Premium/Enterprise package)
- ✅ Manage inventory
- ✅ Supplier management (Premium/Enterprise package)
- ✅ Process delivery orders
- ✅ Backup & Restore database (Premium/Enterprise package)
- ❌ Cannot manage users
- ❌ Cannot delete products

### Sales Promoter (Customer-Facing Sales)
- ✅ Personal attendance tracking (clock in/out)
- ✅ Access POS terminal for sales
- ✅ Price checker functionality
- ✅ Create and manage delivery orders
- ❌ Cannot manage inventory
- ❌ Cannot view reports
- ❌ Cannot access admin features

### Inventory Clerk (Stock & Supplier Management)
- ✅ Personal attendance tracking (clock in/out)
- ✅ View and update inventory status
- ✅ Manage supplier relationships
- ✅ Process items for delivery
- ✅ Track stock levels and reorder points
- ❌ Cannot process sales
- ❌ Cannot view financial reports
- ❌ Cannot manage users

### Delivery Receiver (Receiving & Logistics)
- ✅ Personal attendance tracking (clock in/out)
- ✅ Receive and verify deliveries
- ✅ Coordinate with suppliers
- ✅ Update delivery status
- ❌ Cannot access POS
- ❌ Cannot view financial reports
- ❌ Cannot manage inventory levels

### Cashier (Point of Sale Operations)
- ✅ Process customer transactions
- ✅ Add items to cart
- ✅ Apply discounts
- ✅ Complete sales
- ✅ View sales log
- ✅ Access CCTV (with owner password)
- ✅ Personal attendance tracking (clock in/out)
- ❌ Cannot manage products
- ❌ Cannot view reports
- ❌ Cannot manage inventory

---

### Attendance

#### Personal Clock In / Clock Out (All Roles)

All user roles now have personal attendance tracking accessible from their respective dashboards:

**Roles with Attendance:**
- Owner
- Manager  
- Cashier
- Sales Promoter
- Inventory Clerk
- Delivery Receiver

**How to Use:**

1. **Access Attendance Dialog**
   - Look for the **"Attendance"** tile on your dashboard
   - Tap to open the personal attendance dialog

2. **Clock In** (Start of Shift)
   - Tap the **"Clock In"** button
   - System records:
     - Current timestamp
     - Your name and role
     - Device information
   - Success message appears

3. **Clock Out** (End of Shift)
   - Tap the **"Clock Out"** button when finishing work
   - System records end time
   - Total hours calculated automatically

4. **View Your Records**
   - Recent clock in/out times displayed in dialog
   - Shows current status (Clocked In / Clocked Out)

**For Supervisors (Admin/Owner):**
- Access **Admin Dashboard → Manage Attendance**
- View all users' attendance records
- Edit or correct entries if needed
- Export attendance logs (CSV) for payroll
- Add manual entries for missed clock-ins

**Note:** The attendance dialog shows a personalized greeting with your name and provides quick access to clock in/out without navigating away from your dashboard.

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

#### Add a New User (Owner, Manager, Cashier, Sales Promoter, Inventory Clerk, or Delivery Receiver)

1. **Navigate to User Management**
   - From Admin Dashboard → Click **"Manage Users"**

2. **Add New User**
   - Click the **"+"** icon (top-right corner)
   - Fill in user details:
     - Full Name
     - Email Address
     - Password
     - 4-digit PIN (for quick login)
     - **Select Role:**
       - **Owner** - Full business management access
       - **Manager** - Operations oversight with limited admin rights
       - **Cashier** - POS terminal operations
       - **Sales Promoter** - Customer sales and price checking
       - **Inventory Clerk** - Stock and supplier management
       - **Delivery Receiver** - Receiving and logistics

3. **Save User**
   - Click **"Save"** button
   - User can now login with their credentials
   - User will have access to their role-specific dashboard

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

#### Edit Product

1. In Product Management screen
2. Tap the product card
3. Modify details
4. Click **"Update"**

#### Restock Product

1. Tap product to edit
2. Update **"Quantity"** field to new stock level
3. System automatically records inventory movement
4. Click **"Save"**

#### Delete Product

1. Tap product to edit
2. Click **"Delete Product"** button
3. Confirm deletion
4. Product is removed from system

**⚠️ Warning:** Deleting a product with sales history may affect reports.

### 3. Viewing Reports

#### Sales Reports

1. Admin Dashboard → **"View Reports"** → **"Sales"** tab
2. **Select Date Range** using date picker
3. View:
   - Total sales amount
   - Transaction count
   - Average transaction value
   - Sales by payment method
4. **Export:**
   - Click **"Export CSV"** for spreadsheet
   - Click **"Export PDF"** for document

#### Inventory Reports

1. Navigate to **"Inventory"** tab
2. View:
   - Current stock levels
   - Low stock alerts (≤5 items)
   - Product movements
   - Restock history
3. Export options available

#### Damage Reports

1. Navigate to **"Damage Reports"** tab
2. View:
   - Damaged items list
   - Total quantity damaged
   - Total value lost
   - Damage reasons
3. Filter by date range
4. Export to CSV/PDF

#### User Activity Logs

1. Navigate to **"Activity Logs"** tab
2. View:
   - User login times
   - Actions performed
   - Timestamps
3. Filter by user or date

### Managing Attendance

#### Access Manage Attendance (Admin)

1. **Navigate to Manage Attendance**
   - From Admin Dashboard → Click **"Manage Attendance"**
2. **View attendance list**
   - See all users with today's status, last clock-in/out times, and role
3. **Mark or Edit Attendance**
   - Click a user row to add or correct a clock-in/out record
   - Add notes or reason for adjustments
4. **Attendance Reports & Export**
   - Filter by date range or user
   - Click **"Export CSV"** to download attendance logs for payroll or audits
5. **Bulk actions**
   - Import/Export attendance (CSV) and perform bulk corrections


### 4. System Settings

**Access Settings:**
- Click the **gear icon** (⚙️) in top-right corner

**Available Settings:**

**Language:**
- English (EN)
- Filipino (FIL)

**Theme Customization:**
- 9 preset colors (honeycomb picker)
- 24 additional custom colors
- **Modern vibrant palette:**
  - Primary Blue: #2563EB (vibrant blue)
  - Accent Teal: #06B6D4
  - Success Green: #10B981
  - Warning Orange: #F59E0B
  - Error Red: #EF4444
- Improved card designs with rounded corners (12px)
- Better button styling (48px height, 8px border radius)
- Light grey background (#F3F4F6) for better contrast
- Enhanced input fields with focus indicators

**Accessibility:**
- **Reduce Motion:** Minimizes animations
- Larger text options

**Data Management:**
- Export all data
- Clear old transactions
- Reset database (admin only)

### 5. Payroll Management

**Access:** Admin Dashboard → **"Payroll"**

The payroll system helps manage employee compensation, track work hours from attendance records, and calculate salaries with deductions and allowances.

#### Overview

**Features:**
- Automatic attendance-based calculations
- Support for multiple income types
- Government deductions (SSS, PhilHealth, HDMF/Pag-IBIG)
- Allowances and adjustments
- Loan deductions
- Monthly payroll periods
- Export to CSV for accounting

#### Create New Payroll Entry

1. **Access Payroll Screen**
   - Admin Dashboard → Click **"Payroll"** tile

2. **Click "Add Payroll"** (+ button)

3. **Select Employee**
   - Choose from user list
   - System shows available users

4. **Set Payroll Period**
   - Select Month and Year
   - System defaults to current month
   - Period automatically set from 1st to last day of month

5. **Auto-Calculate Attendance** (Optional)
   - System can pull attendance records for the period
   - Automatically calculates:
     - Total working days
     - Total hours worked
     - Regular hours vs overtime

6. **Enter Income Details:**

   **Regular Income:**
   - **Basic Rate:** ₱XXX.XX (daily or monthly rate)
   - **Regular Pay:** ₱XXX.XX (calculated from attendance)
   - **Overtime:** ₱XXX.XX (overtime hours pay)
   - **Night Differential:** ₱XXX.XX (night shift premium)
   - **Special Holiday:** ₱XXX.XX (holiday premium pay)
   - **COLA:** ₱XXX.XX (Cost of Living Allowance)
   - **13th Month Pay:** ₱XXX.XX (prorated)
   - **Adjustments:** ₱XXX.XX (corrections/bonuses)

   **Allowances (Non-taxable):**
   - **Meal Allowance:** ₱XXX.XX
   - **Lodging Allowance:** ₱XXX.XX
   - **Transportation Allowance:** ₱XXX.XX
   - **Other Allowances:** ₱XXX.XX

7. **Enter Deductions:**

   **Absences/Late/Undertime:**
   - **Absent Days:** ₱XXX.XX
   - **Late:** ₱XXX.XX
   - **Undertime:** ₱XXX.XX

   **Government Contributions:**
   - **SSS:** ₱XXX.XX (Social Security System)
   - **PhilHealth:** ₱XXX.XX (Health insurance)
   - **HDMF/Pag-IBIG:** ₱XXX.XX (Housing fund)
   - **Withholding Tax:** ₱XXX.XX

   **Other Deductions:**
   - **Insurance:** ₱XXX.XX
   - **Voluntary:** ₱XXX.XX (unions, associations)
   - **HMO:** ₱XXX.XX (health maintenance)
   - **Other:** ₱XXX.XX
   - **Loans:** ₱XXX.XX (company loans)

8. **Review Calculations**
   - System automatically computes:
     - **Gross Income:** Total of all income items
     - **Total Allowances:** Sum of allowances
     - **Total Deductions:** Sum of all deductions
     - **Net Pay:** Gross Income + Allowances - Deductions

9. **Save Payroll Entry**
   - Click **"Save"** button
   - Entry added to payroll list

#### View Payroll Records

**Payroll List Displays:**
- Employee name
- Payroll period (month/year)
- Gross income
- Total deductions
- Net pay
- Date created

**Actions:**
- Tap any payroll card to view full details
- View breakdown of all income and deductions
- Edit if corrections needed
- Delete if entered in error

#### Export Payroll Data

1. Click **"Export CSV"** button (top-right)
2. Choose save location
3. Opens in spreadsheet software:
   - All payroll entries
   - Detailed breakdown
   - Ready for accounting software

#### Payroll Calculation Examples

**Example 1: Full-time Employee**
```
Period: January 2026
Days Worked: 22 days (from attendance)
Basic Rate: ₱570/day
Regular Pay: ₱12,540 (22 × ₱570)
Overtime: ₱1,500
Allowances: ₱2,000

Gross Income: ₱14,040
Allowances: ₱2,000
Deductions:
  - SSS: ₱500
  - PhilHealth: ₱300
  - Pag-IBIG: ₱100
  - Withholding Tax: ₱800
Total Deductions: ₱1,700

Net Pay: ₱14,340
```

**Example 2: Part-time with Loan**
```
Period: January 2026
Days Worked: 15 days
Basic Rate: ₱500/day
Regular Pay: ₱7,500
Transportation Allowance: ₱500

Gross Income: ₱7,500
Allowances: ₱500
Deductions:
  - SSS: ₱300
  - PhilHealth: ₱200
  - Loan Payment: ₱1,000
Total Deductions: ₱1,500

Net Pay: ₱6,500
```

#### Best Practices

✅ **Do:**
- Create payroll entries at end of each pay period
- Verify attendance records before calculating
- Double-check government deduction rates
- Keep backup copies of payroll exports
- Document any manual adjustments
- Review calculations before finalizing

❌ **Don't:**
- Mix different pay periods in same entry
- Forget to include statutory deductions
- Skip attendance verification
- Delete payroll records (archive instead)

#### Troubleshooting

**Issue:** Attendance hours not showing
- **Solution:** Ensure employees clocked in/out properly during period
- Check attendance records in Manage Attendance screen

**Issue:** Incorrect deduction amounts
- **Solution:** Update government contribution rates in entry
- Verify employee classification (regular vs probationary)

**Issue:** Net pay seems wrong
- **Solution:** Review all income and deduction items
- Check for duplicate entries
- Verify calculation formula

---

## Owner Features

### 1. Sales Reports & Analytics

**Access:** Owner Dashboard → **"View Sales Reports"**

#### Daily Summary

1. **Select Date** using date picker
2. View dashboard showing:
   - **Daily Total Sales:** ₱X,XXX.XX
   - **Total Transactions:** XX
   - **Average Transaction:** ₱XXX.XX
   - **E-wallet Transfer Fees:** ₱XX.XX

3. **Export Daily Report:**
   - Click **"Export CSV"** for Excel
   - Click **"Export PDF"** for printable document

#### Date Range Reports

1. Click **"Select Date Range"** button
2. Choose start and end dates
3. View sales results
4. Export or analyze trends

#### Sales Charts

- Line chart showing sales trends
- Bar chart for payment methods
- Category breakdown

### 2. CCTV Monitoring

**Access:** Owner Dashboard → **"Monitor CCTV"**

#### Setup Camera Feed

1. In CCTV screen, click **"Settings"**
2. **Configure Camera URL:**
   - **RTSP Stream:** `rtsp://username:password@192.168.1.100:554/stream`
   - **HTTP Stream:** `http://192.168.1.100:8080/video`
   - **Local Video:** Select video file from device

3. **Save Configuration**

#### View Live Feed

1. Open CCTV Monitoring
2. Live feed displays automatically
3. **Controls:**
   - Play/Pause
   - Snapshot (capture image)
   - Zoom controls

#### Multiple Cameras (if configured)

- Swipe between camera feeds
- Grid view for multiple cameras
- Timestamp overlay

### 3. Inventory Management

**Access:** Owner Dashboard → **"View Inventory"**

#### Check Stock Levels

1. View all products with current quantities
2. **Low stock warnings** (red highlight for ≤5 items)
3. Search by name or barcode

#### View Inventory Movements

1. Tap any product
2. View **"Movement History"**:
   - Sales (quantity decreased)
   - Restocks (quantity increased)
   - Adjustments
   - Timestamps and references

#### Report Damaged Items

1. Click **"Damage Reports"** tab
2. Click **"Report Damage"** button
3. **Fill in details:**
   - Select product from dropdown
   - Enter quantity damaged
   - Select reason:
     - Expired
     - Broken
     - Contaminated
     - Lost
     - Other (specify)
4. Click **"Submit"**
5. Report is logged with timestamp

### 4. For Delivery Orders

**Access:** Owner Dashboard → **"For Delivery"** (also available for Manager, Sales Promoter, Inventory Clerk)

The For Delivery system manages customer orders that require delivery, tracks order status, and handles payment collection.

#### Overview

**Features:**
- Create delivery orders from POS
- Track pending and completed deliveries
- Manage customer information
- Payment status tracking
- Receipt generation
- Search and filter orders
- Export delivery reports

#### Create Delivery Order

**Method 1: From POS (During Checkout)**

1. **Add items to cart** in POS terminal
2. At checkout, select **"For Delivery"** option
3. **Enter Customer Information:**
   - **Customer Name:** Full name (required)
   - **Contact Number:** Phone number (required)
   - **Complete Address:** Delivery address (required)
   - **Delivery Notes:** Special instructions (optional)

4. **Select Payment Method:**
   - Cash on Delivery (COD)
   - Advance Payment (Full/Partial)

5. **Complete Order:**
   - Click **"Create Delivery Order"**
   - System generates order with unique ID
   - Receipt printed/saved
   - Order appears in For Delivery list

**Method 2: Direct from For Delivery Screen**

1. **Open For Delivery Screen**
   - From dashboard → Tap **"For Delivery"**

2. **Click "New Delivery Order"** button

3. **Add Products:**
   - Search and select products
   - Adjust quantities
   - Review cart

4. **Enter Customer Details:**
   - Same as Method 1 above

5. **Complete and Save**

#### View Delivery Orders

**Dashboard Statistics:**
- **Pending Payment:** Orders awaiting payment
- **Full Payment:** Orders fully paid
- **Total Orders:** All delivery orders

**Order List Shows:**
- Order ID (e.g., #DEL-2026-0001)
- Customer name
- Delivery address
- Total amount
- Payment status badge:
  - 🟠 **Pending** - Not yet paid
  - 🟢 **Completed** - Fully paid
  - 🟡 **Partial** - Partially paid
- Date and time created

#### Filter Orders

**Filter Options:**
- **All Orders:** Show everything
- **Pending Payment:** Only unpaid orders
- **Completed:** Only fully paid orders

**Search:**
- Search by customer name
- Search by order ID
- Search by phone number

#### Manage Delivery Order

**View Order Details:**
1. Tap any order card in list
2. View full information:
   - Customer name, contact, address
   - Items list with quantities and prices
   - Subtotal, discounts, total
   - Payment status
   - Delivery notes
   - Creation timestamp

**Mark as Paid:**
1. Open order details
2. Click **"Mark as Paid"** button
3. Select payment method:
   - Cash
   - GCash
   - Bank Transfer
   - Other
4. Order status updates to Completed
5. Payment recorded in system

**Print Receipt:**
1. In order details
2. Click **"Print Receipt"** button
3. Receipt shows:
   - Order number
   - Customer information
   - Items ordered
   - Delivery address
   - Payment status
   - Date/time

**Edit Order:**
1. Open order details
2. Click **"Edit"** button (if unpaid)
3. Modify:
   - Customer information
   - Delivery notes
   - Payment status
4. Save changes

**Cancel Order:**
1. Open order details
2. Click **"Cancel"** button
3. Provide cancellation reason
4. Confirm cancellation
5. Order marked as cancelled

#### Delivery Workflow Example

**Scenario: Customer Phone Order**

1. **Receive Call:**
   - Customer: "I want to order..."
   - Take order details

2. **Create Order in System:**
   - Go to For Delivery screen
   - Create new order
   - Add requested products
   - Enter customer details:
     - Name: Juan Dela Cruz
     - Phone: +639171234567
     - Address: 123 Main St, Barangay Center, City
     - Notes: "Call before delivery, prefer morning"

3. **Confirm with Customer:**
   - Total amount: ₱1,500
   - Delivery fee: ₱100 (if applicable)
   - Payment: Cash on Delivery

4. **Prepare Order:**
   - Print receipt
   - Pack items
   - Attach address label

5. **Schedule Delivery:**
   - Assign to delivery personnel
   - Note delivery time window

6. **Upon Delivery:**
   - Driver collects payment
   - Customer signs receipt
   - Mark order as "Paid" in system

7. **Record Completed:**
   - Order moves to Completed list
   - Payment added to daily sales

#### Export Delivery Reports

1. Click **"Export"** button (if available)
2. Choose format:
   - **CSV:** For spreadsheet analysis
   - **PDF:** For printed reports
3. Select date range
4. Report includes:
   - All delivery orders
   - Customer details
   - Payment status
   - Total sales from deliveries

#### For Delivery by Role

**Sales Promoter:**
- Create delivery orders
- View order status
- Contact customers
- Process payments

**Inventory Clerk:**
- View pending orders
- Prepare items for delivery
- Mark as "Ready for Pickup"
- Track inventory for deliveries

**Manager/Owner:**
- Full access to all features
- View analytics and reports
- Manage all orders
- Export data

#### Tips for Efficient Delivery Management

✅ **Best Practices:**
- Verify customer contact number before saving
- Include landmarks in delivery address
- Add estimated delivery time in notes
- Confirm orders via SMS/call
- Update payment status immediately after collection
- Print receipt before packing
- Assign delivery personnel via notes
- Review completed orders weekly

✅ **Customer Service:**
- Call customer if address unclear
- Send SMS with delivery time
- Confirm successful delivery
- Handle complaints professionally
- Keep records of all communications

#### Troubleshooting

**Issue:** Can't find order
- **Solution:** Use search function, try order ID or customer name

**Issue:** Wrong customer address
- **Solution:** Edit order (if not yet delivered), update address field

**Issue:** Customer wants to modify order
- **Solution:** Edit order if pending, add/remove items, update total

**Issue:** Payment not updating
- **Solution:** Check payment status field, ensure "Mark as Paid" was clicked

**Issue:** Receipt not printing
- **Solution:** Check printer connection, try "Print Receipt" again from order details

### 5. Access POS Terminal

Owner can access the POS terminal if needed:
1. Owner Dashboard → **"POS Terminal"**
2. Process sales same as cashier
3. Sales are recorded under owner's name

---

## Manager Features

### Dashboard Overview

**Welcome Card:** Displays personalized greeting "Welcome, [Your Name]!" with Manager Dashboard title

**Access:** Manager Dashboard includes:
- **Attendance:** Personal clock in/out tracking
- **Sales Reports:** View business analytics and trends
- **POS Terminal:** Process customer transactions
- **Price Checker:** Scan and verify product prices
- **E-Wallet:** Transfer funds (Premium/Enterprise package)
- **CCTV Monitoring:** View security feeds (Premium/Enterprise package)
- **Inventory:** Check and update stock levels
- **Supplier Management:** Coordinate with suppliers (Premium/Enterprise package)
- **For Delivery:** Manage delivery orders
- **Backup & Restore:** Database management (Premium/Enterprise package)

### 1. Personal Attendance

1. **Clock In:** Tap **"Attendance"** tile → **"Clock In"** button
2. System records start time and your details
3. **Clock Out:** Return to Attendance → **"Clock Out"** when shift ends
4. View your recent clock in/out history in the dialog

### 2. Sales Reports & Analytics

**Access:** Manager Dashboard → **"Sales Reports"**

- View daily, weekly, monthly sales summaries
- Track transaction counts and averages
- Monitor payment method distribution
- Analyze sales trends with charts
- Export reports to CSV/PDF

### 3. POS & Customer Service

- Full access to POS terminal for sales processing
- Use price checker to assist customers
- Create delivery orders for customer purchases
- Same functionality as Cashier role for transactions

### 4. Operations Management

**Inventory Oversight:**
- Check stock levels and low stock alerts
- View product details and categories
- Monitor inventory movements
- Coordinate restocking needs

**CCTV Monitoring:** (Premium/Enterprise)
- Access security camera feeds
- Monitor store premises
- Review timestamps and recordings

**Supplier Management:** (Premium/Enterprise)
- View supplier list and contact information
- Coordinate deliveries and restocks
- Manage supplier relationships

### 5. Database Backup & Restore (Premium/Enterprise)

- Create database backups at end of shift
- Export database to external storage
- Restore from backups if needed
- Same capabilities as Owner role

---

## Sales Promoter Features

### Dashboard Overview

**Welcome Card:** Displays "Welcome, [Your Name]!" with Sales Promoter Dashboard title

**Access:** Sales Promoter Dashboard includes:
- **Attendance:** Personal clock in/out tracking
- **Cashier POS:** Process customer sales
- **Price Checker:** Verify product prices and availability
- **For Delivery:** Create and manage delivery orders

### 1. Personal Attendance

1. Tap **"Attendance"** tile on dashboard
2. **Clock In** at start of shift
3. **Clock Out** at end of shift
4. View your attendance history

### 2. Point of Sale Operations

**Access:** Sales Promoter Dashboard → **"Cashier POS"**

- Add products to cart (tap, search, or scan)
- Apply discounts to items
- Process checkout with multiple payment methods
- Generate receipts for customers
- View sales log and transaction history

**Perfect For:**
- Floor sales representatives
- Customer service staff
- Product demonstrators
- Promotional event staff

### 3. Price Checker

**Access:** Sales Promoter Dashboard → **"Price Checker"**

**Use Cases:**
- Quick price verification for customers
- Check product availability
- View stock levels without accessing inventory
- Scan barcodes for instant information

**How to Use:**
1. Tap **"Scan"** to use barcode scanner
2. Or use **"Search"** to find products by name
3. View product details:
   - Product name and category
   - Current selling price
   - Stock quantity
   - Barcode number
4. Large, easy-to-read price display for customer visibility

### 4. Delivery Orders

**Access:** Sales Promoter Dashboard → **"For Delivery"**

- Create delivery orders for customer purchases
- Capture customer information (name, contact, address)
- Add delivery notes and special instructions
- Track delivery status
- View order history

---

## Inventory Clerk Features

### Dashboard Overview

**Welcome Card:** Shows "Welcome, [Your Name]!" with Inventory Clerk Dashboard title

**Access:** Inventory Clerk Dashboard includes:
- **Attendance:** Personal clock in/out tracking
- **Inventory Status:** View and update stock levels
- **Supplier Management:** Coordinate with suppliers
- **For Delivery:** Process items for delivery

### 1. Personal Attendance

1. Access **"Attendance"** from dashboard
2. **Clock In** when starting work
3. **Clock Out** when leaving
4. Track your work hours automatically

### 2. Inventory Management

**Access:** Inventory Clerk Dashboard → **"Inventory Status"**

**Responsibilities:**
- Monitor stock levels across all products
- Identify low stock items (≤5 units)
- Update quantities after receiving deliveries
- Track inventory movements
- Coordinate restocking needs

**How to Update Stock:**
1. Search for product by name or barcode
2. Tap product card to view details
3. Click **"Update Stock"** button
4. Enter new quantity
5. System records movement with timestamp

**Inventory Monitoring:**
- View all products with current stock
- Filter by category
- Search by name or barcode
- Red highlight for low stock warnings
- View movement history per product

### 3. Supplier Management

**Access:** Inventory Clerk Dashboard → **"Supplier Management"**

**Functions:**
- View all registered suppliers
- Access supplier contact information
- Coordinate delivery schedules
- Track supplier performance
- Manage supplier relationships

**Typical Workflow:**
1. Check inventory for low stock items
2. Contact suppliers via the supplier management screen
3. Arrange deliveries
4. Update stock levels when items arrive
5. Process received items for delivery if needed

### 4. For Delivery Processing

**Access:** Inventory Clerk Dashboard → **"For Delivery"**

- View pending delivery orders
- Prepare items for customer delivery
- Update order status
- Coordinate with delivery personnel
- Mark orders as ready for pickup

---

## Delivery Receiver Features

### Dashboard Overview

**Welcome Card:** Displays "Welcome, [Your Name]!" with Delivery Receiver Dashboard title

**Access:** Delivery Receiver Dashboard includes:
- **Attendance:** Personal clock in/out tracking
- **Supplier Management:** Manage supplier relationships

### 1. Personal Attendance

1. Tap **"Attendance"** tile on dashboard
2. **Clock In** when arriving at work
3. **Clock Out** at end of shift
4. View your attendance records

### 2. Supplier Management

**Access:** Delivery Receiver Dashboard → **"Supplier Management"**

**Primary Responsibilities:**
- Receive deliveries from suppliers
- Verify delivered quantities against orders
- Check quality of received items
- Communicate with suppliers about deliveries
- Report discrepancies or issues

**Workflow:**
1. **Before Delivery:**
   - Review expected deliveries in supplier management
   - Check supplier contact information
   - Prepare receiving area

2. **During Delivery:**
   - Verify delivery against order
   - Count and inspect items
   - Note any damages or shortages
   - Sign off on receipt

3. **After Delivery:**
   - Notify Inventory Clerk to update stock levels
   - Report any issues to management
   - Update delivery records in system

**Collaboration:**
- Works closely with Inventory Clerk for stock updates
- Reports to Manager or Owner about delivery issues
- Coordinates with suppliers for schedule changes

---

## Cashier Features

### 1. Using the POS Terminal

**Access:** Cashier Dashboard → **"Open POS"**

#### Process a Sale

**Step 1: Add Items to Cart**

**Method A: Tap Product Tiles**
- Browse product grid
- Tap product tile to add to cart
- Long-press product image to view larger picture with zoom

**Method B: Use Search Bar**
- Type product name or category in search bar
- Results filter in real-time
- Tap product to add

**Method C: Scan Barcode**
- Click barcode icon
- Scan product barcode with camera
- Product automatically added to cart

**Step 2: Adjust Quantities**
- In cart sheet, use **+** and **-** buttons
- Or tap quantity to enter manually
- Remove item by reducing to 0

**Step 3: Apply Discounts (Optional)**
- Tap discount icon on cart item
- Enter discount percentage (0-100%)
- Or enter fixed amount discount
- Discount applies to that item only

**Step 4: Review Cart**
- Check all items and quantities
- Verify total amount
- **Cart displays:**
  - Subtotal
  - Total Discount
  - **Final Total**

**Step 5: Checkout**

1. Click **"Checkout"** button
2. **Select Payment Method:**
   - **Cash:** Customer pays with cash
   - **Card:** Credit/Debit card payment
   - **E-wallet (Cash-In):** GCash, Maya, etc. (customer loads)
   - **E-wallet (Cash-Out):** Customer withdraws
   - **Multiple Payment Methods:** Split payment

3. **Enter Amount (for Cash)**
   - Enter amount received
   - System calculates change

4. **Complete Sale**
   - Click **"Complete Sale"**
   - Receipt generated
   - Cart cleared automatically
   - Stock quantities updated

#### Low Stock Warnings

- If item quantity ≤ 5 after sale, warning appears
- Notify admin/owner to restock

#### View Sales Log

1. In POS screen, click **"Sales Log"** button
2. View all completed transactions
3. See sale details:
   - Sale number
   - Items sold
   - Total amount
   - Payment method
   - Timestamp

### 2. Access CCTV from Sales Log

**Requires Owner Password:**

1. In Sales Log, tap camera icon next to any sale
2. **Owner Password Dialog appears**
3. Enter owner password
4. If correct, CCTV footage opens at sale timestamp

**Purpose:** Verify transactions or investigate discrepancies

### 3. Product Image Viewing

**View Enlarged Product Images:**

1. Long-press any product tile with an image
2. Enlarged view opens in dialog
3. **Zoom controls:**
   - Pinch to zoom (0.5x to 4x)
   - Pan around image
   - Tap outside to close

**Use Case:** Verify product details or show customer

---

## Backup & Restore Guide

### Why Backup is Important

**Protect Your Data From:**
- Hardware failure
- Software errors
- Accidental deletion
- System crashes
- Data corruption

**Best Practices:**
- ✅ Daily backups (end of business day)
- ✅ Before major changes (bulk updates)
- ✅ Before system updates
- ✅ Store backups in multiple locations

### How to Create a Backup

**Access:** Owner Dashboard → **"Backup & Restore"**

#### Method 1: Create Internal Backup

1. Click **"Create Backup"** button
2. System creates timestamped backup automatically
3. Success message confirms creation
4. Backup stored in app's backup directory

**Backup Filename Format:**
```
backup_2025-12-19_143022.db
```

#### Method 2: Export Database to External Location

1. Click **"Export Database"** button
2. **File picker opens**
3. **Choose save location:**
   - USB drive
   - Cloud storage (Google Drive, Dropbox)
   - Network drive
   - External hard drive

4. **Choose filename** (or keep default):
   ```
   pos_system_export_2025-12-19_143022.db
   ```

5. Click **"Save"**
6. Database exported successfully

**Recommended Storage:**
- Keep 3 copies: Internal + USB + Cloud
- Rotate weekly backups
- Test restore periodically

### How to Restore a Backup

#### Method 1: Restore from Internal Backup

1. Open **"Backup & Restore"** screen
2. **View list of available backups:**
   - Sorted by date (newest first)
   - Shows timestamp and file size

3. **Select backup to restore:**
   - Tap the backup card
   - Click **"Restore"** button

4. **⚠️ WARNING Dialog:**
   ```
   Restoring will replace ALL current data.
   This action cannot be undone.
   Create a backup before proceeding?
   ```

5. **Confirm restoration:**
   - Click **"Yes, Restore"**

6. **System restores data:**
   - Progress indicator shows status
   - All products, sales, users restored

7. **Restart the app:**
   - Close and reopen the application
   - Login to verify restored data

#### Method 2: Import Database from External File

1. Open **"Backup & Restore"** screen
2. Click **"Import Database"** button
3. **File picker opens**
4. **Navigate to backup file:**
   - Select `.db` file from USB/cloud
   - Example: `pos_system_export_2025-12-15.db`

5. **Confirm import:**
   - ⚠️ Warning about data replacement
   - Click **"Import"**

6. **System imports database:**
   - Replaces current database
   - Shows progress

7. **Restart the app**
   - Close and reopen
   - Verify all data restored

### Backup Schedule Recommendations

| Frequency | When | Method |
|-----------|------|--------|
| **Daily** | End of business day | Internal backup |
| **Weekly** | Every Sunday | Export to USB drive |
| **Monthly** | 1st of month | Export to cloud storage |
| **Before Updates** | Any system update | Both internal + external |

### What is Included in Backups

✅ **Products:** All product details, images, prices  
✅ **Sales:** Complete transaction history  
✅ **Users:** All user accounts (admin, owners, cashiers)  
✅ **Inventory:** Stock levels, movements  
✅ **Damage Reports:** All damage records  
✅ **Settings:** Theme, language preferences  

### Troubleshooting Backup Issues

**Backup Failed:**
- Check available disk space (need 50MB minimum)
- Ensure no other app is using database
- Restart app and try again

**Cannot Find Backup File:**
- Check backup directory in file explorer
- Search for `*.db` files
- Ensure backup wasn't deleted

**Restore Failed:**
- Verify backup file is not corrupted
- Ensure file has `.db` extension
- Try restoring older backup

**After Restore, Data is Old:**
- Verify you selected correct backup file
- Check backup timestamp
- May need to re-enter recent transactions

---

## Quick Start Guide

### For First-Time Setup (15 minutes)

#### Step 1: Create Admin Account (3 min)

1. Launch app
2. Click **"Create Admin Account"**
3. Fill in:
   - Name: `Store Admin`
   - Email: `admin@yourstore.com`
   - Phone: `+639171234567`
   - Password: `Admin@2025`
4. Click **"Create Account"**

#### Step 2: Login as Admin (1 min)

1. Select **Admin Login**
2. Enter email + password
3. Click **"Login"**

#### Step 3: Add Sample Products (5 min)

1. Admin Dashboard → **"Manage Products"**
2. Click **"Add Product"**
3. **Example Product 1:**
   - Name: `Coca-Cola 1.5L`
   - Barcode: `4800888175939`
   - Category: `Beverages`
   - Buying Price: `45.00`
   - Selling Price: `60.00`
   - Quantity: `50`
4. Click **"Save"**
5. Add 2-3 more products

#### Step 4: Create User Accounts (5 min)

**Create Multiple User Types:**

1. Admin Dashboard → **"Manage Users"**
2. Click **"+"** icon

**Example 1: Create Cashier**
- Name: `Cashier 1`
- Email: `cashier@yourstore.com`
- Password: `Cashier@123`
- PIN: `1234`
- Role: **Cashier**
- Click **"Save"**

**Example 2: Create Sales Promoter**
- Name: `Sales Promoter 1`
- Email: `promoter@yourstore.com`
- Password: `Promoter@123`
- PIN: `2345`
- Role: **Sales Promoter**
- Click **"Save"**

**Example 3: Create Inventory Clerk**
- Name: `Inventory Clerk 1`
- Email: `inventory@yourstore.com`
- Password: `Inventory@123`
- PIN: `3456`
- Role: **Inventory Clerk**
- Click **"Save"**

**Example 4: Create Manager**
- Name: `Store Manager`
- Email: `manager@yourstore.com`
- Password: `Manager@123`
- PIN: `9999`
- Role: **Manager**
- Click **"Save"**

#### Step 5: Test POS Transaction (4 min)

1. Logout from admin
2. Login as Cashier or Sales Promoter
3. **Check Welcome Card** - Should show your name
4. **Clock In** - Tap Attendance tile → Clock In
5. Open POS Terminal
6. Add products to cart
7. Complete a test sale
8. Verify receipt generated
9. **Clock Out** - Return to Attendance → Clock Out

✅ **System is now ready for use!**

### Role-Specific First Time Setup

**For Manager:**
1. Login and see personalized welcome card
2. Clock in for attendance tracking
3. Explore Sales Reports
4. Test POS and Price Checker
5. Check Inventory Status

**For Sales Promoter:**
1. Login to Sales Promoter Dashboard
2. Clock in to start shift
3. Use Price Checker to scan demo products
4. Practice POS transactions
5. Create a test delivery order

**For Inventory Clerk:**
1. Login to Inventory Clerk Dashboard
2. Clock in for work
3. Review Inventory Status
4. Check supplier management screen
5. Practice updating stock levels

**For Delivery Receiver:**
1. Login to Delivery Receiver Dashboard
2. Clock in
3. Familiarize with Supplier Management
4. Review delivery coordination process

### Daily Operations Checklist

**Morning (Opening):**
- [ ] All users login to their respective dashboards
- [ ] Everyone clocks in for attendance
- [ ] Cashier/Sales Promoter verify POS is working
- [ ] Inventory Clerk checks stock levels
- [ ] Manager reviews yesterday's sales

**During Business Hours:**
- [ ] Cashier/Sales Promoter process customer transactions
- [ ] Sales Promoter uses Price Checker for customers
- [ ] Inventory Clerk monitors stock and coordinates with suppliers
- [ ] Delivery Receiver handles incoming deliveries
- [ ] Manager oversees operations and handles issues

**Evening (Closing):**
- [ ] Count cash register
- [ ] Verify sales total matches cash
- [ ] All users clock out
- [ ] Manager/Owner creates daily backup
- [ ] Owner exports sales report
- [ ] Logout from all accounts

### Common Tasks Quick Reference

| Task | Who | Steps |
|------|-----|-------|
| **Add Product** | Admin | Admin → Manage Products → + → Fill details → Save |
| **Restock Item** | Admin/Inventory Clerk | Inventory Status → Select product → Update quantity → Save |
| **Process Sale** | Cashier/Sales Promoter/Manager | POS → Add items → Checkout → Payment → Complete |
| **Check Price** | Sales Promoter | Price Checker → Scan/Search product → View details |
| **Clock In/Out** | All Roles | Dashboard → Attendance → Clock In/Out |
| **View Sales** | Owner/Manager | Sales Reports → Select date → View details |
| **Create Backup** | Owner/Manager | Backup & Restore → Create Backup |
| **Report Damage** | Owner/Manager/Admin | Inventory → Damage Reports → Report Damage |
| **Receive Delivery** | Delivery Receiver | Coordinate via Supplier Management |
| **Update Stock** | Inventory Clerk | Inventory Status → Select product → Update |
| **Change Theme** | Any user | Settings (⚙️) → Select color (modern vibrant palette) |
| **Change Language** | Any user | Settings → Language → EN or FIL |

---

## Troubleshooting FAQ

### Login Issues

**Q: Forgot admin password?**

**A:** Use password recovery:
1. Click **"Forgot Password?"** on login screen
2. Enter admin email
3. Verify OTP sent to email
4. Enter phone number
5. Verify SMS code
6. Set new password

**Q: "Invalid credentials" error?**

**A:** 
- Verify caps lock is OFF
- Check email/phone format
- Ensure password is correct
- Try toggling password visibility (eye icon)

**Q: Cannot create admin account?**

**A:**
- Email must be valid format (name@domain.com)
- Phone must start with +63
- Password minimum 8 characters
- Ensure all fields are filled

### POS Issues

**Q: Product not found in POS?**

**A:**
- Verify product was added in Admin → Manage Products
- Check product is not deleted
- Try searching by barcode or name
- Refresh product list

**Q: Barcode scanner not working?**

**A:**
- Grant camera permission to app
- Ensure barcode is clear and visible
- Try manual entry
- Restart app if camera freezes

**Q: "Insufficient stock" error?**

**A:**
- Product quantity is 0 or less than requested
- Restock product via Admin → Manage Products
- Check inventory movements for discrepancies

**Q: Checkout button disabled?**
 
**A:**
- Cart is empty (add items first)
- Check network connection (if using cloud sync)
- Verify all items have valid prices

### Report Issues

**Q: Sales report shows wrong date range?**

**A:**
- Verify date range selection is correct
- Ensure end date is AFTER start date
- System now includes entire end date (fixed in v1.0)
- Try refreshing report

**Q: Export CSV/PDF not working?**

**A:**
- Grant file write permissions
- Ensure sufficient storage space
- Try exporting smaller date range
- Check anti-virus isn't blocking

### Backup Issues

**Q: Backup failed to create?**

**A:**
- Check free disk space (need 50MB+)
- Close app completely and reopen
- Ensure database isn't corrupted
- Try manual export instead

**Q: Cannot restore backup?**

**A:**
- Verify backup file has `.db` extension
- Ensure backup file is not corrupted
- Try different backup file
- Check file isn't opened by another program

**Q: After restore, data seems old?**

**A:**
- Check backup timestamp
- You may have restored an older backup
- Recent transactions may need to be re-entered
- Always verify backup date before restoring

### Performance Issues

**Q: App is slow or laggy?**

**A:**
- Enable **"Reduce Motion"** in Settings
- Close other apps running in background
- Clear old transactions (Admin only)
- Restart device

**Q: Database getting too large?**

**A:**
- Export old sales to CSV
- Archive transactions older than 1 year (Admin feature)
- Regular cleanup recommended every 6 months

### CCTV Issues

**Q: CCTV feed not loading?**

**A:**
- Verify camera URL is correct
- Check camera is powered on and connected
- Test URL in browser first
- Ensure network connectivity
- Check firewall settings

**Q: "Owner password required" for CCTV?**

**A:**
- This is a security feature
- Only owners can authorize CCTV access
- Contact owner for password
- Owner can view without password

---

## Support Information

### Contact Details

**Developer/Vendor:**
- **Company:** [Your Company Name]
- **Email:** support@smartstoremonitoring.com
- **Phone:** +63 XXX XXX XXXX
- **Website:** www.smartstoremonitoring.com

**Business Hours:**
- Monday - Friday: 9:00 AM - 6:00 PM (PHT)
- Saturday: 10:00 AM - 3:00 PM
- Sunday: Closed

**Emergency Support:**
- Critical issues: support@smartstoremonitoring.com
- Response time: Within 24 hours
- Phone support for enterprise customers

### Getting Help

**📧 Email Support:**
- For general inquiries: info@smartstoremonitoring.com
- For technical issues: support@smartstoremonitoring.com
- For billing: billing@smartstoremonitoring.com

**💬 Live Chat:**
- Available on website during business hours
- Average response time: 5-10 minutes

**📱 Social Media:**
- Facebook: @SmartStoreMonitoring
- Twitter: @SmartStorePOS
- Instagram: @smartstoremonitoring

### Requesting Updates

**Software Updates:**
- Check for updates: Settings → About → Check for Updates
- Automatic updates can be enabled in settings
- Update notifications appear on dashboard

**Feature Requests:**
- Submit via email with subject: "Feature Request"
- Include detailed description
- Community voting on features (website)

### Reporting Bugs

**When reporting bugs, include:**
1. Device/OS information (Windows 10, Android 12, etc.)
2. Steps to reproduce the issue
3. Screenshots or error messages
4. Your user role (Admin/Owner/Cashier)
5. App version number (Settings → About)

**Bug Report Email:**
```
To: support@smartstoremonitoring.com
Subject: Bug Report - [Brief Description]

Device: Windows 10
App Version: 1.0.0
User Role: Cashier

Issue: [Describe the problem]
Steps to Reproduce:
1. Step one
2. Step two
3. Step three

Expected Result: [What should happen]
Actual Result: [What actually happens]

Screenshots: [Attached]
```

### Update Schedule

**Release Cycle:**

| Version Type | Frequency | Content |
|--------------|-----------|---------|
| **Major Updates** | Every 6 months | New features, major improvements |
| **Minor Updates** | Monthly | Bug fixes, small enhancements |
| **Security Patches** | As needed | Critical security fixes |
| **Hotfixes** | As needed | Emergency bug fixes |

**Upcoming Features (Roadmap):**

**Q1 2026:**
- Cloud synchronization
- Multi-store support
- Advanced analytics dashboard
- Mobile app improvements

**Q2 2026:**
- Customer loyalty program
- SMS notifications
- Automated inventory reordering
- Enhanced reporting tools

**Q3 2026:**
- AI-powered sales forecasting
- Facial recognition for CCTV
- Voice commands
- Integration with accounting software

**Q4 2026:**
- E-commerce integration
- Supplier management
- Employee scheduling
- Payroll integration

### Training & Resources

**Video Tutorials:**
- YouTube Channel: SmartStore POS Tutorials
- Complete training series (30+ videos)
- Beginner to advanced levels

**Documentation:**
- User Manual (this document)
- API Documentation (for developers)
- Integration guides
- Best practices guide

**Webinars:**
- Monthly live training sessions
- Q&A with product team
- Register at: www.smartstoremonitoring.com/webinars

**Community Forum:**
- Join: forum.smartstoremonitoring.com
- Ask questions
- Share tips and tricks
- Connect with other users

### Warranty & License

**Software License:**
- Single installation per license
- Perpetual license (lifetime use)
- Free updates for 1 year
- Support included for 1 year

**Extended Support:**
- Available for purchase after 1 year
- Enterprise support packages available
- Custom development on request

**Data Privacy:**
- All data stored locally on your device
- No cloud uploads without explicit permission
- GDPR compliant
- Data encryption available

---

## Appendix

### Keyboard Shortcuts (Desktop)

| Shortcut | Action |
|----------|--------|
| `Ctrl + N` | New product (Admin) |
| `Ctrl + S` | Save current form |
| `Ctrl + F` | Search/Filter |
| `Ctrl + P` | Print/Export PDF |
| `Ctrl + B` | Create backup |
| `F5` | Refresh data |
| `Esc` | Close dialog/Cancel |

### Default Categories

Pre-configured product categories:
- Beverages
- Snacks
- Personal Care
- Household Items
- Electronics
- Clothing
- Food & Groceries
- Health & Medicine
- Office Supplies
- Other

### Payment Methods Supported

- ✅ Cash
- ✅ Credit Card
- ✅ Debit Card
- ✅ E-wallet (GCash, Maya, PayMaya)
- ✅ Cash-In (E-wallet load)
- ✅ Cash-Out (E-wallet withdrawal)
- ✅ Multiple Payment Methods (split payment)

### System Limits

| Item | Limit |
|------|-------|
| Maximum Products | Unlimited* |
| Maximum Users | 100 |
| Maximum Sales per Day | Unlimited* |
| Maximum Backup Size | 2GB |
| Product Name Length | 100 characters |
| Product Image Size | 5MB per image |

*Subject to device storage and performance

### Glossary

**Barcode:** Unique identifier for products (can be scanned)  
**Cart:** Temporary collection of items before checkout  
**Cashier:** User role for processing sales  
**CCTV:** Closed-circuit television for monitoring  
**CSV:** Comma-separated values file format (for Excel)  
**Database:** Storage system for all application data  
**E-wallet:** Digital payment method (GCash, Maya, etc.)  
**Inventory:** Stock of products available for sale  
**Owner:** User role with business management access  
**PDF:** Portable document format (for reports)  
**PIN:** Personal identification number (4 digits)  
**POS:** Point of Sale (transaction processing system)  
**Reorder Level:** Minimum stock before warning appears  
**Sale:** Completed transaction with customer  
**SKU:** Stock keeping unit (product identifier)  

---

## Version History

**Version 1.0 (December 19, 2025)**
- Initial release
- Core POS functionality
- User management (Admin, Owner, Cashier)
- Inventory management
- Sales reporting
- CCTV integration
- Backup & restore
- Multi-language support (English, Filipino)
- Theme customization
- Date range fixes for reports

---

## Legal & Compliance

**Copyright © 2025 [Your Company Name]. All rights reserved.**

This software and documentation are protected by copyright law. Unauthorized reproduction or distribution of this software, or any portion of it, may result in severe civil and criminal penalties.

**Terms of Use:**
- Licensed for commercial use
- Not for resale or redistribution
- Support terms apply

**Privacy Policy:**
- Data collected: None (all local storage)
- No telemetry or tracking
- User data remains on-device
- Optional cloud sync available

**Disclaimer:**
This software is provided "as is" without warranty of any kind. The vendor is not liable for any damages resulting from the use of this software.

---

## End of User Manual

**Thank you for choosing Smart Store Monitoring System!**

For additional support, visit: **www.smartstoremonitoring.com**

*Last Updated: December 19, 2025 | Version 1.0*
