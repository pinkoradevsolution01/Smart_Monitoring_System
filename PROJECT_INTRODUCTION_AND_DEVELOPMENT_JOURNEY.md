# Smart Monitoring System

## Introduction

The Smart Monitoring System is a cross-platform retail and business operations application designed to bring essential store activities into one dependable system. It combines point-of-sale operations, inventory management, sales reporting, customer and supplier records, employee attendance, payroll, CCTV monitoring, delivery workflows, cloud synchronization, backup and restore, and subscription licensing.

The system is built with Flutter so that it can run on Windows, Android, iOS, macOS, Linux, and the web. It uses local storage for practical offline-first workflows and connects to a Node.js/MySQL backend and selected cloud services when synchronization, authentication, email, licensing, or remote access is required.

The main goal is to reduce the need for separate tools. Store owners can monitor the business, cashiers can process sales, staff can manage inventory and deliveries, administrators can manage users and reports, and developers can manage activation codes and subscriptions through role-specific dashboards.

## What We Added During Development

### Business and retail operations

- Point-of-sale checkout with cart management and multiple payment workflows.
- Product catalog, barcode support, product images, stock tracking, and low-stock indicators.
- Inventory movement history for purchases, sales, adjustments, damages, and returns.
- Sales reports with summaries, date filtering, transaction details, and export/printing support.
- Customer management, loyalty records, rewards, and customer purchase history.
- Supplier management and purchase-order workflows.
- Delivery and delivery-receiver operations.

### Workforce and role management

- Role-based dashboards for owners, administrators, managers, cashiers, inventory clerks, sales promoters, delivery receivers, and developers.
- User management with separate access responsibilities.
- Attendance tracking with clock-in, break, and clock-out records.
- Payroll management and attendance-based payroll workflows.
- Business registration and business-scoped data handling.

### Monitoring and support tools

- CCTV camera configuration, live feeds, camera timestamps, and recording-related tools.
- AI help assistance and user manuals inside the application.
- English and Filipino language support.
- Theme selection, custom colors, reduced-motion preferences, and responsive layouts.
- Cross-platform image selection with appropriate fallbacks for Windows limitations.

### Licensing, subscriptions, and cloud services

- Trial-period tracking and subscription expiration handling.
- Activation-code generation, validation, assignment, revocation, and expiration controls.
- Developer-side activation request management and email notification workflows.
- Renewal and settlement flows requiring a new activation code.
- System-lock behavior when a trial or subscription expires.
- A fresh activation-code request form from Settings and from the locked-system screen.
- Local backup and restore, cloud synchronization, password reset, OAuth-related flows, and backend connectivity checks.

## Important Fixes and Improvements

Over the development period, the project grew from a basic Flutter POS prototype into a larger multi-role system. Several important issues were discovered and corrected along the way:

- Corrected authentication, password-reset, OAuth, and deep-link handling across supported platforms.
- Improved backend communication and added fallback handling for different backend server locations.
- Fixed email notification and activation-request problems, including failed request responses and delivery workflow issues.
- Strengthened activation-code validation so used, expired, revoked, and invalid codes are rejected correctly.
- Added subscription expiration detection and automatic system-lock behavior.
- Ensured users must request a fresh activation code before renewal or system reactivation.
- Improved data isolation and synchronization so business data is associated with the correct business context.
- Added local database support for desktop systems through SQLite FFI.
- Improved backup and restore handling to protect business data during upgrades or failures.
- Added Windows-specific fallbacks for image selection because direct camera capture is not consistently available on Windows.
- Fixed layout problems caused by fixed widths, crowded mobile rows, and dashboard grids that did not adapt to smaller screens.
- Added responsive dashboard columns, adaptive spacing, and phone-friendly renewal and attendance dialogs.
- Improved localization, theme behavior, and user-facing error messages.
- Added tests and diagnostic tools for serialization, user services, responsive behavior, and database-related workflows.

## Experience From Six Months of Development

Developing this system for approximately half a year has shown that building business software is more than creating screens. Every feature affects data storage, user permissions, backend communication, error handling, and the daily workflow of the people who will use it.

One of the biggest lessons was the importance of designing around real roles and real responsibilities. An owner does not need the same interface as a cashier, and a developer needs different tools from an inventory clerk. Role-specific dashboards made the system clearer, safer, and easier to operate.

Another major lesson was that offline support and cloud synchronization require careful planning. Local storage makes the application more useful when the internet is unavailable, but synchronization introduces challenges involving conflicts, business ownership, device identity, and data consistency. These concerns must be considered from the beginning rather than added only at the end.

Licensing and subscription control also became a significant part of the project. A subscription is not simply a date shown on the screen. It affects login behavior, feature access, activation-code security, email notifications, renewal, system locking, and recovery after payment. Building this workflow improved the system’s reliability and made the business model enforceable.

Cross-platform development provided another valuable experience. A feature that works on Android may behave differently on Windows or the web because of differences in permissions, camera support, file systems, window sizes, and browser behavior. Testing on multiple devices helped identify the need for platform fallbacks and responsive layouts.

The project also demonstrated the value of reusable services and shared components. Centralizing licensing, backend requests, localization, theme settings, responsive rules, and activation-code requests made later changes safer and reduced duplicated logic.

Finally, the development process showed that fixing and refining existing features is as important as adding new ones. User feedback exposed unclear flows, missing validation, layout overflow, confusing renewal steps, and recovery problems. Each issue became an opportunity to make the system more understandable and dependable.

## Current Position of the System

The Smart Monitoring System now provides a broad foundation for retail operations and business monitoring. It supports daily transactions, inventory control, staff administration, reporting, delivery, monitoring, licensing, backups, and cloud-connected workflows in one application.

The system is still designed for continuous improvement. Future work can focus on deeper automated testing, stronger conflict resolution for synchronization, improved analytics, better notification controls, more device-specific testing, enhanced security auditing, and further simplification of complex workflows.

## Conclusion

The Smart Monitoring System represents approximately six months of continuous design, implementation, debugging, testing, and refinement. It began as a retail management application and developed into a complete multi-role platform with monitoring, licensing, cloud, and operational support capabilities.

More than the number of features, the project’s most important achievement is the experience gained in building software that must be practical, secure, recoverable, and usable on different devices. The system continues to evolve, but its current structure provides a strong foundation for reliable business management and future expansion.
