import 'locale_controller.dart';

class AppLocalizations {
  // Keys and translations
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Smart Store Monitoring System',
      'welcome': 'Welcome!',
      'email': 'Email',
      'contact': 'Contact',
      'password': 'Password',
      'login': 'Continue to Login',
      'user_manual': 'User Manual',
      'export_pdf_success': 'PDF exported successfully',
      'help_support': 'Help & Support',
      'export_pdf': 'Export PDF',
      'generating_pdf': 'Generating PDF...',
      'pdf_exported_to': 'PDF exported to: {path}',
      'pdf_saved_to_downloads': 'PDF saved to Downloads folder',
      'export_failed': 'Export failed: {error}',
      'contents': 'Contents',
      'sections_count': '{n} sections',
      'invalid': 'Invalid Email or Password',
      'google_signin_unavailable':
          'Google Sign-In is not available in offline mode',
      'store_name': 'Smart Store Monitoring System',
      'settings': 'Settings',
      'theme': 'Theme Color',
      'red': 'Red',
      'yellow': 'Yellow',
      'blue': 'Blue',
      'english': 'English',
      'filipino': 'Filipino',
      'language': 'Language',
      'loading': 'Loading...',
      // Admin
      'admin_dashboard': 'Admin Dashboard',
      'sign_out': 'Sign Out',
      'manage_users': 'Manage Users',
      'manage_products': 'Manage Products',
      'reports_coming': 'Reports (Coming Soon)',
      'manage_users_title': 'Manage Users',
      'owner': 'Owner',
      'cashier_role': 'Cashier',
      'manager': 'Manager',
      'sales_promoter': 'Sales Promoter',
      'inventory_clerk': 'Inventory Clerk',
      'delivery_receiver': 'Delivery Receiver',
      'other_role': 'Others',
      'manage_users_placeholder': 'User Management UI Placeholder',
      'manage_products_title': 'Manage Products',
      'manage_products_placeholder': 'Product Management UI Placeholder',
      'manage_attendance': 'Manage Attendance',
      'manage_payroll': 'Manage Payroll',
      'payroll': 'Payroll',
      'attendance_for': 'Attendance for {name}',
      'clear_records': 'Clear Records',
      'confirm_clear_attendance':
          'Are you sure you want to clear attendance records for this user?',
      'apply': 'Apply',
      // Owner
      'owner_dashboard': 'Store Owner',
      'customer_management': 'Customer Management',
      'loyalty_rewards': 'Loyalty Rewards',
      'search_customers': 'Search customers...',
      'no_customers': 'No customers found',
      'add_customer': 'Add Customer',
      'edit_customer': 'Edit Customer',
      'adjust_points': 'Adjust Points',
      'deactivate_customer': 'Deactivate Customer',
      'points_history': 'Points History',
      'current_points': 'Current Points',
      'points': 'Points',
      'estimated_loyalty_points': 'Estimated loyalty points',
      'estimated_loyalty_value': '₱{value} value',
      'redemption_minimum_notice': 'Redemption requires at least {n} points.',
      'scan_loyalty_barcode': 'Scan Loyalty Barcode',
      'enter_loyalty_barcode': 'Enter Loyalty Barcode',
      'loyalty_barcode_id': 'Loyalty Barcode ID',
      'loyalty_customer_not_found':
          'Customer not found for this loyalty barcode',
      'loyalty_customer_linked': 'Loyalty customer linked: {name}',
      'apply_loyalty_redemption': 'Apply loyalty redemption',
      'redeemable_points': 'Redeemable Points',
      'loyalty_redemption': 'Loyalty Redemption',
      'loyalty_redemption_not_eligible':
          'Customer is not eligible for redemption on this checkout',
      'award': 'Award',
      'redeem': 'Redeem',
      'barcode_copied': 'Barcode copied to clipboard',
      'barcode_generated_for_customer':
          'Barcode generated. Give this code to the customer for loyalty use.',
      'view_sales_reports': 'View Sales Reports',
      'monitor_cctv': 'Monitor CCTV',
      'inventory_status': 'Inventory Status',
      // Manager
      'manager_dashboard': 'Manager',
      // Cashier
      'cashier_dashboard': 'Cashier Dashboard',
      'attendance': 'Attendance',
      'next': 'Next',
      'no_records': 'No records yet',
      'open_pos': 'Open POS Terminal',
      'price_checker': 'Price Checker',
      'scan_check_product_prices': 'Scan & Check Product Prices',
      'cashier_pos': 'Cashier POS',
      'item_out_of_stock': 'Item out of stock',
      'only_x_left': 'Only {n} left in stock',
      'stock_label': 'Stock: {n}',
      'cart_empty': 'Cart is empty',
      'cart': 'Cart',
      'total_prefix': 'Total: ₱',
      'checkout': 'Checkout',
      'close': 'Close',
      'sale_recorded': 'Sale recorded (ID: {id})',
      'not_enough_stock_for': 'Not enough stock for {name}',
      'sales_log_title': 'Sales Log (Local Demo)',
      'no_sales_yet': 'No sales yet',
      'sale_label': 'Sale {id}',
      'sales_log_tooltip': 'Sales Log',
      'open_cart_tooltip': 'Open Cart',
      'cart_count': 'Cart ({count})',
      'payment_method': 'Payment Method',
      'select_payment': 'Select Payment Method',
      'cash': 'Cash',
      'gcash': 'GCash',
      'online_bank': 'Online Bank',
      'amount_tendered': 'Amount Tendered',
      'change': 'Change',
      'insufficient_cash': 'Insufficient cash amount',
      'enter_amount': 'Enter amount',
      'payment_summary': 'Payment Summary',
      'subtotal': 'Subtotal',
      'discount': 'Discount',
      'grand_total': 'Grand Total',
      'confirm_payment': 'Confirm Payment',
      'insufficient_amount': 'Insufficient amount',
      'cancel_sale': 'Cancel Sale',
      'cancelled': 'CANCELLED',
      'cancellation_reason': 'Cancellation Reason',
      'enter_cancellation_reason': 'Enter reason for cancellation...',
      'confirm_cancellation': 'Confirm Cancellation',
      'sale_cancelled_successfully': 'Sale cancelled successfully',
      // Delivery Orders
      'for_delivery': 'For Delivery',
      'delivery_order': 'Delivery Order',
      'delivery_order_created': 'Delivery Order Created',
      'delivery_order_success_message':
          'Delivery order has been created successfully',
      'failed_to_create_delivery': 'Failed to create delivery order',
      'delivery_notes': 'Delivery Notes',
      'enter_delivery_notes_hint':
          'Enter customer address, contact, or special instructions...',
      'create_delivery_order': 'Create Delivery Order',
      'customer_information': 'Customer Information',
      'customer_name': 'Name of Customer',
      'contact_number': 'Contact Number',
      'complete_address': 'Complete Address',
      'enter_customer_name': 'Enter customer name',
      'enter_contact_number': 'Enter contact number',
      'enter_complete_address': 'Enter complete delivery address',
      'customer_name_required': 'Customer name is required',
      'contact_number_required': 'Contact number is required',
      'address_required': 'Complete address is required',
      // Reservation
      'reservation_order': 'Reservation Order',
      'reservation_order_hint': 'Pay reservation fee now, full payment later',
      'reservation_fee': 'Reservation Fee',
      'reserve_order': 'Reserve Order',
      'pending_payment': 'Pending Payment',
      'full_pay': 'Full Pay',
      'remaining_balance': 'Remaining Balance',
      'payment_completed': 'Payment Completed',
      'reserved_orders': 'Reserved Orders',
      // Inventory Screen
      'search_products': 'Search by name or barcode...',
      'search_product_name_barcode': 'Search by product name or barcode...',
      'no_products': 'No products available',
      'barcode': 'Barcode',
      'category': 'Category',
      'stock': 'Stock',
      'stock_quantity': 'Stock Quantity',
      'update_stock': 'Update Stock',
      'view_movements': 'View Movements',
      'add_product': 'Add Product',
      'name': 'Name',
      'selling_price': 'Selling Price',
      'quantity': 'Quantity',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'add': 'Add',
      'verify': 'Verify',
      'clear': 'Clear',
      'units': 'units',
      'product_found': 'Product Found',
      'product_not_found': 'Product Not Found',
      'align_barcode_within_frame': 'Align barcode within frame to scan',
      'low_stock': 'Low Stock',
      'low_stock_warning': 'Low Stock - Please Restock Soon',
      'price_checker_empty_title': 'Start Checking Prices',
      'price_checker_empty_subtitle':
          'Scan a barcode or search for products to view prices and stock information',
      'scan': 'Scan',
      'search': 'Search',
      'view_details': 'Details',
      'owner_verification': 'Owner Verification Required',
      'enter_owner_password':
          'Please enter owner password to access CCTV monitoring',
      'invalid_owner_password': 'Invalid owner password',
      'inventory_movements': 'Inventory Movements',
      'no_movements': 'No movements recorded',
      // Product Management
      'edit_product': 'Edit Product',
      'delete_product': 'Delete Product',
      'product_details': 'Product Details',
      'buying_price': 'Buying Price',
      'description': 'Description',
      'reorder_level': 'Low Stock Alert Level',
      'image': 'Image',
      'select_image': 'Select Image',
      'product_added': 'Product added successfully',
      'product_updated': 'Product updated successfully',
      'product_deleted': 'Product deleted successfully',
      'confirm_delete': 'Confirm Delete',
      'delete_product_msg': 'Are you sure you want to delete {name}?',
      'delete': 'Delete',
      'low_stock_items': 'Low Stock Items ({count})',
      'all_products': 'All Products',
      'profit': 'Profit',
      'low_stock_alert': 'LOW STOCK!',
      'optional': 'Optional',
      // Inventory Management
      'inventory_levels': 'Inventory Levels',
      'restock_delivery': 'Restock / Delivery',
      'adjust_pricing': 'Adjust Pricing',
      'filter_by': 'Filter By',
      'all_items': 'All Items',
      'low_stock_only': 'Low Stock Only',
      'out_of_stock': 'Out of Stock',
      'in_stock': 'In Stock',
      'restock_item': 'Restock Item',
      'delivery_received': 'Delivery Received',
      'quantity_received': 'Quantity Received',
      'supplier': 'Supplier',
      'delivery_note': 'Delivery Note',
      'damage_item': 'Damage Item',
      'damaged_items': 'Damaged Items',
      'quantity_damaged': 'Quantity Damaged',
      'damage_reason': 'Damage Reason',
      'damage_recorded': 'Damage recorded successfully',
      'record_damage': 'Record Damage',
      'record_delivery': 'Record Delivery',
      'delivery_recorded': 'Delivery recorded successfully',
      'adjust_price': 'Adjust Price',
      'new_price': 'New Price',
      'price_updated': 'Price updated successfully',
      'current_price': 'Current Price',
      'new_buying_price': 'New Buying Price',
      'new_selling_price': 'New Selling Price',
      'profit_margin': 'Profit Margin',
      'update_prices': 'Update Prices',
      'items_found': '{count} items found',
      // Supplier Management
      'supplier_management': 'Supplier Management',
      'manage_suppliers_desc': 'Manage suppliers and restock history',
      'suppliers': 'Suppliers',
      'restock_history': 'Restock History',
      'add_supplier': 'Add Supplier',
      'edit_supplier': 'Edit Supplier',
      'supplier_name': 'Supplier Name',
      'contact_person': 'Contact Person',
      'phone': 'Phone',
      'address': 'Address',
      'notes': 'Notes',
      'no_suppliers': 'No suppliers added yet',
      'no_restock_records': 'No restock records yet',
      'supplier_added': 'Supplier added successfully',
      'supplier_updated': 'Supplier updated successfully',
      'supplier_deleted': 'Supplier deleted successfully',
      'supplier_activated': 'Supplier activated',
      'supplier_deactivated': 'Supplier deactivated',
      'please_fill_required_fields': 'Please fill all required fields',
      'delete_supplier_confirm':
          'Are you sure you want to delete supplier "{name}"? This action cannot be undone.',
      'no_results_found': 'No results found',
      'delivery_receipt_no': 'Delivery Receipt No.',
      'receipt_no': 'Receipt No',
      'has_damaged_items': 'Report damaged items during delivery',
      'damage_details': 'Damage Information',
      'damage_info': 'Damage Information',
      'enter_valid_quantity': 'Please enter a valid quantity',
      'enter_damage_quantity': 'Please enter damage quantity',
      'damage_exceeds_received':
          'Damage quantity cannot exceed received quantity',
      'damaged': 'Damaged',
      'restock_details': 'Restock Details',
      'reason': 'Reason',
      'serial_number': 'Serial Number',
      'damage_from': 'Damage from',
      'reason_optional': 'e.g., Broken during delivery',
      // Purchase Orders
      'purchase_orders': 'Purchase Orders',
      'create_order': 'Create Order',
      'order_number': 'Order Number',
      'order_date': 'Order Date',
      'expected_delivery': 'Expected Delivery',
      'order_status': 'Status',
      'pending': 'Pending',
      'approved': 'Approved',
      'completed': 'Completed',
      'received': 'Received',
      'restock': 'Restock',
      'restock_items': 'Restock Items',
      'delivery_receipt': 'Delivery Receipt',
      'delivery_receipt_required': 'Delivery receipt number is required',
      'ordered': 'Ordered',
      'restock_success':
          'Items restocked successfully and order marked as received',
      'no_orders': 'No purchase orders yet',
      'add_products': 'Add Products',
      'select_products': 'Select Products',
      'unit_price': 'Unit Price',
      'total_value': 'Total Value',
      'approve_order': 'Approve Order',
      'sign_here': 'Sign Here',
      'clear_signature': 'Clear',
      'signature_required': 'Signature is required for approval',
      'order_approved': 'Order approved successfully',
      'order_created': 'Purchase order created successfully',
      'order_updated': 'Purchase order updated successfully',
      'order_deleted': 'Purchase order deleted successfully',
      'delete_order_confirm': 'Are you sure you want to delete this order?',
      'order_details': 'Order Details',
      'add_item': 'Add Item',
      'remove_item': 'Remove',
      'create_purchase_order': 'Create Purchase Order',
      'order_from_supplier': 'Order from Supplier',
      'select_product': 'Select Product',
      'select_supplier': 'Please select a supplier',
      'enter_quantity': 'Enter Quantity',
      'enter_unit_price': 'Enter Unit Price',
      'no_items': 'No items added yet',
      'at_least_one_item': 'Please add at least one item',
      'approval_signature': 'Approval Signature',
      'approved_on': 'Approved On',
      'mark_completed': 'Mark Completed',
      // Reports continued
      'reports': 'Reports',
      'sales_report': 'Sales Report',
      'inventory_report': 'Inventory Report',
      'activity_logs': 'Activity Logs',
      'select_date_range': 'Select Date Range',
      'refresh': 'Refresh',
      'total_sales': 'Total Sales',
      'transactions': 'Transactions',
      'avg_transaction': 'Avg Transaction',
      'items_sold': 'Items Sold',
      'sales_trend': 'Sales Trend',
      'top_selling_products': 'Top Selling Products',
      'recent_transactions': 'Recent Transactions',
      'daily_sales': 'Daily Sales',
      'today_total_sales': 'Today\'s Total',
      'today_transactions': 'Today\'s Transactions',
      'average_sale_value': 'Average Sale Value',
      'select_day': 'Select Day',
      'export_csv': 'Export CSV',
      'export_success': 'Export successful',
      'no_sales_data': 'No sales data available',
      'no_transactions': 'No transactions found',
      'total_products': 'Total Products',
      'inventory_value': 'Inventory Value',
      'inventory_by_category': 'Inventory by Category',
      'products': 'products',
      'system_activity': 'System Activity',
      'no_activity': 'No activity found',
      'activity_summary': 'Activity Summary',
      'total_activities': 'Total Activities',
      'sales_transactions': 'Sales Transactions',
      'date_range': 'Date Range',
      'no_data_available': 'No data available',
      'sale': 'Sale',
      // Receipt
      'receipt_header': 'SMART MONITORING POS',
      'receipt_number': 'Receipt #',
      'date': 'Date',
      'cashier': 'Cashier',
      'processed_by': 'Processed By',
      'thank_you': 'Thank you for your purchase!',
      'transaction_completed': 'Transaction Successfully Completed',
      'payment_successful':
          'Your payment has been processed successfully. Would you like to print a receipt?',
      'print_receipt': 'Print Receipt',
      // Login & Auth
      'admin_login_method': 'Admin Login Method',
      'email_gmail': 'Email / Gmail',
      'email_placeholder': 'admin@example.com',
      'contact_number_short': 'Contact Number',
      'contact_placeholder': '+639123456789',
      'password_placeholder': '••••••••',
      'sign_in_google_admin': 'Sign in with Google (Owner Only)',
      'or': 'OR',
      'create_admin_account': 'Create Admin Account',
      'forgot_password': 'Forgot Password? (Owner Only)',
      'reset_admin_password': 'Reset Admin Password',
      'reset_owner_password': 'Reset Owner Password',
      'send_otp': 'Send OTP',
      'enter_otp': 'Enter OTP',
      'otp_sent_to_email': 'A verification code was sent to {email}',
      'tokens': 'Token',
      'confirm_password': 'Confirm Password',
      'secure_access_portal': 'Secure Access Portal',
      'please_fill_all_fields': 'Please fill all fields',
      'valid_email_required':
          'Please enter a valid email (e.g., admin@gmail.com)',
      'valid_contact_required':
          'Please enter a valid contact number (e.g., +639123456789)',
      'password_min_6': 'Password must be at least 6 characters',
      'passwords_not_match': 'Passwords do not match',
      'admin_created_success':
          'Admin account created successfully! You can now login.',
      'account_creation_failed':
          'Failed to create account. Please check your inputs.',
      'password_confirm': 'Confirm Password',
      'password_min_6_hint': 'Password (min 6 characters)',
      'windows_verify_identity':
          'Enter your Windows lockscreen password to verify your identity',
      'windows_user_label': 'Windows User: {username}',
      'windows_password_hint':
          'This is the password you use to log into Windows',
      'windows_password': 'Windows Password',
      'device_verify_identity': 'Verify Your Identity',
      'device_lockscreen': 'Device Lockscreen',
      'device_password_hint':
          'Enter the password you use to unlock your device',
      'device_password': 'Device Password',
      'enter_device_password': 'Please enter your device password',
      'device_auth_success':
          'Device authentication successful! Now set your new admin password',
      'invalid_device_password': 'Invalid device password. Please try again.',
      'device_auth_not_available':
          'Device authentication is not available on this device',
      'enter_new_password': 'Enter your new password',
      'new_password_min_6': 'New Password (min 6 chars)',
      'verify_button': 'Verify',
      'reset_password_button': 'Reset Password',
      'enter_windows_password': 'Please enter your Windows password',
      'windows_auth_success':
          'Windows authentication successful! Now set your new admin password',
      'invalid_windows_password': 'Invalid Windows password. Please try again.',
      'authentication_error': 'Authentication error: {error}',
      'password_reset_success': 'Password reset successfully',
      'password_reset_failed': 'Failed to reset password',
      // CCTV
      'cctv_monitoring': 'CCTV Monitoring',
      'camera_url': 'Camera URL / RTSP Stream',
      'recordings_directory': 'Recordings Directory (Optional)',
      'add_camera': 'Add Camera',
      'configure_camera': 'Configure Camera',
      'remove_camera': 'Remove Camera',
      'camera_name': 'Camera Name',
      'camera_type': 'Camera Type',
      'no_cameras': 'No cameras added yet',
      'add_first_camera': 'Add your first camera to start monitoring',
      'camera_added': 'Camera added successfully',
      'camera_updated': 'Camera updated successfully',
      'camera_deleted': 'Camera deleted successfully',
      'confirm_delete_camera': 'Delete this camera?',
      'camera_grid': 'Camera Grid',
      'select_camera': 'Select a camera to view',
      // Sales Reports
      'sales_results': 'Sales Results',
      'sales_reports': 'Sales Reports',
      // Product Camera
      'capture_product_image': 'Capture Product Image',
      // User Management
      'deactivate_user': 'Deactivate User',
      'deactivate': 'Deactivate',
      'no_users_yet': 'No users yet',
      'add_user': 'Add User',
      // Settings
      'reduce_motion': 'Reduce Motion (limit animations)',
      // Navigation subtitles
      'open_cash_register': 'Open cash register',
      'process_customer_payments': 'Process customer payments',
      'manage_admin_account': 'Manage Admin Account',
      'welcome_user': 'Welcome, {name}',
      // System Reset
      'reset_all_data': 'Reset All Data',
      'reset_all_data_desc':
          'Delete ALL products, sales & inventory records and start fresh',
      'confirm_reset_title': 'Confirm Full Reset',
      'confirm_reset_message':
          'This will permanently delete ALL POS records. Type RESET to continue.',
      'type_reset_label': 'Type RESET to confirm',
      'reset': 'Reset',
      'reset_success': 'System data cleared successfully',
      'reset_cancelled': 'Reset cancelled',
      'reset_all_data_tooltip': 'Danger: Reset System Data',
      // Admin Account Management
      'edit': 'Edit',
      'account_information': 'Account Information',
      'full_name': 'Full Name',
      'email_address': 'Email Address',
      'account_contact_number': 'Contact Number (for SMS recovery)',
      'contact_hint': '+1 (555) 123-4567',
      'save_changes': 'Save Changes',
      'security': 'Security',
      'change_password': 'Change Password',
      'security_message':
          'Change your password regularly to maintain account security.',
      'account_created': 'Account Created',
      'last_updated': 'Last Updated',
      'never': 'Never',
      'account_updated_success': 'Account updated successfully',
      'fill_required_fields':
          'Please fill all required fields with valid email',
      'password_changed_success': 'Password changed successfully',
      'current_password': 'Current Password',
      'new_password': 'New Password (min 6 chars)',
      'confirm_new_password': 'Confirm New Password',
      'update_password': 'Update Password',
      'current_password_incorrect': 'Current password is incorrect',
      'new_password_min_length': 'New password must be at least 6 characters',
      'passwords_do_not_match': 'Passwords do not match',
      'admin_password_conflict':
          'Admin password must be different from owner passwords',
      'last_updated_date': 'Last updated: {date}',
      'damage_reports': 'Damage Reports',
      'total_damaged_items': 'Total Damaged Items',
      'total_value_lost': 'Total Value Lost',
      'view_admin_reports': 'View Admin Reports',
      'no_damage_reports': 'No damage reports yet',
      'value': 'Value',
      'reported_by': 'Reported By',
      'return_to_supplier': 'Return to Supplier',
      'return_status': 'Return Status',
      'return_approval': 'Return Approval',
      'approve_return': 'Approve Return',
      'return_approved': 'Return approved successfully',
      'returned': 'Returned',
      'pending_return': 'Pending',
      'return_date': 'Return Date',
      'approved_by': 'Approved By',
      'damage_return_report': 'Damage Return Report',
      'export_return_pdf': 'Export Return PDF',
      // Store Damage Payment
      'proceed_to_payment': 'Proceed to Payment',
      'select_responsible_person': 'Select Responsible Person',
      'all_staff': 'All Staff',
      'payment_responsibility': 'Payment Responsibility',
      'store_damage_payment': 'Store Damage Payment',
      'responsible_person': 'Responsible Person',
      'payment_processed': 'Payment processed successfully',
      'store_damage_paid': 'Store Damage Paid',
      'payment_pending': 'Payment Pending',
      'payment_date': 'Payment Date',
      'assign_payment_to': 'Assign payment to:',
      'shared_responsibility': 'Shared among all staff members',
      'no_users_found': 'No users found in the system',
      'already_paid': 'Already Paid',
      // CCTV Timestamps
      'timestamps_log': 'Timestamps Log',
      'saved_timestamps': 'Saved CCTV Timestamps',
      'no_timestamps_saved': 'No timestamps saved yet',
      'view_footage': 'View Footage',
      'export_video': 'Export Video',
      'video_exported': 'Video Exported',
      'file_path': 'File Path',
      'video_export_success': 'Video exported successfully',
      'video_export_failed': 'Failed to export video',
      'delete_timestamp_confirm':
          'Are you sure you want to delete this timestamp?',
      'clear_all': 'Clear All',
      'clear_all_timestamps_confirm':
          'Are you sure you want to clear all saved timestamps?',
      // Business Registration
      'business_registration': 'Business Registration',
      'business_registration_title': 'Register Your Business',
      'business_registration_subtitle':
          'Set up your store information to personalize the system',
      'store_logo': 'Store Logo',
      'tap_to_upload_logo': 'Tap to upload logo',
      'store_name_label': 'Store Name',
      'store_name_hint': 'Enter your store name',
      'store_name_required': 'Store name is required',
      'business_type_label': 'Business Type',
      'select_business_type': 'Select business type',
      'business_type_required': 'Business type is required',
      'store_address_label': 'Store Address',
      'store_address_hint': 'Enter store address (street, city, zip code)',
      'save_business_info': 'Save Business Information',
      'saving': 'Saving...',
      'business_info_saved': 'Business information saved successfully!',
      'business_info_save_failed': 'Failed to save business information',

      // Shoe Store Features
      'shoe_size_section': 'Shoe Size Information',
      'size_type': 'Size Type',
      'men_sizes': 'Men Sizes',
      'women_sizes': 'Women Sizes',
      'unisex_sizes': 'Unisex Sizes',
      'enter_quantity_per_size': 'Enter quantity for each size:',
      'shoe_sizes_available': 'Shoe Sizes Available',
      'tap_to_view_sizes': '👟 Tap to view sizes',
      'select_size': 'Select Size',
      'multiple_sizes': 'Multiple Sizes',
      'added_to_cart': 'added to cart',

      // Privacy Policy & User Agreement
      'legal': 'Legal',
      'privacy_policy': 'Privacy Policy',
      'user_agreement': 'User Agreement',
      // About System
      'about': 'About',
      'about_system': 'About the System',
      'system_subtitle': 'Integrated POS and CCTV Monitoring',
      'developed_by': 'Developed By',
      'brand': 'Brand',
      'version': 'Version',
      'release_date': 'Release Date',
      'about_description':
          'A comprehensive retail management solution combining Point-of-Sale operations with advanced CCTV monitoring capabilities. Designed to streamline business operations and enhance security.',
      // Financial Monitoring
      'financial_monitoring': 'Financial Monitoring',
      'financial_monitoring_desc':
          'Track revenue, analyze trends, export reports',
      'start_date': 'Start Date',
      'end_date': 'End Date',
      'total_revenue': 'Total Revenue',
      'average_transaction': 'Average Transaction',
      'daily_revenue_chart': 'Daily Revenue Chart',
      'exporting': 'Exporting...',
      'pdf_saved': 'PDF saved successfully',
      'csv_saved': 'CSV saved successfully',
      'transaction_id': 'Transaction ID',
      'amount': 'Amount',
      'financial_report': 'Financial Report',
      'report_period': 'Report Period',
      'summary': 'Summary',
      'transaction_details': 'Transaction Details',
      // Privacy Policy Content
      'privacy_last_updated': 'Last Updated: December 12, 2025',
      'agreement_last_updated': 'Last Updated: December 12, 2025',
      'privacy_intro_title': '1. Introduction',
      'privacy_intro_content':
          'Welcome to Smart Monitoring System with Integrated POS and CCTV. This Privacy Policy explains how we collect, use, and protect your personal information when using our system. By using this application, you agree to the collection and use of information in accordance with this policy.',
      'privacy_data_collection_title': '2. Information We Collect',
      'privacy_data_collection_content':
          'We collect information necessary for system operation including: User account information (name, email, contact number, role), Product data (names, barcodes, prices, inventory levels), Sales transaction records, CCTV footage and timestamps, Inventory movement history, and Device information for authentication purposes. All data is stored locally on your device.',
      'privacy_data_usage_title': '3. How We Use Your Information',
      'privacy_data_usage_content':
          'Your information is used exclusively for: Processing sales transactions, Managing inventory and stock levels, User authentication and role-based access control, Generating sales reports and analytics, CCTV monitoring and security purposes, Tracking product movements and damage reports. We do not share your data with third parties.',
      'privacy_data_storage_title': '4. Data Storage and Retention',
      'privacy_data_storage_content':
          'Core application data is stored locally using SQLite database on your device. Optional cloud sync and license/subscription features may use a backend MySQL/Supabase service when configured. Local data persists until manually deleted by authorized administrators, and CCTV footage is stored based on available device storage capacity. You have full control over data retention and deletion.',
      'privacy_security_title': '5. Security Measures',
      'privacy_security_content':
          'We implement industry-standard security measures including: Role-based access control (Admin, Owner, Cashier), Secure local database storage, PIN and password authentication, Device-level encryption (when available), Regular security updates. However, no system is completely secure, and you are responsible for maintaining device security.',
      'privacy_rights_title': '6. Your Rights',
      'privacy_rights_content':
          'You have the right to: Access your personal information, Request data corrections or updates, Delete your account and associated data, Export transaction records and reports, Opt-out of CCTV recording in non-security areas. Contact your system administrator to exercise these rights.',
      // Additional legal tools
      'dependency_licenses': 'Dependency Licenses',
      'dependency_licenses_desc':
          'View open-source licenses for bundled packages.',
      'update_privacy_policy': 'Edit Privacy Policy',
      'update_terms': 'Edit Terms & Conditions',
      'pci_guidance_title': 'PCI Guidance',
      'pci_guidance_summary': 'Basic guidance if you accept card payments',
      'pci_guidance_content':
          'If you accept card payments, follow PCI DSS basics: use a PCI-compliant payment processor, avoid storing card numbers, use TLS for network communication, maintain unique admin accounts, keep systems updated, and perform periodic security reviews. For full compliance consult a PCI Qualified Security Assessor (QSA).',
      // User Agreement Content
      'agreement_acceptance_title': '1. Acceptance of Terms',
      'agreement_acceptance_content':
          'By accessing and using the Smart Monitoring System, you accept and agree to be bound by the terms and conditions of this agreement. If you do not agree to these terms, please discontinue use immediately. This agreement applies to all users including administrators, store owners, and cashiers.',
      'agreement_license_title': '2. License and Usage',
      'agreement_license_content':
          'We grant you a limited, non-exclusive, non-transferable license to use this software for retail business operations. This license is valid for the organization that deployed the system. You may use the system on multiple devices within your organization as authorized by your administrator.',
      'agreement_restrictions_title': '3. Restrictions',
      'agreement_restrictions_content':
          'You agree NOT to: Reverse engineer, decompile, or disassemble the software, Share login credentials with unauthorized persons, Attempt to bypass security measures or role-based access controls, Use the system for illegal activities or fraudulent transactions, Tamper with or delete audit logs, CCTV footage, or transaction records, Redistribute or resell the software without authorization.',
      'agreement_responsibilities_title': '4. User Responsibilities',
      'agreement_responsibilities_content':
          'Users are responsible for: Maintaining confidentiality of login credentials, Reporting security breaches immediately, Ensuring accurate data entry for products and transactions, Following proper checkout and inventory procedures, Regular data backups (administrator responsibility), Compliance with local laws and regulations regarding POS systems and CCTV monitoring.',
      'agreement_liability_title': '5. Limitation of Liability',
      'agreement_liability_content':
          'This software is provided "as is" without warranties of any kind. We are not liable for: Loss of data due to device failure, hardware issues, or user error, Business losses resulting from system downtime or errors, Damages from unauthorized access due to user negligence, Issues arising from improper use or configuration. Users assume all risks associated with system usage.',
      'agreement_termination_title': '6. Termination',
      'agreement_termination_content':
          'This agreement remains in effect until terminated. Your access may be terminated immediately without notice if you violate any terms of this agreement. Upon termination, you must cease all use of the system. Data may be retained as required by law or business needs. Administrators have the right to deactivate user accounts at any time.',
      // User Manual Sections
      'manual_installation': 'Installation Instructions',
      'manual_installation_content': '''System Requirements:

Windows Desktop:
- Windows 10 or later (64-bit)
- Minimum 4GB RAM
- 500MB free disk space
- Screen resolution: 1280x720 or higher

Android:
- Android 7.0 (Nougat) or later
- Minimum 2GB RAM
- 200MB free storage

iOS:
- iOS 12.0 or later
- iPhone 6s or newer
- iPad Air 2 or newer

Windows Installation Steps:
1. Download the installer or locate the executable file
2. Double-click to run the application
3. Grant camera and file access permissions
4. The login screen will appear - system is ready

Android/iOS Installation:
1. Install APK file (Android) or from App Store (iOS)
2. Grant camera and storage permissions
3. Launch the application

Database Setup:
The system automatically creates a local database on first launch. No manual configuration required.''',

      'manual_roles': 'User Roles & Permissions',
      'manual_roles_content': '''Admin (Full System Access):
[x] Manage user accounts (create/edit/deactivate)
[x] Manage products (add/edit/delete/restock)
[x] View all reports (sales, inventory, damage)
[x] Export data (CSV/PDF)
[x] Configure system settings

Owner (Business Management):
[x] View detailed sales reports
[x] Monitor CCTV feeds
[x] Manage inventory
[x] Report damaged items
[x] Access POS terminal
[x] Backup & Restore database
[x] View analytics and charts
[ ] Cannot manage users
[ ] Cannot delete products

Cashier (Point of Sale):
[x] Process customer transactions
[x] Add items to cart
[x] Apply discounts
[x] Complete sales
[x] View sales log
[x] Access CCTV (with owner password)
[ ] Cannot manage products
[ ] Cannot view reports
[ ] Cannot manage inventory''',

      'manual_create_admin': 'How to Create Admin Account',
      'manual_create_admin_content': '''Step 1: Click "Create Admin Account"
- On the login screen, click the button at the bottom
- Registration form will appear

Step 2: Fill in Account Details
- Full Name: Your complete name
- Email Address: Valid email (e.g., admin@store.com)
- Contact Number: Must start with +63
  Example: +639171234567
- Password: Minimum 8 characters
  Must contain letters, numbers, and symbols
  Example: Admin@2025

Step 3: Verify Information
- Double-check all entered information
- Ensure email is correct (for password recovery)
- Ensure phone includes country code (+63)

Step 4: Create Account
- Click "Create Account" button
- Wait for success confirmation
- Redirected to login screen

Step 5: Login as Admin
- Select Admin Login tab
- Choose login method:
  - Email + Password OR
  - Contact Number + Password OR
  - Gmail Sign-In (if configured)
- Click "Login" button''',

      'manual_add_products': 'How to Add Products',
      'manual_add_products_content': '''Navigate to Product Management:
- Admin Dashboard -> "Manage Products"

Click "Add Product" button

Fill in Product Information:
- Product Name: Descriptive name (e.g., "Coca-Cola 1.5L")
- Barcode: Scan or enter manually
- Category: Select from dropdown or create new
- Buying Price: Cost price (PHP )
- Selling Price: Retail price (PHP )
- Quantity: Current stock level
- Reorder Level: Minimum stock threshold (default: 5)
- Product Image: Click camera icon to add photo

Save Product:
- Click "Save" button
- Product is now available in POS

Edit Product:
- Tap product card
- Modify details
- Click "Update"

Restock Product:
- Tap product to edit
- Update "Quantity" field to new stock level
- System automatically records inventory movement
- Click "Save"''',

      'manual_use_pos': 'How to Use POS',
      'manual_use_pos_content': '''Access: Cashier Dashboard -> "Open POS"

Process a Sale:

Step 1: Add Items to Cart
Method A: Tap Product Tiles
- Browse product grid
- Tap product tile to add to cart
- Long-press image to view larger picture with zoom

Method B: Use Search Bar
- Type product name or category
- Results filter in real-time
- Tap product to add

Method C: Scan Barcode
- Click barcode icon
- Scan product barcode with camera
- Product automatically added to cart

Step 2: Adjust Quantities
- In cart sheet, use + and - buttons
- Or tap quantity to enter manually
- Remove item by reducing to 0

Step 3: Apply Discounts (Optional)
- Tap discount icon on cart item
- Enter discount percentage (0-100%)
- Or enter fixed amount discount
- Discount applies to that item only

Step 4: Review Cart
- Check all items and quantities
- Verify total amount
- Cart displays: Subtotal, Total Discount, Final Total

Step 5: Checkout
- Click "Checkout" button
- Select Payment Method:
  - Cash: Customer pays with cash
  - Card: Credit/Debit card payment
  - E-wallet (Cash-In): GCash, Maya, etc.
  - E-wallet (Cash-Out): Customer withdraws
  - Multiple Payment Methods: Split payment
- Enter Amount (for Cash)
- Click "Complete Sale"
- Receipt generated automatically
- Cart cleared, stock updated''',

      'manual_backup': 'Backup & Restore Guide',
      'manual_backup_content': '''Why Backup is Important:
- Protect from hardware failure
- Protect from software errors
- Prevent data loss from accidental deletion
- Recover from system crashes

Best Practices:
[x] Daily backups (end of business day)
[x] Before major changes (bulk updates)
[x] Before system updates
[x] Store backups in multiple locations

How to Create a Backup:
Access: Owner Dashboard -> "Backup & Restore"

Method 1: Create Internal Backup
1. Click "Create Backup" button
2. System creates timestamped backup automatically
3. Success message confirms creation
4. Backup stored in app's backup directory

Method 2: Export Database
1. Click "Export Database" button
2. Choose save location (USB, Cloud, Network drive)
3. Choose filename (default: pos_system_export_YYYY-MM-DD.db)
4. Click "Save"
5. Database exported successfully

Recommended Storage:
- Keep 3 copies: Internal + USB + Cloud
- Rotate weekly backups
- Test restore periodically

How to Restore a Backup:

Method 1: Restore from Internal Backup
1. Open "Backup & Restore" screen
2. View list of available backups
3. Select backup to restore
4. WARNING: Replacing ALL current data
5. Click "Yes, Restore"
6. Restart the app

Method 2: Import Database
1. Click "Import Database" button
2. Navigate to backup .db file
3. Confirm import
4. System imports database
5. Restart the app

Backup Schedule:
- Daily: End of business day (Internal backup)
- Weekly: Every Sunday (Export to USB)
- Monthly: 1st of month (Export to cloud)
- Before Updates: Both internal + external''',

      'manual_quick_start': 'Quick Start Guide',
      'manual_quick_start_content': '''First-Time Setup (15 minutes):

Step 1: Create Admin Account (3 min)
- Launch app
- Click "Create Admin Account"
- Fill in: Name, Email, Phone, Password
- Click "Create Account"

Step 2: Login as Admin (1 min)
- Select Admin Login
- Enter email + password
- Click "Login"

Step 3: Add Sample Products (5 min)
- Admin Dashboard -> "Manage Products"
- Click "Add Product"
- Example: Coca-Cola 1.5L, Barcode, Category, Prices, Quantity
- Click "Save"
- Add 2-3 more products

Step 4: Create Cashier Account (2 min)
- Admin Dashboard -> "Manage Users"
- Click "+" icon
- Fill in: Name, Email, Password, PIN, Role: Cashier
- Click "Save"

Step 5: Test POS Transaction (4 min)
- Logout from admin
- Login as Cashier
- Open POS Terminal
- Add products to cart
- Complete a test sale

[x] System is now ready for use!

Daily Operations Checklist:

Morning (Opening):
[ ] Login as Cashier
[ ] Verify POS is working
[ ] Check product availability
[ ] Review yesterday's sales (Owner)

During Business Hours:
[ ] Process customer transactions
[ ] Report any damaged items
[ ] Restock products as needed

Evening (Closing):
[ ] Count cash register
[ ] Verify sales total matches cash
[ ] Create daily backup (Owner)
[ ] Export sales report
[ ] Logout from all accounts''',

      'manual_troubleshooting': 'Troubleshooting FAQ',
      'manual_troubleshooting_content': '''Login Issues:

Q: Forgot admin password?
A: Use password recovery:
1. Click "Forgot Password?" on login screen
2. Enter admin email
3. Verify OTP sent to email
4. Enter phone number
5. Verify SMS code
6. Set new password

Q: "Invalid credentials" error?
A: 
- Verify caps lock is OFF
- Check email/phone format
- Ensure password is correct
- Try toggling password visibility (eye icon)

POS Issues:

Q: Product not found in POS?
A:
- Verify product was added in Admin -> Manage Products
- Check product is not deleted
- Try searching by barcode or name
- Refresh product list

Q: Barcode scanner not working?
A:
- Grant camera permission to app
- Ensure barcode is clear and visible
- Try manual entry
- Restart app if camera freezes

Q: "Insufficient stock" error?
A:
- Product quantity is 0 or less than requested
- Restock product via Admin -> Manage Products
- Check inventory movements

Backup Issues:

Q: Backup failed to create?
A:
- Check free disk space (need 50MB+)
- Close app completely and reopen
- Ensure database isn't corrupted
- Try manual export instead

Q: Cannot restore backup?
A:
- Verify backup file has .db extension
- Ensure backup file is not corrupted
- Try different backup file
- Check file isn't opened by another program

Performance Issues:

Q: App is slow or laggy?
A:
- Enable "Reduce Motion" in Settings
- Close other apps in background
- Clear old transactions (Admin only)
- Restart device

Q: Database getting too large?
A:
- Export old sales to CSV
- Archive transactions older than 1 year
- Regular cleanup every 6 months''',

      'manual_common_tasks': 'Common Tasks Reference',
      'manual_common_tasks_content': '''Quick Reference:

Add Product:
Admin -> Manage Products -> + -> Fill details -> Save

Restock Item:
Admin -> Manage Products -> Select product -> Update quantity -> Save

Process Sale:
Cashier -> POS -> Add items -> Checkout -> Payment -> Complete

View Sales:
Owner -> Sales Reports -> Select date -> View details

Create Backup:
Owner -> Backup & Restore -> Create Backup

Report Damage:
Owner/Admin -> Inventory -> Damage Reports -> Report Damage

Process Damage Payment (Owner Only):
Owner -> Inventory -> Damage Reports -> Select unpaid damage -> Proceed to Payment -> Select responsible person -> Confirm -> Receipt generated

View Payment Status:
Damage Reports -> Blue badge = Paid, Green = Returned, Red/Orange = Pending

Change Theme:
Any user -> Settings (gear icon) -> Select color

Change Language:
Settings -> Language -> EN or FIL

Export Reports:
View report -> Click Export CSV or Export PDF

Access CCTV:
Owner -> Monitor CCTV
Cashier -> Sales Log -> Camera icon -> Enter owner password

View Inventory:
Owner/Admin -> Inventory -> View stock levels

Low Stock Alerts:
Products with ≤5 items shown in red

User Management:
Admin -> Manage Users -> + to add, tap to edit

Deactivate User:
Admin -> Manage Users -> Select user -> Toggle Active Status OFF

Password Recovery:
Login screen -> Forgot Password -> Follow email/SMS verification

Search Products:
POS screen -> Type in search bar (name or barcode)

Zoom Product Image:
Long-press product tile in POS

Apply Discount:
In cart -> Tap discount icon on item -> Enter amount/percentage

Multiple Payment:
Checkout -> Select "Multiple Payment Methods" -> Split payment

Add Supplier:
Owner -> Supplier Management -> + Add Supplier -> Fill details -> Save

Create Purchase Order:
Owner -> Supplier Management -> Purchase Orders -> + Create -> Select supplier -> Add products -> Submit

Return Damaged Item to Supplier:
Owner -> Supplier Management -> Supplier Damage Reports -> Select damage -> Return to Supplier -> Confirm

View Order Status:
Supplier Management -> Purchase Orders -> View cards (Orange=Pending, Green=Completed, Red=Cancelled)''',

      'manual_getting_started': 'Getting Started',
      'manual_getting_started_content': '''First Launch:

1. Open the application
   - Launch Smart Store Monitoring System

2. You'll see the login screen with three options:
   - Admin Login
   - Owner Login
   - Cashier Login

3. First-time setup requires creating an Admin account

Note: Admin account must be created before any other user accounts.''',

      'manual_admin_features': 'Admin Features',
      'manual_admin_features_content': '''1. Managing User Accounts

Add New User (Owner or Cashier):
- Admin Dashboard -> "Manage Users"
- Click "+" icon (top-right)
- Fill in: Name, Email, Password, PIN, Role
- Click "Save"

Edit User: Tap user card -> Modify -> "Update"
Deactivate User: Tap user card -> Toggle "Active Status" OFF

2. Managing Products

Add Product:
- Admin Dashboard -> "Manage Products" -> "Add Product"
- Fill in: Name, Barcode, Category, Prices, Quantity, Reorder Level
- Add photo -> "Save"

Edit Product: Tap product -> Modify -> "Update"
Restock: Tap product -> Update "Quantity" -> "Save"
Delete: Tap product -> "Delete Product" -> Confirm

3. Viewing Reports

Sales Reports: View total sales, transactions, payment methods
Inventory Reports: Stock levels, low stock alerts (≤5 items)
Damage Reports: Damaged items, value lost, reasons
User Activity Logs: Login times, actions, timestamps
Export: CSV or PDF

4. System Settings

Access: Click gear icon
- Language: EN/FIL
- Theme: 9 presets + 24 custom colors
- Accessibility: Reduce Motion
- Data Management: Export, clear old transactions

7. Managing Attendance

Access Manage Attendance:
- Admin Dashboard -> "Manage Attendance"

View Attendance List:
- See all users with today's status, last clock-in/out times, and role

Mark or Edit Attendance:
- Click a user row to add or correct a clock-in/out record
- Add notes or reason for adjustments

Attendance Reports & Export:
- Filter by date range or user
- Click "Export CSV" to download attendance logs for payroll or audits

Bulk Actions:
- Import/Export attendance (CSV) and perform bulk corrections''',

      'manual_owner_features': 'Owner Features',
      'manual_owner_features_content': '''1. Sales Reports & Analytics

Access: Owner Dashboard -> "View Sales Reports"

Daily Summary:
- Select date
- View: Total Sales, Transactions, Average, E-wallet Fees
- Export: CSV or PDF

Date Range: Choose dates -> View trends -> Export

Sales Charts: Line chart (trends), Bar chart (payment methods)

2. CCTV Monitoring

Setup: Settings -> Configure URL (RTSP/HTTP/Local video)
View: Live feed, Play/Pause, Snapshot, Zoom
Multiple Cameras: Swipe between feeds, grid view

3. Inventory Management

Check Stock: View quantities, low stock warnings (≤5 items)
Movements: View sales, restocks, adjustments
Report Damage: Select product, quantity, reason -> "Submit"

4. Access POS Terminal

Owner Dashboard -> "POS Terminal"
Process sales as cashier
Sales recorded under owner name

5. Store Damage Payment Management

Access: Owner Dashboard -> "Inventory Status" -> "Damage Reports" tab

For Unpaid Store Damage:
- View damage reports with red/orange icons (pending)
- Click "Proceed to Payment" button (orange)

Payment Process:
1. Select Responsible Person:
   - Choose staff member from list (shows name and role)
   - OR select "All Staff" for shared responsibility
   - Review damage details: Product, Quantity, Total Value

2. Confirm Payment:
   - Click "Proceed to Payment" button
   - System creates sale record with 'SD-{timestamp}' number
   - Payment method recorded as "Store Damage Payment"

3. Receipt Generation:
   - Receipt dialog appears automatically
   - Shows: Receipt number, date, product, quantity, amount
   - Displays responsible person's name
   - Click "Print Receipt" to generate PDF
   - Click "Close" to finish

Post-Payment Status:
- Damage report shows blue "Store Damage Paid" badge
- Payment date displayed
- Responsible person information visible
- Sale recorded in Sales Reports
- Total damaged items/value updated (excluding paid)

Admin Reports Integration:
- Admin -> Reports -> Damage Reports
- View payment status cards: Paid (blue), Returned (green), Pending (red)
- Enhanced CSV export includes payment columns
- Filter by status for detailed analysis

6. Supplier Management

Access: Owner Dashboard -> "Supplier Management"

Tabs: Suppliers | Supplier Damage Reports | Purchase Orders

A. Managing Suppliers:

Add New Supplier:
1. Tap "+ Add Supplier" button
2. Fill in supplier information:
   - Supplier Name (required)
   - Contact Person
   - Phone Number
   - Email Address
   - Physical Address
3. Tap "Add Supplier" to save

Edit/Delete Supplier:
- Tap supplier card to view details
- Use edit icon to update information
- Use delete icon to remove (if no active orders)

B. Supplier Damage Reports:

View Damages from Suppliers:
- See all items received damaged from suppliers
- Status indicators:
  * Red: Pending (not yet returned)
  * Green: Returned (completed)
  * Blue: Already paid (store damage settled)
- Displays: Product, Quantity, Supplier, Date

Return to Supplier:
1. Tap "Return to Supplier" button (red)
2. Confirm return action
3. Status changes to green "Returned to Supplier"
4. Stock adjustments applied automatically

Note: Items marked as "Store Damage Paid" cannot be returned
- Disabled "Return to Supplier" button for paid damages
- Payment date and responsible person displayed

C. Purchase Orders:

Create Purchase Order:
1. Tap "+ Create Purchase Order" button
2. Select Supplier from dropdown
3. Add Products:
   - Search and select products from inventory
   - Enter quantity for each product
   - System shows current stock levels
4. Review Order Summary:
   - Total items
   - Total order value
   - Supplier information
5. Tap "Create Order" to submit

Order from Product Screen:
- From Inventory -> Restock Delivery tab
- Tap cart icon on low stock/out of stock items
- Auto-navigates to Purchase Orders with product preselected

View/Manage Orders:
- Order status cards: Pending, Completed, Cancelled
- View order details: Products, quantities, total value
- Track order dates and status changes
- Export order history as CSV

Order Statuses:
- Pending (Orange): Awaiting delivery
- Completed (Green): Received and stock updated
- Cancelled (Red): Order cancelled

Best Practices:
- Keep supplier contact information updated
- Process returns promptly for damaged items
- Review purchase orders before submission
- Monitor order statuses regularly
- Coordinate with suppliers on delivery schedules''',

      'manual_cashier_features': 'Cashier Features',
      'manual_cashier_features_content': '''1. Using POS Terminal

Access: Cashier Dashboard -> "Open POS"

Add Items to Cart:
- Method A: Tap product tiles (long-press for zoom)
- Method B: Search bar (type name/category)
- Method C: Scan barcode

Adjust Quantities: Use +/- buttons or tap to enter manually
Apply Discounts: Tap discount icon -> Enter percentage or amount
Review Cart: Check items, verify Subtotal, Discount, Total

Checkout:
1. Click "Checkout"
2. Select Payment: Cash/Card/E-wallet/Multiple
3. Enter Amount (Cash) - System calculates change
4. "Complete Sale" - Receipt generated, cart cleared, stock updated

Low Stock Warning: If quantity ≤5 after sale

View Sales Log: See all transactions with details

2. Access CCTV (Requires Owner Password)

Sales Log -> Tap camera icon -> Enter owner password
View CCTV at sale timestamp

3. Product Image Viewing

Long-press product tile -> Enlarged view -> Zoom (0.5x-4x)

4. Attendance (Clock In / Clock Out)

Clock In / Clock Out:
1. Open the POS (Cashier) screen
2. Tap the Profile / Attendance icon (top-right) or use the `Attendance` action
3. Clock In to start your shift; the app records timestamp and device
4. Clock Out when you finish; supervisors can edit entries if needed
5. Owners/Admins can export attendance logs (CSV) from Admin -> Manage Attendance
''',

      'manual_support': 'Support Information',
      'manual_support_content': '''Contact Details:

Developer/Vendor:
- Company: Pinkora Dev
- Email: jaybe.gubot01@gmail.com
- Phone: +63 9604279947
- Raket PH: raket.ph/pinkora_dev

Business Hours:
Monday - Friday: 9:00 AM - 6:00 PM (PHT)
Saturday: 10:00 AM - 3:00 PM
Sunday: Closed

Emergency Support:
- Email: jaybe.gubot01@gmail.com
- Response: Within 24 hours

Getting Help:
- General: jaybe.gubot01@gmail.com
- Technical: jaybe.gubot01@gmail.com
- Billing: jaybe.gubot01@gmail.com

Live Chat: Available during business hours (5-10 min response)

Social Media:
Facebook: @gubotjaybe26
Tiktok: @pinkora_dev

Software Updates:
Settings -> About -> Check for Updates
Automatic updates available
Dashboard notifications

Bug Reports Include:
1. Device/OS info
2. Steps to reproduce
3. Screenshots/errors
4. User role
5. App version

Update Schedule:
- Major: Every 6 months
- Minor: Monthly
- Security Patches: As needed
- Hotfixes: As needed

Roadmap 2026:
Q1: Cloud sync, Multi-store, Analytics
Q2: Loyalty program, SMS, Auto-reordering
Q3: AI forecasting, Facial recognition, Voice commands
Q4: E-commerce, Supplier management, Payroll

Training:
- YouTube: @Pinkora_Dev SmartStore POS Tutorials (30+ videos)
- User Manual
- API Documentation

License:
- Single installation per license
- Lifetime use
- 1 year free updates & support
- Extended support available

Data Privacy:
- Local storage only
- No telemetry
- GDPR compliant
- Optional encryption

Thank you for choosing Smart Store Monitoring System!
Visit: www.pinkoradev.com''',

      'settings_saved': 'Settings saved successfully',

      // E-Wallet Transfer
      'ewallet_transfer': 'E-Wallet Transfer',
      'transaction_type': 'Transaction Type',
      'cash_in': 'Cash IN',
      'cash_out': 'Cash Out',
      'transfer_fee': 'Transfer Fee',
      'receipt_verification': 'Receipt Verification',
      'capture_receipt': 'Capture Receipt',
      'capture_receipt_optional': 'Capture Receipt (Optional)',
      'receipt_captured': '✓ Receipt captured',
      'retake': 'Retake',
      // Financial Reports
      'financial_reports': 'Financial Reports',
      'financial_reports_tab': 'Financial Reports',
      'sales_report_tab': 'Sales Report',
      'available_in_standard': 'Available in Standard package and above',
      'upgrade_package': 'Upgrade Package',
      'upgrade_to_standard': 'Please upgrade to Standard package or above',
      'select_date': 'Select Date',
      'revenue_overview': 'Revenue Overview',
      'gross_revenue': 'Gross Revenue',
      'net_revenue': 'Net Revenue',
      'growth_rate': 'Growth Rate',
      'expenses': 'Expenses',
      'operating_costs': 'Operating Costs',
      'transfer_fees': 'Transfer Fees',
      'total_expenses': 'Total Expenses',
      'profit_analysis': 'Profit Analysis',
      'gross_profit': 'Gross Profit',
      'net_profit': 'Net Profit',
      'financial_insights': 'Financial Insights',
      'revenue_explanation':
          'Revenue: Gross revenue includes all completed sales. Net revenue excludes transfer fees from e-wallet transactions.',
      'expenses_explanation':
          'Expenses: Operating costs are estimated at 20% of gross revenue. Transfer fees are actual fees from e-wallet transactions.',
      'profit_explanation':
          'Profit: Gross profit = Revenue - Operating costs. Net profit = Revenue - All expenses. Profit margin = Net profit / Revenue.',
    },
    'fil': {
      'app_title': 'Smart Store Monitoring System',
      'welcome': 'Mabuhay!',
      'email': 'Email',
      'contact': 'Contact',
      'password': 'Password',
      'login': 'Magpatuloy sa Pag-login',
      'user_manual': 'Manwal ng Gumagamit',
      'export_pdf_success': 'Matagumpay na na-export ang PDF',
      'help_support': 'Tulong at Suporta',
      'export_pdf': 'I-export ang PDF',
      'generating_pdf': 'Gumagawa ng PDF...',
      'pdf_exported_to': 'Na-export ang PDF sa: {path}',
      'pdf_saved_to_downloads': 'Na-save ang PDF sa Downloads folder',
      'export_failed': 'Nabigo ang pag-export: {error}',
      'contents': 'Mga Nilalaman',
      'sections_count': '{n} mga seksyon',
      'invalid': 'Maling Email o Password',
      'google_signin_unavailable':
          'Ang Google Sign-In ay hindi available sa offline mode',
      'store_name': 'Smart Store Monitoring System',
      'settings': 'Mga Setting',
      'theme': 'Kulay ng Tema',
      'red': 'Pula',
      'yellow': 'Dilaw',
      'blue': 'Asul',
      'english': 'Ingles',
      'filipino': 'Filipino',
      'language': 'Wika',
      'loading': 'Naglo-load...',
      // Admin
      'admin_dashboard': 'Admin Dashboard',
      'sign_out': 'Mag-sign Out',
      'manage_users': 'Pamamahala ng Gumagamit',
      'manage_products': 'Pamamahala ng Produkto',
      'manage_payroll': 'Pamamahala ng Payroll',
      'payroll': 'Payroll',
      'reports_coming': 'Mga Ulat (Darating)',
      'manage_users_title': 'Pamamahala ng Gumagamit',
      'manage_users_placeholder': 'Placeholder para sa Pag-manage ng User',
      'manage_products_title': 'Pamamahala ng Produkto',
      'manage_products_placeholder':
          'Placeholder para sa Pag-manage ng Produkto',
      'owner': 'May-ari',
      'cashier_role': 'Cashier',
      'manager': 'Manager',
      'sales_promoter': 'Sales Promoter',
      'inventory_clerk': 'Inventory Clerk',
      'delivery_receiver': 'Delivery Receiver',
      'other_role': 'Iba pa',
      'manage_attendance': 'Pamamahala ng Attendance',
      'attendance_for': 'Attendance para kay {name}',
      'clear_records': 'Burahin ang mga Rekord',
      'confirm_clear_attendance':
          'Sigurado ka bang gusto mong burahin ang attendance records ng user na ito?',
      'apply': 'Ilapat',
      'attendance': 'Attendance',
      'next': 'Susunod',
      'no_records': 'Wala pang rekord',
      // Owner
      'owner_dashboard': 'May-ari ng Tindahan',
      'customer_management': 'Pamamahala ng Customer',
      'loyalty_rewards': 'Loyalty Rewards',
      'search_customers': 'Maghanap ng customer...',
      'no_customers': 'Walang nahanap na customer',
      'add_customer': 'Magdagdag ng Customer',
      'edit_customer': 'I-edit ang Customer',
      'adjust_points': 'Ayusin ang Points',
      'deactivate_customer': 'I-deactivate ang Customer',
      'points_history': 'Kasaysayan ng Points',
      'current_points': 'Kasalukuyang Points',
      'points': 'Points',
      'estimated_loyalty_points': 'Tinatayang loyalty points',
      'estimated_loyalty_value': 'Halagang ₱{value}',
      'redemption_minimum_notice':
          'Kailangang may hindi bababa sa {n} points para makapag-redeem.',
      'scan_loyalty_barcode': 'I-scan ang Loyalty Barcode',
      'enter_loyalty_barcode': 'Ilagay ang Loyalty Barcode',
      'loyalty_barcode_id': 'Loyalty Barcode ID',
      'loyalty_customer_not_found':
          'Walang customer para sa loyalty barcode na ito',
      'loyalty_customer_linked': 'Naka-link ang loyalty customer: {name}',
      'apply_loyalty_redemption': 'Gamitin ang loyalty redemption',
      'redeemable_points': 'Points na puwedeng i-redeem',
      'loyalty_redemption': 'Loyalty Redemption',
      'loyalty_redemption_not_eligible':
          'Hindi eligible ang customer sa redemption para sa checkout na ito',
      'award': 'Ibigay',
      'redeem': 'I-redeem',
      'barcode_copied': 'Nakopya ang barcode sa clipboard',
      'barcode_generated_for_customer':
          'Nagawa ang barcode. Ibigay ang code na ito sa customer para sa loyalty.',
      'view_sales_reports': 'Tingnan ang Mga Ulat ng Benta',
      'monitor_cctv': 'Bantayan ang CCTV',
      'inventory_status': 'Katayuan ng Imbentaryo',
      // Manager
      'manager_dashboard': 'Manager',
      // Sales Promoter
      'sales_promoter_dashboard': 'Dashboard ng Promotor ng Benta',
      // Inventory Clerk
      'inventory_clerk_dashboard': 'Dashboard ng Klerk ng Imbentaryo',
      // Delivery Receiver
      'delivery_receiver_dashboard': 'Dashboard ng Tumatanggap ng Delivery',
      // Cashier
      'cashier_dashboard': 'Cashier Dashboard',
      'open_pos': 'Buksan ang POS Terminal',
      'price_checker': 'Pagsusuri ng Presyo',
      'scan_check_product_prices': 'I-scan at Suriin ang Presyo ng Produkto',
      'cashier_pos': 'Cashier POS',
      'item_out_of_stock': 'Wala sa stock ang item',
      'only_x_left': 'May natira lamang na {n}',
      'stock_label': 'Stock: {n}',
      'cart_empty': 'Walang laman ang Cart',
      'cart': 'Cart',
      'total_prefix': 'Kabuuan: ₱',
      'checkout': 'Mag-checkout',
      'close': 'Isara',
      'sale_recorded': 'Nairekord na benta (ID: {id})',
      'not_enough_stock_for': 'Kulang ang stock para sa {name}',
      'sales_log_title': 'Tala ng Benta (Local Demo)',
      'no_sales_yet': 'Wala pang benta',
      'sale_label': 'Benta {id}',
      'sales_log_tooltip': 'Tala ng Benta',
      'open_cart_tooltip': 'Buksan ang Cart',
      'cart_count': 'Kart ({count})',
      'payment_method': 'Paraan ng Pagbabayad',
      'select_payment': 'Pumili ng Paraan ng Pagbabayad',
      'cash': 'Cash',
      'gcash': 'GCash',
      'online_bank': 'Online Bank',
      'amount_tendered': 'Halagang Ibinayad',
      'change': 'Sukli',
      'insufficient_cash': 'Kulang ang halagang ibinayad',
      'enter_amount': 'Ilagay ang halaga',
      'payment_summary': 'Buod ng Bayad',
      'subtotal': 'Subtotal',
      'discount': 'Diskwento',
      'grand_total': 'Kabuuang Bayad',
      'confirm_payment': 'Kumpirmahin ang Bayad',
      'insufficient_amount': 'Kulang ang halaga',
      'cancel_sale': 'Kanselahin ang Benta',
      'cancelled': 'KINANSELA',
      'cancellation_reason': 'Dahilan ng Pagkansela',
      'enter_cancellation_reason': 'Ilagay ang dahilan ng pagkansela...',
      'confirm_cancellation': 'Kumpirmahin ang Pagkansela',
      'sale_cancelled_successfully': 'Matagumpay na kinansela ang benta',
      // Delivery Orders
      'for_delivery': 'Para sa Delivery',
      'delivery_order': 'Order para sa Delivery',
      'delivery_order_created': 'Nagawa ang Order para sa Delivery',
      'delivery_order_success_message':
          'Matagumpay na nagawa ang delivery order',
      'failed_to_create_delivery': 'Nabigo ang paggawa ng delivery order',
      'delivery_notes': 'Mga Tala para sa Delivery',
      'enter_delivery_notes_hint':
          'Ilagay ang address ng customer, contact, o espesyal na tagubilin...',
      'create_delivery_order': 'Gumawa ng Delivery Order',
      'customer_information': 'Impormasyon ng Customer',
      'customer_name': 'Pangalan ng Customer',
      'contact_number': 'Numero ng Telepono',
      'complete_address': 'Buong Address',
      'enter_customer_name': 'Ilagay ang pangalan ng customer',
      'enter_contact_number': 'Ilagay ang numero ng telepono',
      'enter_complete_address': 'Ilagay ang buong address para sa delivery',
      'customer_name_required': 'Kailangan ang pangalan ng customer',
      'contact_number_required': 'Kailangan ang numero ng telepono',
      'address_required': 'Kailangan ang buong address',
      // Reservation
      'reservation_order': 'Reservasyon',
      'reservation_order_hint':
          'Magbayad ng reservation fee ngayon, buong bayad mamaya',
      'reservation_fee': 'Bayad sa Reservasyon',
      'reserve_order': 'I-reserve ang Order',
      'pending_payment': 'Naghihintay ng Bayad',
      'full_pay': 'Buong Bayad',
      'remaining_balance': 'Natitirang Balanse',
      'payment_completed': 'Tapos na ang Bayad',
      'reserved_orders': 'Mga Naka-reserve na Order',
      // Inventory Screen
      'search_products': 'Maghanap gamit ang pangalan o barcode...',
      'search_product_name_barcode':
          'Maghanap gamit ang pangalan o barcode ng produkto...',
      'no_products': 'Walang available na produkto',
      'barcode': 'Barcode',
      'category': 'Kategorya',
      'stock': 'Stock',
      'stock_quantity': 'Dami ng Stock',
      'update_stock': 'I-update ang Stock',
      'view_movements': 'Tingnan ang Kilusan',
      'add_product': 'Magdagdag ng Produkto',
      'name': 'Pangalan',
      'selling_price': 'Presyong Benta',
      'quantity': 'Dami',
      'cancel': 'Kanselahin',
      'confirm': 'Kumpirma',
      'save': 'I-save',
      'add': 'Magdagdag',
      'verify': 'I-verify',
      'clear': 'Burahin',
      'units': 'piraso',
      'product_found': 'Nahanap ang Produkto',
      'product_not_found': 'Hindi Nahanap ang Produkto',
      'align_barcode_within_frame':
          'Ilagay ang barcode sa loob ng frame para i-scan',
      'low_stock': 'Mababang Stock',
      'low_stock_warning': 'Mababa ang Stock - Mangyaring Mag-restock',
      'price_checker_empty_title': 'Magsimula ng Pagsuri ng Presyo',
      'price_checker_empty_subtitle':
          'I-scan ang barcode o maghanap ng produkto para makita ang presyo at stock',
      'scan': 'I-scan',
      'search': 'Maghanap',
      'view_details': 'Detalye',
      'owner_verification': 'Kailangan ng Owner Verification',
      'enter_owner_password':
          'Mangyaring ilagay ang owner password para ma-access ang CCTV monitoring',
      'invalid_owner_password': 'Maling owner password',
      'inventory_movements': 'Kilusan ng Imbentaryo',
      'no_movements': 'Walang narekordong kilusan',
      // Product Management
      'edit_product': 'I-edit ang Produkto',
      'delete_product': 'Tanggalin ang Produkto',
      'product_details': 'Detalye ng Produkto',
      'buying_price': 'Presyong Bili',
      'description': 'Paglalarawan',
      'reorder_level': 'Antas ng Babala sa Mababang Stock',
      'image': 'Larawan',
      'select_image': 'Pumili ng Larawan',
      'product_added': 'Matagumpay na naidagdag ang produkto',
      'product_updated': 'Matagumpay na na-update ang produkto',
      'product_deleted': 'Matagumpay na natanggal ang produkto',
      'confirm_delete': 'Kumpirmahin ang Pagtanggal',
      'delete_product_msg': 'Sigurado ka bang gusto mong tanggalin ang {name}?',
      'delete': 'Tanggalin',
      'low_stock_items': 'Mga Item na Mababa ang Stock ({count})',
      'all_products': 'Lahat ng Produkto',
      'profit': 'Kita',
      'low_stock_alert': 'MABABA ANG STOCK!',
      'optional': 'Opsyonal',
      // Inventory Management
      'inventory_levels': 'Antas ng Imbentaryo',
      'restock_delivery': 'Restock / Paghahatid',
      'adjust_pricing': 'Ayusin ang Presyo',
      'filter_by': 'I-filter Ayon sa',
      'all_items': 'Lahat ng Item',
      'low_stock_only': 'Mababang Stock Lamang',
      'out_of_stock': 'Walang Stock',
      'in_stock': 'May Stock',
      'restock_item': 'Restock ng Item',
      'delivery_received': 'Natanggap ang Delivery',
      'quantity_received': 'Dami ng Natanggap',
      'supplier': 'Supplier',
      'delivery_note': 'Tala ng Delivery',
      'damage_item': 'Sirang Item',
      'damaged_items': 'Sirang mga Item',
      'quantity_damaged': 'Dami ng Sira',
      'damage_reason': 'Dahilan ng Pagkasira',
      'damage_recorded': 'Matagumpay na naitala ang pagkasira',
      'record_damage': 'Itala ang Pagkasira',
      'record_delivery': 'Irekord ang Delivery',
      'delivery_recorded': 'Matagumpay na nairekord ang delivery',
      'adjust_price': 'Ayusin ang Presyo',
      'new_price': 'Bagong Presyo',
      'price_updated': 'Matagumpay na na-update ang presyo',
      'current_price': 'Kasalukuyang Presyo',
      'new_buying_price': 'Bagong Presyong Bili',
      'new_selling_price': 'Bagong Presyong Benta',
      'profit_margin': 'Margin ng Kita',
      'update_prices': 'I-update ang Presyo',
      'items_found': '{count} na item ang nahanap',
      // Supplier Management
      'supplier_management': 'Pamamahala ng Supplier',
      'manage_suppliers_desc':
          'Pamahalaan ang mga supplier at kasaysayan ng restock',
      'suppliers': 'Mga Supplier',
      'restock_history': 'Kasaysayan ng Restock',
      'add_supplier': 'Magdagdag ng Supplier',
      'edit_supplier': 'I-edit ang Supplier',
      'supplier_name': 'Pangalan ng Supplier',
      'contact_person': 'Taong Makikipag-ugnayan',
      'phone': 'Telepono',
      'address': 'Address',
      'notes': 'Mga Tala',
      'no_suppliers': 'Walang supplier na naidagdag pa',
      'no_restock_records': 'Walang restock records pa',
      'supplier_added': 'Matagumpay na naidagdag ang supplier',
      'supplier_updated': 'Matagumpay na na-update ang supplier',
      'supplier_deleted': 'Matagumpay na natanggal ang supplier',
      'supplier_activated': 'Na-activate ang supplier',
      'supplier_deactivated': 'Na-deactivate ang supplier',
      'delivery_receipt_no': 'Numero ng Resibo ng Delivery',
      'receipt_no': 'Numero ng Resibo',
      'has_damaged_items': 'Mag-ulat ng sirang item sa delivery',
      'damage_details': 'Detalye ng Pinsala',
      'damage_info': 'Impormasyon ng Pinsala',
      'enter_valid_quantity': 'Maglagay ng wastong dami',
      'enter_damage_quantity': 'Maglagay ng dami ng sira',
      'damage_exceeds_received':
          'Dami ng sira ay hindi maaaring lumampas sa natanggap',
      'damaged': 'Sira',
      'restock_details': 'Detalye ng Restock',
      'reason': 'Dahilan',
      'serial_number': 'Serial Number',
      'damage_from': 'Damage mula sa',
      'reason_optional': 'hal., Nasira sa delivery',
      // Purchase Orders
      'purchase_orders': 'Mga Purchase Order',
      'create_order': 'Lumikha ng Order',
      'order_number': 'Numero ng Order',
      'order_date': 'Petsa ng Order',
      'expected_delivery': 'Inaasahang Petsa ng Delivery',
      'order_status': 'Katayuan',
      'pending': 'Naghihintay',
      'approved': 'Naaprubahan',
      'completed': 'Nakumpleto',
      'received': 'Natanggap',
      'restock': 'Mag-restock',
      'restock_items': 'Mag-restock ng Items',
      'delivery_receipt': 'Resibo ng Delivery',
      'delivery_receipt_required': 'Kailangan ang numero ng resibo ng delivery',
      'ordered': 'Naka-order',
      'restock_success':
          'Matagumpay na nag-restock at naka-marka ang order bilang natanggap',
      'no_orders': 'Walang purchase order pa',
      'add_products': 'Magdagdag ng Produkto',
      'select_products': 'Pumili ng Produkto',
      'unit_price': 'Presyo bawat Piraso',
      'total_value': 'Kabuuang Halaga',
      'approve_order': 'Aprubahan ang Order',
      'sign_here': 'Lumagda Dito',
      'clear_signature': 'Burahin',
      'signature_required': 'Kailangan ang lagda para sa pag-apruba',
      'order_approved': 'Matagumpay na naaprubahan ang order',
      'order_created': 'Matagumpay na nalikha ang purchase order',
      'order_updated': 'Matagumpay na na-update ang purchase order',
      'order_deleted': 'Matagumpay na natanggal ang purchase order',
      'delete_order_confirm':
          'Sigurado ka bang gusto mong tanggalin ang order na ito?',
      'order_details': 'Detalye ng Order',
      'add_item': 'Magdagdag ng Item',
      'remove_item': 'Alisin',
      'create_purchase_order': 'Gumawa ng Purchase Order',
      'order_from_supplier': 'Umorder sa Supplier',
      'select_product': 'Pumili ng Produkto',
      'select_supplier': 'Pumili ng supplier',
      'enter_quantity': 'Maglagay ng Dami',
      'enter_unit_price': 'Maglagay ng Presyo',
      'no_items': 'Walang item na naidagdag pa',
      'at_least_one_item': 'Magdagdag ng kahit isang item',
      'approval_signature': 'Lagda ng Pag-apruba',
      'approved_on': 'Naaprubahan Noong',
      'mark_completed': 'Markahan Bilang Tapos',
      // Reports continued
      'please_fill_required_fields':
          'Pakipunan lahat ng kinakailangang patlang',
      'delete_supplier_confirm':
          'Sigurado ka bang gusto mong tanggalin ang supplier na "{name}"? Hindi na ito maibabalik.',
      'no_results_found': 'Walang nahanap na resulta',
      'reports': 'Mga Ulat',
      'sales_report': 'Ulat ng Benta',
      'inventory_report': 'Ulat ng Imbentaryo',
      'activity_logs': 'Mga Talaan ng Aktibidad',
      'select_date_range': 'Pumili ng Saklaw ng Petsa',
      'refresh': 'I-refresh',
      'total_sales': 'Kabuuang Benta',
      'transactions': 'Mga Transaksyon',
      'avg_transaction': 'Avg na Transaksyon',
      'items_sold': 'Mga Naibentang Item',
      'sales_trend': 'Takbo ng Benta',
      'top_selling_products': 'Pinakamabentang Produkto',
      'recent_transactions': 'Kamakailang Transaksyon',
      'daily_sales': 'Arawang Benta',
      'today_total_sales': 'Kabuuan Ngayong Araw',
      'today_transactions': 'Transaksyon Ngayong Araw',
      'average_sale_value': 'Average na Halaga ng Benta',
      'select_day': 'Pumili ng Araw',
      'export_csv': 'I-export ang CSV',
      'export_success': 'Matagumpay na na-export',
      'no_sales_data': 'Walang data ng benta',
      'no_transactions': 'Walang nahanap na transaksyon',
      'total_products': 'Kabuuang Produkto',
      'inventory_value': 'Halaga ng Imbentaryo',
      'inventory_by_category': 'Imbentaryo ayon sa Kategorya',
      'products': 'mga produkto',
      'system_activity': 'Aktibidad ng Sistema',
      'no_activity': 'Walang nahanap na aktibidad',
      'activity_summary': 'Buod ng Aktibidad',
      'total_activities': 'Kabuuang Aktibidad',
      'sales_transactions': 'Mga Transaksyon ng Benta',
      'date_range': 'Saklaw ng Petsa',
      'no_data_available': 'Walang available na data',
      'sale': 'Benta',
      // Receipt
      'receipt_header': 'SMART MONITORING POS',
      'receipt_number': 'Resibo #',
      'date': 'Petsa',
      'cashier': 'Kahera',
      'processed_by': 'Pinroseso ni',
      'thank_you': 'Salamat sa iyong pagbili!',
      'transaction_completed': 'Matagumpay na Nakumpleto ang Transaksyon',
      'payment_successful':
          'Matagumpay na naproseso ang iyong pagbabayad. Gusto mo bang mag-print ng resibo?',
      'print_receipt': 'I-print ang Resibo',
      // Login & Auth
      'admin_login_method': 'Paraan ng Pag-login ng Admin',
      'email_gmail': 'Email / Gmail',
      'email_placeholder': 'admin@example.com',
      'contact_number_short': 'Contact Number',
      'contact_placeholder': '+639123456789',
      'password_placeholder': '••••••••',
      'sign_in_google_admin': 'Mag-sign in gamit ang Google (Owner Lamang)',
      'or': 'O',
      'create_admin_account': 'Gumawa ng Admin Account',
      'forgot_password': 'Nakalimutan ang Password? (Owner Lamang)',
      'reset_admin_password': 'I-reset ang Admin Password',
      'reset_owner_password': 'I-reset ang Owner Password',
      'send_otp': 'Magpadala ng OTP',
      'enter_otp': 'Ilagay ang OTP',
      'otp_sent_to_email': 'Isang verification code ang ipinadala sa {email}',
      'tokens': 'Token',
      'confirm_password': 'Kumpirmahin ang Password',
      'secure_access_portal': 'Secure na Portal ng Access',
      'please_fill_all_fields': 'Pakipunan ang lahat ng fields',
      'valid_email_required':
          'Pakipasok ang valid na email (hal., admin@gmail.com)',
      'valid_contact_required':
          'Pakipasok ang valid na contact number (hal., +639123456789)',
      'password_min_6': 'Ang password ay dapat hindi bababa sa 6 characters',
      'passwords_not_match': 'Hindi tugma ang mga password',
      'admin_created_success':
          'Matagumpay na nagawa ang admin account! Maaari ka nang mag-login.',
      'account_creation_failed':
          'Nabigo ang paggawa ng account. Pakisuri ang iyong mga input.',
      'password_confirm': 'Kumpirmahin ang Password',
      'password_min_6_hint': 'Password (min 6 characters)',
      'windows_verify_identity':
          'Ipasok ang iyong Windows lockscreen password upang i-verify ang iyong pagkakakilanlan',
      'windows_user_label': 'Windows User: {username}',
      'windows_password_hint':
          'Ito ang password na ginagamit mo para mag-log in sa Windows',
      'windows_password': 'Windows Password',
      'device_verify_identity': 'Patunayan ang Iyong Pagkakakilanlan',
      'device_lockscreen': 'Device Lockscreen',
      'device_password_hint':
          'Ilagay ang password na ginagamit mo upang i-unlock ang iyong device',
      'device_password': 'Device Password',
      'enter_device_password': 'Pakiusap ilagay ang iyong device password',
      'device_auth_success':
          'Matagumpay ang device authentication! Ngayon magtakda ng iyong bagong admin password',
      'invalid_device_password':
          'Maling device password. Pakiusap subukan muli.',
      'device_auth_not_available':
          'Ang device authentication ay hindi available sa device na ito',
      'enter_new_password': 'Ipasok ang iyong bagong password',
      'new_password_min_6': 'Bagong Password (min 6 chars)',
      'verify_button': 'I-verify',
      'reset_password_button': 'I-reset ang Password',
      'enter_windows_password': 'Pakipasok ang iyong Windows password',
      'windows_auth_success':
          'Matagumpay ang Windows authentication! Ngayon ay itakda ang iyong bagong admin password',
      'invalid_windows_password':
          'Invalid ang Windows password. Pakisubukan muli.',
      'authentication_error': 'Error sa authentication: {error}',
      'password_reset_success': 'Matagumpay na na-reset ang password',
      'password_reset_failed': 'Nabigo ang pag-reset ng password',
      // CCTV
      'cctv_monitoring': 'Pagsubaybay sa CCTV',
      'camera_url': 'URL ng Camera / RTSP Stream',
      'recordings_directory': 'Direktoryo ng mga Recording (Opsyonal)',
      'add_camera': 'Magdagdag ng Camera',
      'configure_camera': 'I-configure ang Camera',
      'remove_camera': 'Alisin ang Camera',
      'camera_name': 'Pangalan ng Camera',
      'camera_type': 'Uri ng Camera',
      'no_cameras': 'Walang naidagdag na camera',
      'add_first_camera': 'Magdagdag ng unang camera para magsimula',
      'camera_added': 'Matagumpay na naidagdag ang camera',
      'camera_updated': 'Matagumpay na na-update ang camera',
      'camera_deleted': 'Matagumpay na natanggal ang camera',
      'confirm_delete_camera': 'Tanggalin ang camera na ito?',
      'camera_grid': 'Grid ng Camera',
      'select_camera': 'Pumili ng camera para tingnan',
      // Sales Reports
      'sales_results': 'Mga Resulta ng Benta',
      'sales_reports': 'Mga Ulat ng Benta',
      // Product Camera
      'capture_product_image': 'Kunan ang Larawan ng Produkto',
      // User Management
      'deactivate_user': 'I-deactivate ang User',
      'deactivate': 'I-deactivate',
      'no_users_yet': 'Walang user pa',
      'add_user': 'Magdagdag ng User',
      // Settings
      'reduce_motion': 'Bawasan ang Paggalaw (limitahan ang galaw)',
      // Navigation subtitles
      'open_cash_register': 'Buksan ang cash register',
      'process_customer_payments': 'Magproseso ng bayad ng customer',
      'manage_admin_account': 'Pamahalaan ang Admin Account',
      'welcome_user': 'Maligayang pagdating, {name}',
      // System Reset
      'reset_all_data': 'I-reset ang Lahat ng Datos',
      'reset_all_data_desc':
          'Tanggalin ang LAHAT ng produkto, benta at imbentaryo at magsimula muli',
      'confirm_reset_title': 'Kumpirmahin ang Buong Reset',
      'confirm_reset_message':
          'Permanenteng buburahin ang LAHAT ng tala ng POS. I-type ang RESET para magpatuloy.',
      'type_reset_label': 'I-type ang RESET para kumpirmahin',
      'reset': 'I-reset',
      'reset_success': 'Matagumpay na nabura ang datos',
      'reset_cancelled': 'Kinansela ang reset',
      'reset_all_data_tooltip': 'Panganib: I-reset ang Datos ng Sistema',
      // Admin Account Management
      'edit': 'I-edit',
      'account_information': 'Impormasyon ng Account',
      'full_name': 'Buong Pangalan',
      'email_address': 'Email Address',
      'account_contact_number': 'Contact Number (para sa SMS recovery)',
      'contact_hint': '+63 912 345 6789',
      'save_changes': 'I-save ang mga Pagbabago',
      'security': 'Seguridad',
      'change_password': 'Baguhin ang Password',
      'security_message':
          'Palitan ang iyong password nang regular para mapanatili ang seguridad ng account.',
      'account_created': 'Ginawa ang Account',
      'last_updated': 'Huling Na-update',
      'never': 'Hindi pa',
      'account_updated_success': 'Matagumpay na na-update ang account',
      'fill_required_fields':
          'Pakipunan ang lahat ng kinakailangang field na may valid na email',
      'password_changed_success': 'Matagumpay na nabago ang password',
      'current_password': 'Kasalukuyang Password',
      'new_password': 'Bagong Password (minimum 6 characters)',
      'confirm_new_password': 'Kumpirmahin ang Bagong Password',
      'update_password': 'I-update ang Password',
      'current_password_incorrect': 'Mali ang kasalukuyang password',
      'new_password_min_length':
          'Ang bagong password ay dapat hindi bababa sa 6 na character',
      'passwords_do_not_match': 'Hindi tugma ang mga password',
      'admin_password_conflict':
          'Ang admin password ay dapat magkaiba sa mga password ng owner',
      'last_updated_date': 'Huling na-update: {date}',
      'damage_reports': 'Mga Ulat ng Sira',
      'total_damaged_items': 'Kabuuang Sirang Item',
      'total_value_lost': 'Kabuuang Halaga na Nawala',
      'view_admin_reports': 'Tingnan ang Mga Ulat ng Admin',
      'no_damage_reports': 'Walang ulat ng sira pa',
      'value': 'Halaga',
      'reported_by': 'Nag-ulat',
      'return_to_supplier': 'Ibalik sa Supplier',
      'return_status': 'Status ng Pagbabalik',
      'return_approval': 'Pag-apruba ng Pagbabalik',
      'approve_return': 'Aprubahan ang Pagbabalik',
      'return_approved': 'Matagumpay na naaprubahan ang pagbabalik',
      'returned': 'Naibalik Na',
      'pending_return': 'Naghihintay',
      'return_date': 'Petsa ng Pagbabalik',
      'approved_by': 'Nag-apruba',
      'damage_return_report': 'Ulat ng Pagbabalik ng Sira',
      'export_return_pdf': 'I-export ang Return PDF',
      // Store Damage Payment
      'proceed_to_payment': 'Magpatuloy sa Pagbabayad',
      'select_responsible_person': 'Pumili ng Responsableng Tao',
      'all_staff': 'Lahat ng Staff',
      'payment_responsibility': 'Responsibilidad sa Pagbayad',
      'store_damage_payment': 'Bayad sa Pagkasira ng Tindahan',
      'responsible_person': 'Responsableng Tao',
      'payment_processed': 'Matagumpay na naproseso ang bayad',
      'store_damage_paid': 'Nabayaran na ang Store Damage',
      'payment_pending': 'Naghihintay ng Bayad',
      'payment_date': 'Petsa ng Pagbabayad',
      'assign_payment_to': 'Itakda ang bayad sa:',
      'shared_responsibility': 'Ibinahagi sa lahat ng miyembro ng staff',
      'no_users_found': 'Walang nahanap na users sa system',
      'already_paid': 'Nabayaran Na',
      // CCTV Timestamps
      'timestamps_log': 'Tala ng Timestamps',
      'saved_timestamps': 'Mga Naka-save na CCTV Timestamps',
      'no_timestamps_saved': 'Walang naka-save na timestamps pa',
      'view_footage': 'Tingnan ang Footage',
      'export_video': 'I-export ang Video',
      'video_exported': 'Naka-export ang Video',
      'file_path': 'Lokasyon ng File',
      'video_export_success': 'Matagumpay na nai-export ang video',
      'video_export_failed': 'Nabigo ang pag-export ng video',
      'delete_timestamp_confirm':
          'Sigurado ka bang gusto mong tanggalin ang timestamp na ito?',
      'clear_all': 'Burahin Lahat',
      'clear_all_timestamps_confirm':
          'Sigurado ka bang gusto mong burahin ang lahat ng naka-save na timestamps?',
      // Business Registration
      'business_registration': 'Rehistro ng Negosyo',
      'business_registration_title': 'Irehistro ang Iyong Negosyo',
      'business_registration_subtitle':
          'I-setup ang impormasyon ng iyong tindahan upang i-personalize ang sistema',
      'store_logo': 'Logo ng Tindahan',
      'tap_to_upload_logo': 'I-tap upang mag-upload ng logo',
      'store_name_label': 'Pangalan ng Tindahan',
      'store_name_hint': 'Ilagay ang pangalan ng iyong tindahan',
      'store_name_required': 'Kailangan ang pangalan ng tindahan',
      'business_type_label': 'Uri ng Negosyo',
      'select_business_type': 'Pumili ng uri ng negosyo',
      'business_type_required': 'Kailangan ang uri ng negosyo',
      'store_address_label': 'Address ng Tindahan',
      'store_address_hint':
          'Ilagay ang address ng tindahan (kalye, lungsod, zip code)',
      'save_business_info': 'I-save ang Impormasyon ng Negosyo',
      'saving': 'Nag-save...',
      'business_info_saved':
          'Matagumpay na na-save ang impormasyon ng negosyo!',
      'business_info_save_failed':
          'Nabigo ang pag-save ng impormasyon ng negosyo',

      // Shoe Store Features
      'shoe_size_section': 'Impormasyon ng Laki ng Sapatos',
      'size_type': 'Uri ng Laki',
      'men_sizes': 'Laki para sa Lalaki',
      'women_sizes': 'Laki para sa Babae',
      'unisex_sizes': 'Unisex na Laki',
      'enter_quantity_per_size': 'Ilagay ang dami para sa bawat laki:',
      'shoe_sizes_available': 'Mga Available na Laki ng Sapatos',
      'tap_to_view_sizes': '👟 I-tap upang tingnan ang mga laki',
      'select_size': 'Pumili ng Laki',
      'multiple_sizes': 'Maraming Laki',
      'added_to_cart': 'naidagdag sa cart',

      // Privacy Policy & User Agreement
      'legal': 'Legal',
      'privacy_policy': 'Patakaran sa Privacy',
      'user_agreement': 'Kasunduan ng Gumagamit',
      // About System
      'about': 'Tungkol',
      'about_system': 'Tungkol sa Sistema',
      'system_subtitle': 'Integrated POS at CCTV Monitoring',
      'developed_by': 'Ginawa Ni',
      'brand': 'Brand',
      'version': 'Bersyon',
      'release_date': 'Petsa ng Release',
      'about_description':
          'Isang komprehensibong retail management solution na pinagsasama ang Point-of-Sale operations at advanced CCTV monitoring capabilities. Dinisenyo upang gawing mas simple ang mga operasyon ng negosyo at pahusayin ang seguridad.',
      // Financial Monitoring
      'financial_monitoring': 'Pagsubaybay sa Pananalapi',
      'financial_monitoring_desc':
          'Subaybayan ang kita, suriin ang mga uso, i-export ang mga ulat',
      'start_date': 'Simulang Petsa',
      'end_date': 'Huling Petsa',
      'total_revenue': 'Kabuuang Kita',
      'average_transaction': 'Average na Transaksyon',
      'daily_revenue_chart': 'Tsart ng Araw-araw na Kita',
      'exporting': 'Nag-e-export...',
      'pdf_saved': 'Matagumpay na na-save ang PDF',
      'csv_saved': 'Matagumpay na na-save ang CSV',
      'transaction_id': 'ID ng Transaksyon',
      'amount': 'Halaga',
      'financial_report': 'Ulat sa Pananalapi',
      'report_period': 'Panahon ng Ulat',
      'summary': 'Buod',
      'transaction_details': 'Detalye ng Transaksyon',
      // Privacy Policy Content
      'privacy_last_updated': 'Huling Na-update: Disyembre 12, 2025',
      'agreement_last_updated': 'Huling Na-update: Disyembre 12, 2025',
      'privacy_intro_title': '1. Panimula',
      'privacy_intro_content':
          'Maligayang pagdating sa Smart Monitoring System na may Integrated POS at CCTV. Ang Patakaran sa Privacy na ito ay nagpapaliwanag kung paano namin kinokolekta, ginagamit, at pinoprotektahan ang iyong personal na impormasyon sa paggamit ng aming sistema. Sa paggamit ng application na ito, sumasang-ayon ka sa pagkolekta at paggamit ng impormasyon alinsunod sa patakarang ito.',
      'privacy_data_collection_title': '2. Impormasyong Kinokolekta Namin',
      'privacy_data_collection_content':
          'Kinokolekta namin ang impormasyong kinakailangan para sa operasyon ng sistema kabilang ang: Impormasyon ng user account (pangalan, email, contact number, tungkulin), Datos ng produkto (pangalan, barcode, presyo, antas ng imbentaryo), Mga tala ng transaksyon sa pagbebenta, CCTV footage at timestamps, Kasaysayan ng paggalaw ng imbentaryo, at Impormasyon ng device para sa authentication. Lahat ng datos ay naka-imbak nang lokal sa iyong device.',
      'privacy_data_usage_title':
          '3. Paano Namin Ginagamit ang Iyong Impormasyon',
      'privacy_data_usage_content':
          'Ang iyong impormasyon ay ginagamit lamang para sa: Pagproseso ng mga transaksyon sa pagbebenta, Pamamahala ng imbentaryo at antas ng stock, User authentication at role-based access control, Paggawa ng mga ulat at analytics sa pagbebenta, CCTV monitoring at mga layuning panseguridad, Pagsubaybay sa mga paggalaw ng produkto at mga ulat ng sira. Hindi namin ibinabahagi ang iyong datos sa third parties.',
      'privacy_data_storage_title': '4. Pag-iimbak at Pagreretain ng Datos',
      'privacy_data_storage_content':
          'Ang pangunahing datos ng application ay naka-imbak nang lokal gamit ang SQLite database sa iyong device. Ang opsyonal na cloud sync at mga feature ng lisensya/subscription ay maaaring gumamit ng MySQL/Supabase backend kapag na-configure. Ang lokal na datos ay mananatili hanggang sa manu-manong tanggalin ng awtorisadong administrators, at ang CCTV footage ay naka-imbak batay sa available na storage capacity ng device. Mayroon kang ganap na kontrol sa data retention at deletion.',
      'privacy_security_title': '5. Mga Hakbang sa Seguridad',
      'privacy_security_content':
          'Nagpapatupad kami ng mga pamantayang hakbang sa seguridad kabilang ang: Role-based access control (Admin, Owner, Cashier), Secure na lokal na pag-iimbak ng database, PIN at password authentication, Device-level encryption (kung available), Regular na mga security update. Gayunpaman, walang sistema na ganap na secure, at ikaw ay responsable sa pagpapanatili ng seguridad ng device.',
      'privacy_rights_title': '6. Iyong Mga Karapatan',
      'privacy_rights_content':
          'Mayroon kang karapatan na: I-access ang iyong personal na impormasyon, Humiling ng mga pagwawasto o update ng datos, Tanggalin ang iyong account at kaugnay na datos, Mag-export ng mga tala ng transaksyon at mga ulat, Mag-opt-out ng CCTV recording sa mga non-security area. Makipag-ugnayan sa iyong system administrator upang gamitin ang mga karapatang ito.',
      // Karagdagang legal tools
      'dependency_licenses': 'Lisensya ng Mga Dependency',
      'dependency_licenses_desc':
          'Tingnan ang mga open-source license ng mga naka-bundle na package.',
      'update_privacy_policy': 'I-edit ang Patakaran sa Privacy',
      'update_terms': 'I-edit ang Mga Tuntunin at Kundisyon',
      'pci_guidance_title': 'PCI Gabay',
      'pci_guidance_summary':
          'Pangunahing gabay kung tumatanggap ka ng card payments',
      'pci_guidance_content':
          'Kung tumatanggap ka ng card payments, gumamit ng PCI-compliant na payment processor. Iwasang mag-imbak ng card numbers, gumamit ng TLS para sa network communication, panatilihin ang unique admin accounts, i-update ang mga device at software, at magsagawa ng regular na security review. Para sa kumpletong pagsunod, kumunsulta sa isang PCI Qualified Security Assessor (QSA).',
      // User Agreement Content
      'agreement_acceptance_title': '1. Pagtanggap ng mga Tuntunin',
      'agreement_acceptance_content':
          'Sa pag-access at paggamit ng Smart Monitoring System, tinatanggap mo at sumasang-ayon na sumunod sa mga tuntunin at kondisyon ng kasunduang ito. Kung hindi ka sumasang-ayon sa mga tuntuning ito, mangyaring ihinto kaagad ang paggamit. Ang kasunduang ito ay nalalapat sa lahat ng users kabilang ang mga administrator, may-ari ng tindahan, at mga cashier.',
      'agreement_license_title': '2. Lisensya at Paggamit',
      'agreement_license_content':
          'Binibigyan ka namin ng limitadong, non-exclusive, non-transferable na lisensya upang gamitin ang software na ito para sa mga operasyon ng retail business. Ang lisensiyang ito ay valid para sa organisasyong nag-deploy ng sistema. Maaari mong gamitin ang sistema sa maraming device sa loob ng iyong organisasyon ayon sa awtorisasyon ng iyong administrator.',
      'agreement_restrictions_title': '3. Mga Paghihigpit',
      'agreement_restrictions_content':
          'Sumasang-ayon ka na HUWAG: Mag-reverse engineer, mag-decompile, o mag-disassemble ng software, Magbahagi ng login credentials sa mga hindi awtorisadong tao, Subukang i-bypass ang mga hakbang sa seguridad o role-based access controls, Gamitin ang sistema para sa mga ilegal na aktibidad o mga pekeng transaksyon, Mandaya o magtanggal ng audit logs, CCTV footage, o mga tala ng transaksyon, Mag-redistribute o magbenta muli ng software nang walang awtorisasyon.',
      'agreement_responsibilities_title': '4. Mga Responsibilidad ng User',
      'agreement_responsibilities_content':
          'Ang mga user ay responsable para sa: Pagpapanatili ng pagiging kumpidensyal ng login credentials, Pag-uulat ng mga paglabag sa seguridad kaagad, Pagtiyak ng tumpak na pagpasok ng datos para sa mga produkto at transaksyon, Pagsunod sa tamang checkout at mga pamamaraan sa imbentaryo, Regular na mga backup ng datos (responsibilidad ng administrator), Pagsunod sa mga lokal na batas at regulasyon tungkol sa mga POS system at CCTV monitoring.',
      'agreement_liability_title': '5. Limitasyon ng Pananagutan',
      'agreement_liability_content':
          'Ang software na ito ay ibinibigay "as is" nang walang anumang uri ng warranty. Hindi kami mananagot para sa: Pagkawala ng datos dahil sa pagkabigo ng device, mga isyu sa hardware, o pagkakamali ng user, Mga pagkalugi sa negosyo na nagreresulta mula sa downtime o mga error ng sistema, Mga pinsala mula sa hindi awtorisadong access dahil sa kapabayaan ng user, Mga isyung nagmumula sa hindi wastong paggamit o configuration. Ang mga user ay tumatanggap ng lahat ng panganib na nauugnay sa paggamit ng sistema.',
      'agreement_termination_title': '6. Pagtatapos',
      'agreement_termination_content':
          'Ang kasunduang ito ay nananatiling epektibo hanggang sa wakasan. Ang iyong access ay maaaring wakasan kaagad nang walang paunawa kung lumabag ka sa anumang tuntunin ng kasunduang ito. Sa pagtatapos, dapat mong ihinto ang lahat ng paggamit ng sistema. Ang datos ay maaaring panatilihin ayon sa kinakailangan ng batas o pangangailangan ng negosyo. Ang mga administrator ay may karapatang mag-deactivate ng mga user account anumang oras.',

      // User Manual Sections (Filipino)
      'manual_installation': 'Mga Tagubilin sa Pag-install',
      'manual_installation_content': '''Mga Kinakailangan ng Sistema:

Windows Desktop:
- Windows 10 o mas bago (64-bit)
- Minimum 4GB RAM
- 500MB libreng disk space
- Screen resolution: 1280x720 o mas mataas

Android:
- Android 7.0 (Nougat) o mas bago
- Minimum 2GB RAM
- 200MB libreng storage

iOS:
- iOS 12.0 o mas bago
- iPhone 6s o mas bago
- iPad Air 2 o mas bago

Mga Hakbang sa Windows Installation:
1. I-download ang installer o hanapin ang executable file
2. I-double-click para patakbuhin ang application
3. Bigyan ng camera at file access permissions
4. Lalabas ang login screen - handa na ang sistema

Android/iOS Installation:
1. I-install ang APK file (Android) o mula sa App Store (iOS)
2. Bigyan ng camera at storage permissions
3. Patakbuhin ang application

Database Setup:
Awtomatikong lumilikha ang sistema ng lokal na database sa unang paggamit. Walang kailangang manual na configuration.''',

      'manual_roles': 'Mga Tungkulin at Permiso ng User',
      'manual_roles_content': '''Admin (Buong Access sa Sistema):
[x] Pamahalaan ang mga user account (lumikha/baguhin/i-deactivate)
[x] Pamahalaan ang mga produkto (magdagdag/baguhin/magtanggal/mag-restock)
[x] Tingnan ang lahat ng ulat (benta, imbentaryo, sira)
[x] Mag-export ng datos (CSV/PDF)
[x] I-configure ang mga setting ng sistema

Owner (Pamamahala ng Negosyo):
[x] Tingnan ang detalyadong mga ulat sa benta
[x] Subaybayan ang mga CCTV feed
[x] Pamahalaan ang imbentaryo
[x] Mag-ulat ng mga sirang item
[x] I-access ang POS terminal
[x] Backup & Restore ng database
[x] Tingnan ang analytics at charts
[ ] Hindi maaaring pamahalaan ang mga user
[ ] Hindi maaaring magtanggal ng mga produkto

Cashier (Point of Sale):
[x] Prosesahin ang mga transaksyon ng customer
[x] Magdagdag ng mga item sa cart
[x] Mag-apply ng mga discount
[x] Kumpletuhin ang mga benta
[x] Tingnan ang sales log
[x] I-access ang CCTV (gamit ang owner password)
[ ] Hindi maaaring pamahalaan ang mga produkto
[ ] Hindi maaaring tingnan ang mga ulat
[ ] Hindi maaaring pamahalaan ang imbentaryo''',

      'manual_create_admin': 'Paano Lumikha ng Admin Account',
      'manual_create_admin_content':
          '''Hakbang 1: I-click ang "Create Admin Account"
- Sa login screen, i-click ang button sa ibaba
- Lalabas ang registration form

Hakbang 2: Punan ang Detalye ng Account
- Buong Pangalan: Iyong kumpletong pangalan
- Email Address: Valid na email (hal., admin@store.com)
- Contact Number: Dapat magsimula sa +63
  Halimbawa: +639171234567
- Password: Minimum 8 characters
  Dapat may mga letra, numero, at simbolo
  Halimbawa: Admin@2025

Hakbang 3: I-verify ang Impormasyon
- I-double-check ang lahat ng inilagay na impormasyon
- Siguraduhing tama ang email (para sa password recovery)
- Siguraduhing may country code ang phone (+63)

Hakbang 4: Lumikha ng Account
- I-click ang "Create Account" button
- Maghintay ng success confirmation
- Ire-redirect sa login screen

Hakbang 5: Mag-login bilang Admin
- Piliin ang Admin Login tab
- Pumili ng login method:
  - Email + Password O
  - Contact Number + Password O
  - Gmail Sign-In (kung naka-configure)
- I-click ang "Login" button''',

      'manual_add_products': 'Paano Magdagdag ng mga Produkto',
      'manual_add_products_content': '''Mag-navigate sa Product Management:
- Admin Dashboard -> "Manage Products"

I-click ang "Add Product" button

Punan ang Impormasyon ng Produkto:
- Product Name: Naglalarawang pangalan (hal., "Coca-Cola 1.5L")
- Barcode: I-scan o ilagay manually
- Category: Pumili mula sa dropdown o gumawa ng bago
- Buying Price: Cost price (PHP )
- Selling Price: Retail price (PHP )
- Quantity: Kasalukuyang antas ng stock
- Reorder Level: Minimum na threshold ng stock (default: 5)
- Product Image: I-click ang camera icon para magdagdag ng photo

I-save ang Produkto:
- I-click ang "Save" button
- Available na ngayon ang produkto sa POS

I-edit ang Produkto:
- I-tap ang product card
- Baguhin ang mga detalye
- I-click ang "Update"

Mag-restock ng Produkto:
- I-tap ang produkto para i-edit
- I-update ang "Quantity" field sa bagong antas ng stock
- Awtomatikong inirerekord ng sistema ang inventory movement
- I-click ang "Save"''',

      'manual_use_pos': 'Paano Gamitin ang POS',
      'manual_use_pos_content': '''Access: Cashier Dashboard -> "Open POS"

Prosesahin ang isang Benta:

Hakbang 1: Magdagdag ng mga Item sa Cart
Paraan A: I-tap ang mga Product Tile
- Mag-browse ng product grid
- I-tap ang product tile para idagdag sa cart
- Long-press ang image para tingnan ang mas malaking larawan na may zoom

Paraan B: Gamitin ang Search Bar
- I-type ang pangalan ng produkto o category
- Mag-filter ang mga resulta nang real-time
- I-tap ang produkto para idagdag

Paraan C: I-scan ang Barcode
- I-click ang barcode icon
- I-scan ang barcode ng produkto gamit ang camera
- Awtomatikong idadagdag ang produkto sa cart

Hakbang 2: Ayusin ang mga Dami
- Sa cart sheet, gamitin ang + at - buttons
- O i-tap ang quantity para manually na maglagay
- Alisin ang item sa pamamagitan ng pagbaba sa 0

Hakbang 3: Mag-apply ng mga Discount (Opsyonal)
- I-tap ang discount icon sa cart item
- Ilagay ang discount percentage (0-100%)
- O ilagay ang fixed amount discount
- Nalalapat lamang sa item na iyon ang discount

Hakbang 4: I-review ang Cart
- Tingnan ang lahat ng mga item at dami
- I-verify ang kabuuang halaga
- Ipinapakita ng cart ang: Subtotal, Total Discount, Final Total

Hakbang 5: Mag-checkout
- I-click ang "Checkout" button
- Pumili ng Payment Method:
  - Cash: Nagbabayad ng cash ang customer
  - Card: Credit/Debit card payment
  - E-wallet (Cash-In): GCash, Maya, atbp.
  - E-wallet (Cash-Out): Nag-withdraw ang customer
  - Multiple Payment Methods: Hatiin ang bayad
- Ilagay ang Halaga (para sa Cash)
- I-click ang "Complete Sale"
- Awtomatikong nabubuong resibo
- Na-clear ang cart, na-update ang stock''',

      'manual_backup': 'Gabay sa Backup at Restore',
      'manual_backup_content': '''Bakit Mahalaga ang Backup:
- Protektado mula sa hardware failure
- Protektado mula sa mga error ng software
- Pigilan ang pagkawala ng datos mula sa aksidenteng pagtanggal
- Makabawi mula sa mga system crash

Mga Best Practice:
[x] Araw-araw na mga backup (katapusan ng araw ng negosyo)
[x] Bago ang malalaking pagbabago (bulk updates)
[x] Bago ang mga system update
[x] Mag-imbak ng mga backup sa maraming lokasyon

Paano Lumikha ng Backup:
Access: Owner Dashboard -> "Backup & Restore"

Paraan 1: Lumikha ng Internal Backup
1. I-click ang "Create Backup" button
2. Awtomatikong lumilikha ang sistema ng timestamped backup
3. Kinukumpirma ng success message ang paggawa
4. Nakaimbak ang backup sa backup directory ng app

Paraan 2: I-export ang Database
1. I-click ang "Export Database" button
2. Pumili ng save location (USB, Cloud, Network drive)
3. Pumili ng filename (default: pos_system_export_YYYY-MM-DD.db)
4. I-click ang "Save"
5. Matagumpay na na-export ang database

Inirerekomendang Storage:
- Magtago ng 3 kopya: Internal + USB + Cloud
- I-rotate ang lingguhang mga backup
- Subukan ang restore pana-panahon

Paano Mag-restore ng Backup:

Paraan 1: Mag-restore mula sa Internal Backup
1. Buksan ang "Backup & Restore" screen
2. Tingnan ang listahan ng available backups
3. Pumili ng backup na ire-restore
4. BABALA: Papalitan ang LAHAT ng kasalukuyang datos
5. I-click ang "Yes, Restore"
6. I-restart ang app

Paraan 2: Mag-import ng Database
1. I-click ang "Import Database" button
2. Mag-navigate sa backup .db file
3. Kumpirmahin ang import
4. Ini-import ng sistema ang database
5. I-restart ang app

Backup Schedule:
- Araw-araw: Katapusan ng araw ng negosyo (Internal backup)
- Lingguhan: Tuwing Linggo (Export sa USB)
- Buwanan: Ika-1 ng buwan (Export sa cloud)
- Bago ang mga Update: Parehong internal + external''',

      'manual_quick_start': 'Gabay sa Mabilis na Simula',
      'manual_quick_start_content': '''Unang Pag-setup (15 minuto):

Hakbang 1: Lumikha ng Admin Account (3 min)
- Patakbuhin ang app
- I-click ang "Create Admin Account"
- Punan ang: Name, Email, Phone, Password
- I-click ang "Create Account"

Hakbang 2: Mag-login bilang Admin (1 min)
- Piliin ang Admin Login
- Ilagay ang email + password
- I-click ang "Login"

Hakbang 3: Magdagdag ng Sample Products (5 min)
- Admin Dashboard -> "Manage Products"
- I-click ang "Add Product"
- Halimbawa: Coca-Cola 1.5L, Barcode, Category, Prices, Quantity
- I-click ang "Save"
- Magdagdag ng 2-3 pang produkto

Hakbang 4: Lumikha ng Cashier Account (2 min)
- Admin Dashboard -> "Manage Users"
- I-click ang "+" icon
- Punan ang: Name, Email, Password, PIN, Role: Cashier
- I-click ang "Save"

Hakbang 5: Subukan ang POS Transaction (4 min)
- Mag-logout mula sa admin
- Mag-login bilang Cashier
- Buksan ang POS Terminal
- Magdagdag ng mga produkto sa cart
- Kumpletuhin ang isang test sale

[x] Handa na ngayon ang sistema para gamitin!

Checklist ng Araw-araw na Operasyon:

Umaga (Pagbubukas):
[ ] Mag-login bilang Cashier
[ ] I-verify na gumagana ang POS
[ ] Tingnan ang availability ng produkto
[ ] I-review ang sales kahapon (Owner)

Sa Oras ng Negosyo:
[ ] Prosesahin ang mga transaksyon ng customer
[ ] Mag-ulat ng anumang sirang item
[ ] Mag-restock ng mga produkto kung kinakailangan

Gabi (Pagsasara):
[ ] Bilangin ang cash register
[ ] I-verify na tugma ang sales total sa cash
[ ] Lumikha ng araw-araw na backup (Owner)
[ ] Mag-export ng sales report
[ ] Mag-logout mula sa lahat ng account''',

      'manual_troubleshooting': 'FAQ sa Troubleshooting',
      'manual_troubleshooting_content': '''Mga Isyu sa Login:

T: Nakalimutan ang admin password?
S: Gamitin ang password recovery:
1. I-click ang "Forgot Password?" sa login screen
2. Ilagay ang admin email
3. I-verify ang OTP na ipinadala sa email
4. Ilagay ang phone number
5. I-verify ang SMS code
6. Magtakda ng bagong password

T: "Invalid credentials" error?
S: 
- I-verify na OFF ang caps lock
- Tingnan ang format ng email/phone
- Siguraduhing tama ang password
- Subukan ang pag-toggle ng password visibility (eye icon)

Mga Isyu sa POS:

T: Hindi makita ang produkto sa POS?
S:
- I-verify na naidagdag ang produkto sa Admin -> Manage Products
- Tingnan na hindi deleted ang produkto
- Subukan ang paghahanap gamit ang barcode o pangalan
- I-refresh ang product list

T: Hindi gumagana ang barcode scanner?
S:
- Bigyan ng camera permission ang app
- Siguraduhing malinaw at nakikita ang barcode
- Subukan ang manual entry
- I-restart ang app kung nag-freeze ang camera

T: "Insufficient stock" error?
S:
- Ang dami ng produkto ay 0 o kulang sa hiniling
- Mag-restock ng produkto sa pamamagitan ng Admin -> Manage Products
- Tingnan ang inventory movements

Mga Isyu sa Backup:

T: Nabigo ang paggawa ng backup?
S:
- Tingnan ang libreng disk space (kailangan 50MB+)
- Isara ang app nang buo at buksan muli
- Siguraduhing hindi corrupted ang database
- Subukan ang manual export sa halip

T: Hindi maa-restore ang backup?
S:
- I-verify na may .db extension ang backup file
- Siguraduhing hindi corrupted ang backup file
- Subukan ang ibang backup file
- Tingnan na hindi nakabukas ang file ng ibang program

Mga Isyu sa Performance:

T: Mabagal o nag-lag ang app?
S:
- I-enable ang "Reduce Motion" sa Settings
- Isara ang ibang apps sa background
- Magtanggal ng lumang transaksyon (Admin lang)
- I-restart ang device

T: Masyadong malaki na ang database?
S:
- Mag-export ng lumang sales sa CSV
- Mag-archive ng mga transaksyon na mas matanda sa 1 taon
- Regular na cleanup tuwing 6 na buwan''',

      'manual_common_tasks': 'Sanggunian sa Karaniwang Gawain',
      'manual_common_tasks_content': '''Mabilis na Sanggunian:

Magdagdag ng Produkto:
Admin -> Manage Products -> + -> Punan ang detalye -> Save

Mag-restock ng Item:
Admin -> Manage Products -> Piliin ang produkto -> I-update ang quantity -> Save

Prosesahin ang Benta:
Cashier -> POS -> Magdagdag ng mga item -> Checkout -> Payment -> Complete

Tingnan ang Sales:
Owner -> Sales Reports -> Pumili ng petsa -> Tingnan ang detalye

Lumikha ng Backup:
Owner -> Backup & Restore -> Create Backup

Mag-ulat ng Sira:
Owner/Admin -> Inventory -> Damage Reports -> Report Damage

Proseso ng Bayad sa Damage (Owner Lamang):
Owner -> Inventory -> Damage Reports -> Pumili ng hindi pa nabayarang damage -> Proceed to Payment -> Pumili ng may pananagutan -> Kumpirmahin -> Resibo ay nabuo

Tingnan ang Payment Status:
Damage Reports -> Asul na badge = Nabayaran, Berde = Naibalik, Pula/Orange = Pending

Baguhin ang Theme:
Anumang user -> Settings (gear icon) -> Pumili ng kulay

Baguhin ang Wika:
Settings -> Language -> EN o FIL

Mag-export ng mga Ulat:
Tingnan ang ulat -> I-click ang Export CSV o Export PDF

I-access ang CCTV:
Owner -> Monitor CCTV
Cashier -> Sales Log -> Camera icon -> Ilagay ang owner password

Tingnan ang Imbentaryo:
Owner/Admin -> Inventory -> Tingnan ang mga antas ng stock

Mga Alerto sa Mababang Stock:
Mga produktong may ≤5 items ay ipinapakita sa pula

Pamamahala ng User:
Admin -> Manage Users -> + para magdagdag, i-tap para i-edit

I-deactivate ang User:
Admin -> Manage Users -> Piliin ang user -> I-toggle ang Active Status OFF

Password Recovery:
Login screen -> Forgot Password -> Sundin ang email/SMS verification

Maghanap ng mga Produkto:
POS screen -> I-type sa search bar (pangalan o barcode)

I-zoom ang Larawan ng Produkto:
Long-press ang product tile sa POS

Mag-apply ng Discount:
Sa cart -> I-tap ang discount icon sa item -> Ilagay ang halaga/percentage

Maraming Paraan ng Bayad:
Checkout -> Piliin ang "Multiple Payment Methods" -> Hatiin ang bayad

Magdagdag ng Supplier:
Owner -> Supplier Management -> + Add Supplier -> Punan ang detalye -> Save

Gumawa ng Purchase Order:
Owner -> Supplier Management -> Purchase Orders -> + Create -> Piliin ang supplier -> Magdagdag ng produkto -> Isumite

Ibalik ang Sirang Item sa Supplier:
Owner -> Supplier Management -> Supplier Damage Reports -> Piliin ang damage -> Return to Supplier -> Kumpirmahin

Tingnan ang Order Status:
Supplier Management -> Purchase Orders -> Tingnan ang cards (Orange=Pending, Berde=Completed, Pula=Cancelled)''',

      'manual_getting_started': 'Pagsisimula',
      'manual_getting_started_content': '''Unang Paglunsad:

1. Buksan ang application
   - Patakbuhin ang Smart Store Monitoring System

2. Makikita mo ang login screen na may tatlong opsyon:
   - Admin Login
   - Owner Login
   - Cashier Login

3. Ang unang pag-setup ay nangangailangan ng paggawa ng Admin account

Tandaan: Dapat gawin muna ang Admin account bago ang iba pang user account.''',

      'manual_admin_features': 'Mga Feature ng Admin',
      'manual_admin_features_content': '''1. Pamamahala ng Mga User Account

Magdagdag ng Bagong User (Owner o Cashier):
- Admin Dashboard -> "Manage Users"
- I-click ang "+" icon (sa itaas kanan)
- Punan ang: Name, Email, Password, PIN, Role
- I-click ang "Save"

I-edit ang User: I-tap ang user card -> I-modify -> "Update"
I-deactivate ang User: I-tap ang user card -> I-toggle ang "Active Status" OFF

2. Pamamahala ng Mga Produkto

Magdagdag ng Produkto:
- Admin Dashboard -> "Manage Products" -> "Add Product"
- Punan ang: Name, Barcode, Category, Prices, Quantity, Reorder Level
- Magdagdag ng larawan -> "Save"

I-edit ang Produkto: I-tap ang product -> I-modify -> "Update"
Mag-restock: I-tap ang product -> I-update ang "Quantity" -> "Save"
Tanggalin: I-tap ang product -> "Delete Product" -> Kumpirmahin

3. Pagtingin ng mga Ulat

Mga Ulat sa Benta: Tingnan ang kabuuang benta, transaksyon, paraan ng bayad
Mga Ulat sa Imbentaryo: Antas ng stock, alerto sa mababang stock (≤5 items)
Mga Ulat sa Sirang Produkto: Sirang mga item, nawalang halaga, dahilan
Mga Log ng Aktibidad ng User: Oras ng login, aksyon, timestamp
I-export: CSV o PDF

4. Mga Setting ng Sistema

I-access: I-click ang gear icon
- Wika: EN/FIL
- Tema: 9 preset + 24 custom na kulay
- Accessibility: Reduce Motion
- Pamamahala ng Datos: I-export, i-clear ang lumang transaksyon

7. Pamamahala ng Attendance

I-access ang Manage Attendance:
- Admin Dashboard -> "Manage Attendance"

Tingnan ang Listahan ng Attendance:
- Makita ang lahat ng users na may today's status, last clock-in/out times, at role

Marka o I-edit ang Attendance:
- I-tap ang user row upang magdagdag o mag-correct ng clock-in/out record
- Magdagdag ng notes o dahilan para sa adjustments

Attendance Reports & Export:
- I-filter ayon sa date range o user
- I-click ang "Export CSV" para i-download ang attendance logs para sa payroll o audit

Bulk Actions:
- Import/Export attendance (CSV) at magsagawa ng bulk corrections''',

      'manual_owner_features': 'Mga Feature ng Owner',
      'manual_owner_features_content': '''1. Mga Ulat sa Benta at Analytics

I-access: Owner Dashboard -> "View Sales Reports"

Buod Araw-araw:
- Piliin ang petsa
- Tingnan: Kabuuang Benta, Transaksyon, Average, E-wallet Fees
- I-export: CSV o PDF

Date Range: Piliin ang mga petsa -> Tingnan ang trends -> I-export

Mga Chart ng Benta: Line chart (trends), Bar chart (paraan ng bayad)

2. Pagsubaybay sa CCTV

Setup: Settings -> I-configure ang URL (RTSP/HTTP/Local video)
Tingnan: Live feed, Play/Pause, Snapshot, Zoom
Maraming Camera: Mag-swipe sa pagitan ng feeds, grid view

3. Pamamahala ng Imbentaryo

Tingnan ang Stock: Tingnan ang dami, alerto sa mababang stock (≤5 items)
Mga Paggalaw: Tingnan ang benta, restock, adjustment
Mag-ulat ng Sira: Piliin ang produkto, dami, dahilan -> "Submit"

4. I-access ang POS Terminal

Owner Dashboard -> "POS Terminal"
Mag-proseso ng benta bilang cashier
Nakatalang benta sa ilalim ng pangalan ng owner

5. Pamamahala ng Bayad sa Store Damage

I-access: Owner Dashboard -> "Inventory Status" -> "Damage Reports" tab

Para sa Hindi Pa Nabayarang Store Damage:
- Tingnan ang damage reports na may pula/orange na icon (pending)
- Pindutin ang "Proceed to Payment" button (orange)

Proseso ng Pagbabayad:
1. Pumili ng May Pananagutan:
   - Pumili ng staff member mula sa listahan (ipinapakita ang pangalan at role)
   - O pumili ng "All Staff" para sa shared responsibility
   - Suriin ang detalye ng damage: Produkto, Dami, Kabuuang Halaga

2. Kumpirmahin ang Bayad:
   - Pindutin ang "Proceed to Payment" button
   - Gumawa ang system ng sale record na may 'SD-{timestamp}' na numero
   - Paraan ng bayad ay naitala bilang "Store Damage Payment"

3. Paggawa ng Resibo:
   - Awtomatikong lumalabas ang resibo dialog
   - Ipinapakita: Receipt number, petsa, produkto, dami, halaga
   - Ipinapakita ang pangalan ng may pananagutan
   - Pindutin ang "Print Receipt" para gumawa ng PDF
   - Pindutin ang "Close" para tapusin

Katayuan Pagkatapos ng Bayad:
- Damage report ay nagpapakita ng asul na "Store Damage Paid" badge
- Ipinakikita ang petsa ng pagbabayad
- Makikita ang impormasyon ng may pananagutan
- Benta ay naitala sa Sales Reports
- Na-update ang kabuuang damaged items/value (hindi kasama ang nabayaran)

Pagsasama sa Admin Reports:
- Admin -> Reports -> Damage Reports
- Tingnan ang payment status cards: Paid (asul), Returned (berde), Pending (pula)
- Pinahusay na CSV export kasama ang payment columns
- I-filter ayon sa status para sa detalyadong pagsusuri

6. Pamamahala ng Supplier

I-access: Owner Dashboard -> "Supplier Management"

Mga Tab: Suppliers | Supplier Damage Reports | Purchase Orders

A. Pamamahala ng mga Supplier:

Magdagdag ng Bagong Supplier:
1. I-tap ang "+ Add Supplier" button
2. Punan ang impormasyon ng supplier:
   - Pangalan ng Supplier (kinakailangan)
   - Contact Person
   - Numero ng Telepono
   - Email Address
   - Pisikal na Address
3. I-tap ang "Add Supplier" para i-save

I-edit/I-delete ang Supplier:
- I-tap ang supplier card para tingnan ang detalye
- Gamitin ang edit icon para i-update ang impormasyon
- Gamitin ang delete icon para tanggalin (kung walang active orders)

B. Mga Ulat ng Damage mula sa Supplier:

Tingnan ang mga Sira mula sa mga Supplier:
- Tingnan ang lahat ng items na natanggap na sira mula sa mga supplier
- Mga status indicator:
  * Pula: Pending (hindi pa naibabalik)
  * Berde: Returned (completed)
  * Asul: Already paid (nabayaran na ang store damage)
- Ipinapakita: Produkto, Dami, Supplier, Petsa

Ibalik sa Supplier:
1. I-tap ang "Return to Supplier" button (pula)
2. Kumpirmahin ang return action
3. Magbabago ang status sa berdeng "Returned to Supplier"
4. Awtomatikong inilalapat ang stock adjustments

Tandaan: Ang mga items na markado bilang "Store Damage Paid" ay hindi maibabalik
- Disabled ang "Return to Supplier" button para sa nabayarang damages
- Ipinakikita ang petsa ng pagbabayad at may pananagutan

C. Mga Purchase Order:

Gumawa ng Purchase Order:
1. I-tap ang "+ Create Purchase Order" button
2. Pumili ng Supplier mula sa dropdown
3. Magdagdag ng mga Produkto:
   - Maghanap at pumili ng mga produkto mula sa inventory
   - Ilagay ang dami para sa bawat produkto
   - Ipinakikita ng system ang kasalukuyang stock levels
4. I-review ang Order Summary:
   - Kabuuang items
   - Kabuuang halaga ng order
   - Impormasyon ng supplier
5. I-tap ang "Create Order" para isumite

Umorder mula sa Product Screen:
- Mula sa Inventory -> Restock Delivery tab
- I-tap ang cart icon sa low stock/out of stock items
- Awtomatikong nag-navigate sa Purchase Orders na may preselected na produkto

Tingnan/Pamahalaan ang mga Order:
- Mga order status cards: Pending, Completed, Cancelled
- Tingnan ang order details: Mga produkto, dami, kabuuang halaga
- Subaybayan ang order dates at status changes
- I-export ang order history bilang CSV

Mga Order Status:
- Pending (Orange): Naghihintay ng delivery
- Completed (Berde): Natanggap at na-update ang stock
- Cancelled (Pula): Kinansela ang order

Mahusay na Gawain:
- Panatilihing updated ang supplier contact information
- Agad na prosesahin ang returns para sa sirang items
- I-review ang purchase orders bago isumite
- Regular na subaybayan ang order statuses
- Makipag-coordinate sa mga supplier sa delivery schedules''',

      'manual_cashier_features': 'Mga Feature ng Cashier',
      'manual_cashier_features_content': '''1. Paggamit ng POS Terminal

I-access: Cashier Dashboard -> "Open POS"

Magdagdag ng mga Item sa Cart:
- Paraan A: I-tap ang product tiles (long-press para sa zoom)
- Paraan B: Search bar (i-type ang name/category)
- Paraan C: I-scan ang barcode

Ayusin ang Dami: Gamitin ang +/- buttons o i-tap para mag-type manually
Mag-apply ng Discount: I-tap ang discount icon -> Ilagay ang percentage o halaga
I-review ang Cart: Tingnan ang items, i-verify ang Subtotal, Discount, Total

Checkout:
1. I-click ang "Checkout"
2. Piliin ang Bayad: Cash/Card/E-wallet/Multiple
3. Ilagay ang Halaga (Cash) - Kalkulahin ng sistema ang sukli
4. "Complete Sale" - Nabuo ang resibo, na-clear ang cart, na-update ang stock

Alerto sa Mababang Stock: Kung dami ay ≤5 pagkatapos ng benta

Tingnan ang Sales Log: Tingnan ang lahat ng transaksyon kasama ang mga detalye

2. I-access ang CCTV (Kailangan ng Owner Password)

Sales Log -> I-tap ang camera icon -> Ilagay ang owner password
Tingnan ang CCTV sa oras ng benta

3. Pagtingin ng Larawan ng Produkto

Long-press ang product tile -> Pinalaking view -> Zoom (0.5x-4x)

4. Attendance (Clock In / Clock Out)

Clock In / Clock Out:
1. Buksan ang POS (Cashier) screen
2. I-tap ang Profile / Attendance icon (top-right) o gamitin ang `Attendance` action
3. Clock In upang simulan ang shift; ini-record ng app ang timestamp at device
4. Clock Out kapag tapos na; maaaring i-edit ng supervisor ang entries kung kinakailangan
5. Ang Owners/Admins ay maaaring i-export ang attendance logs (CSV) mula sa Admin -> Manage Attendance
''',

      'manual_support': 'Impormasyon sa Suporta',
      'manual_support_content': '''Mga Detalye ng Kontak:

Developer/Vendor:
- Kumpanya: Pinkora Dev
- Email: jaybe.gubot01@gmail.com
- Telepono: +63 9604279947
- Raket PH: raket.ph/pinkora_dev

Oras ng Negosyo:
Lunes - Biyernes: 9:00 AM - 6:00 PM (PHT)
Sabado: 10:00 AM - 3:00 PM
Linggo: Sarado

Emergency Support:
- Email: jaybe.gubot01@gmail.com
- Tugon: Sa loob ng 24 oras

Pagkuha ng Tulong:
- Pangkalahatan: jaybe.gubot01@gmail.com
- Teknikal: jaybe.gubot01@gmail.com
- Billing: jaybe.gubot01@gmail.com

Live Chat: Available sa oras ng negosyo (5-10 min tugon)

Social Media:
Facebook: @gubotjaybe26
Tiktok: @pinkora_dev

Mga Update ng Software:
Settings -> About -> Check for Updates
Available ang automatic updates
Mga notification sa dashboard

Pag-uulat ng Mga Bug Kasama ang:
1. Impormasyon ng Device/OS
2. Mga hakbang para i-reproduce
3. Screenshots/errors
4. User role
5. Bersyon ng app

Iskedyul ng Update:
- Major: Bawat 6 buwan
- Minor: Buwanan
- Security Patches: Kung kinakailangan
- Hotfixes: Kung kinakailangan

Roadmap 2026:
Q1: Cloud sync, Multi-store, Analytics
Q2: Loyalty program, SMS, Auto-reordering
Q3: AI forecasting, Facial recognition, Voice commands
Q4: E-commerce, Supplier management, Payroll

Pagsasanay:
- YouTube: @Pinkora_Dev SmartStore POS Tutorials (30+ videos)
- User Manual
- API Documentation

Lisensya:
- Isang installation per license
- Habambuhay na paggamit
- 1 taon libreng updates at support
- Available ang extended support

Privacy ng Datos:
- Lokal na storage lamang
- Walang telemetry
- GDPR compliant
- Opsyonal na encryption

Salamat sa pagpili ng Smart Store Monitoring System!
Bisitahin: www.pinkoradev.com''',

      'settings_saved': 'Matagumpay na na-save ang mga setting',

      // E-Wallet Transfer
      'ewallet_transfer': 'Paglipat sa E-Wallet',
      'transaction_type': 'Uri ng Transaksyon',
      'cash_in': 'Cash IN',
      'cash_out': 'Cash Out',
      'transfer_fee': 'Bayad sa Paglipat',
      'receipt_verification': 'Pagpapatunay ng Resibo',
      'capture_receipt': 'Kunan ng Resibo',
      'capture_receipt_optional': 'Kunan ng Resibo (Opsyonal)',
      'receipt_captured': '✓ Nakuha na ang resibo',
      'retake': 'Kunan Ulit',
      // Financial Reports
      'financial_reports': 'Mga Ulat sa Pananalapi',
      'financial_reports_tab': 'Mga Ulat sa Pananalapi',
      'sales_report_tab': 'Ulat ng Benta',
      'available_in_standard': 'Available sa Standard package at pataas',
      'upgrade_package': 'I-upgrade ang Package',
      'upgrade_to_standard':
          'Pakiusap mag-upgrade sa Standard package o mas mataas',
      'select_date': 'Pumili ng Petsa',
      'revenue_overview': 'Pangkalahatang-ideya ng Kita',
      'gross_revenue': 'Kabuuang Kita',
      'net_revenue': 'Netong Kita',
      'growth_rate': 'Rate ng Paglaki',
      'expenses': 'Mga Gastos',
      'operating_costs': 'Gastos sa Operasyon',
      'transfer_fees': 'Bayad sa Paglipat',
      'total_expenses': 'Kabuuang Gastos',
      'profit_analysis': 'Pagsusuri ng Kita',
      'gross_profit': 'Kabuuang Kita',
      'net_profit': 'Netong Kita',
      'financial_insights': 'Pag-unawa sa Pananalapi',
      'revenue_explanation':
          'Kita: Ang kabuuang kita ay kasama ang lahat ng nakumpletong benta. Ang netong kita ay hindi kasama ang bayad sa paglipat mula sa mga transaksyon ng e-wallet.',
      'expenses_explanation':
          'Gastos: Ang gastos sa operasyon ay tinantya sa 20% ng kabuuang kita. Ang bayad sa paglipat ay aktwal na bayad mula sa mga transaksyon ng e-wallet.',
      'profit_explanation':
          'Kita: Kabuuang kita = Kita - Gastos sa operasyon. Netong kita = Kita - Lahat ng gastos. Margin ng kita = Netong kita / Kita.',
    },
  };

  static String t(String key) {
    final code = LocaleController.locale.value.languageCode;
    final map = _localizedValues[code] ?? _localizedValues['en']!;
    return map[key] ?? key;
  }
}
