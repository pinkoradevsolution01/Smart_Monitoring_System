# Daily System Testing Checklist

Use this checklist once each business day before users begin work, and after any app, backend, database, DNS, or deployment change. Record a **Pass**, **Fail**, or **Not applicable (N/A)** beside every item. A failure that affects login, sales, stock, payment, activation, security, or data synchronization blocks production use until it is resolved or explicitly accepted by the system owner.

## Daily test record

| Field | Record |
| --- | --- |
| Date and time (Asia/Manila) | |
| Tester | |
| App version / Git commit | |
| Device(s) tested | Android / Windows / Web |
| Backend environment | Production / staging |
| Test business and test accounts used | |
| Overall result | Pass / Fail / Conditional |
| Incident or ticket links | |

## Rules for safe testing

- Use designated test accounts, test products, and a test business whenever a test creates, changes, revokes, or deletes data.
- Never test destructive actions against a real customer, real sale, active subscriber, or production activation code unless the owner has approved it.
- Do not paste passwords, JWTs, API keys, reset tokens, activation codes, or full customer personal information into this document or a ticket.
- Capture a screenshot, request ID, error message, and the time for each failure. Do not retry a charge, activation, or data deletion until the current result is known.

## 1. Start-up and availability

- [ ] **App launches:** Open the Flutter app. Confirm it reaches the expected sign-in, package, or dashboard screen without a crash, blank screen, overflow warning, or persistent loading indicator.
- [ ] **Theme and readability:** Check Professional, Indigo, and Mocha. Headlines, subtext, inputs, navigation, buttons, status badges, and dialogs must remain readable with sufficient contrast.
- [ ] **Developer tools readability:** Open each Developer Dashboard feature. Confirm the dark workspace shows visible titles, back arrows, icons, cards, subtext, and input values.
- [ ] **Owner registration integrity:** Open Manage Owner Account. Confirm the registered name, email, and contact fields are read-only; no Edit or Save Changes action is available.
- [ ] **API health:** Confirm `GET /api/health` returns HTTP 200 and the expected backend name.
- [ ] **Database health:** Confirm `GET /api/health/db` returns HTTP 200 with a successful database result.
- [ ] **Connectivity behavior:** Temporarily test with no network, if practical. The app must show a clear offline/error state and must not silently lose entered data.

## 2. Authentication and access control

- [ ] **Owner sign-in:** Sign in with a valid owner test account. Confirm the owner dashboard loads and shows only that business data.
- [ ] **Cashier/Admin sign-in:** Sign in with valid test accounts. Confirm each role reaches its own allowed modules.
- [ ] **Developer sign-in:** Sign in with a valid developer account. Confirm Developer Dashboard loads and owner credentials cannot access it.
- [ ] **Google sign-in:** Complete a Google sign-in using an existing authorized account. Confirm the correct user/business is selected and no duplicate owner/subscriber account is created.
- [ ] **Unauthorized access:** Attempt one protected route with the wrong role. Confirm access is denied or the user is redirected; data must not load.
- [ ] **Sign out:** Sign out, then use the Android back button or browser history. Confirm protected dashboard data is not available without signing in again.
- [ ] **Password/PIN recovery:** On a test account only, request a password or PIN reset. Confirm the request reports a useful success/error result and the reset link/token is not exposed in the app UI or logs.

## 3. POS and sales flow

- [ ] **Product search:** In POS, find a product by name and barcode where available. Confirm results are accurate and touch targets are usable.
- [ ] **Stock state:** Verify an in-stock product can be added and an out-of-stock product cannot be sold. Low-stock indicators must match inventory quantity.
- [ ] **Add to cart:** Add a test product, change quantity, remove it, and add it again. Confirm cart totals, item count, discounts, and tax calculations are correct.
- [ ] **Checkout:** Complete one test sale using an approved test payment method. Confirm the receipt/sales record is created once and stock is reduced by the sold quantity.
- [ ] **Duplicate protection:** During checkout, tap the confirmation control only once. Confirm a slow connection or repeat tap does not create a duplicate sale.
- [ ] **Cancelled sale:** Cancel a pending test sale. Confirm it does not count as revenue and does not reduce stock.
- [ ] **Sales records:** Open the daily sales log/report. Confirm the completed sale appears with the correct total, payment method, cashier, and time.

## 4. Inventory, suppliers, and operations

- [ ] **Inventory list:** Confirm product name, category, quantity, cost/retail values, low-stock status, and out-of-stock status display correctly.
- [ ] **Stock adjustment:** Use a test product to perform one permitted stock adjustment/restock. Confirm the quantity and movement history update exactly once.
- [ ] **Supplier workflow:** Open Supplier Management. View a supplier and a purchase order. Confirm headline text, table rows, status, and action controls are readable.
- [ ] **Damage workflow:** Create or review a test damage report. Confirm damaged quantity affects the appropriate inventory logic and audit/history record.
- [ ] **Customer/loyalty:** Find a test customer, verify points/balance, and confirm no unrelated customer information is shown.
- [ ] **Attendance/operational records:** If enabled for the business, verify one current attendance/operational record can be viewed and has the correct date/time.

## 5. Cloud synchronization and data integrity

- [ ] **Initial sync:** Trigger or wait for a normal sync. Confirm it finishes without a timeout, duplicate-record message, or unhandled error.
- [ ] **Cross-device verification:** Create one approved test record on device A, then refresh device B. Confirm it appears once with matching values.
- [ ] **Offline queue:** If supported, create one non-financial test record while offline, reconnect, and confirm it syncs once after reconnection.
- [ ] **Conflict behavior:** Where two devices edit the same test record, confirm the app displays the expected conflict/last-update behavior; do not assume silent overwrites are acceptable.
- [ ] **No data leakage:** Sign in to a second test business. Confirm sales, products, customers, and analytics from the first business are not visible.

## 6. Subscriptions, activation, and email

- [ ] **Subscription fetch:** Confirm Cloud Subscription Service loads the expected number of records and shows a clear error/retry state if the backend is unavailable.
- [ ] **Activation code availability:** In Developer tools, verify a test package can find an available code without exposing unrelated codes.
- [ ] **Activation request:** Submit one test activation request. Confirm the request appears in Activation Requests with the expected pending status.
- [ ] **Fulfilment:** Fulfil a test request once. Confirm the code is marked used/assigned exactly once and the request becomes fulfilled.
- [ ] **Email delivery:** Confirm the activation/reset email is accepted by the configured provider and arrives at the approved test inbox. Verify sender identity, recipient, subject, and link/code only; do not copy the secret into the record.
- [ ] **Expiry/cancellation logic:** Use a non-production test subscription when possible. Confirm active accounts can proceed and expired/cancelled accounts are denied with a clear explanation.

## 7. Developer Dashboard checks

- [ ] **Dashboard header:** Confirm Developer Dashboard title, navigation arrow, refresh icons, and Sign Out icon are high-contrast and tappable.
- [ ] **Activation Code Generator:** Generate test codes only. Confirm package selection, generated-code list, copy action, export action, and clear/delete confirmation work as expected.
- [ ] **Activation Requests:** Check Pending, Fulfilled, and All filters. Confirm counts match the list and fulfilment cannot be run twice.
- [ ] **Subscription Records:** Search and filter records. Open details and confirm all labels/values are readable; export only approved test data.
- [ ] **Code Revocation:** Verify used test-code list, refresh, reason confirmation, and revocation status. Do not revoke a real active client code.
- [ ] **Developer Account:** Confirm fields, password controls, and destructive-account confirmation are visible and protected.
- [ ] **Backend Connection Test:** Run it once. Confirm the API/database status is reported accurately and failures contain an actionable error.

## 8. Web Analytics checks

Perform these when Smart Analytics is deployed or changed.

- [ ] **Site availability:** Open `https://smartmonitoringsystem.store` and confirm HTTPS loads without a browser security warning.
- [ ] **Google login handoff:** Select Continue with Google. Confirm redirect to Smart Monitoring API, return to Web Analytics, one-time code exchange, and dashboard load succeed.
- [ ] **Tenant enforcement:** With two test businesses, confirm the dashboard/API never accepts a client-supplied business ID to show another business's data.
- [ ] **KPI accuracy:** Compare one selected date range against the Flutter sales/inventory records. Revenue excludes cancelled sales; product counts and low-stock lists match.
- [ ] **Filters and export:** Change dates/filters, then export CSV. Confirm the visual data and CSV use the same filters and tenant scope.
- [ ] **Theme parity:** Check Professional, Indigo, and Mocha. Inter typography, focus states, status colors, tables, charts, empty states, and error states must be readable.

## 9. Device, interaction, and accessibility regression

- [ ] **Android phone:** Check the main dashboard, POS, cart, Settings, and one long form. There must be no clipped text, horizontal overflow, or unreachable action.
- [ ] **Windows/tablet/web:** Check sidebar/bottom navigation behavior, resizable layouts, tables, dialogs, and POS cart at wider widths.
- [ ] **Motion and sound setting:** With Motion and interaction sounds enabled, test navigation and one POS add-to-cart action. With it disabled, confirm optional motion/sound feedback stops. Device media volume and system haptics must be enabled for physical feedback testing.
- [ ] **Keyboard/accessibility:** Tab through a web/desktop form. Confirm visible focus, readable font size, labels for icons, and logical navigation order.
- [ ] **Reduced motion:** Enable reduced motion. Confirm non-essential animations are removed or minimized without disabling core workflows.

## 10. Close-out

- [ ] Record every failed check, affected role/device, exact steps, time, and evidence location.
- [ ] Re-test each repaired failure before marking it resolved.
- [ ] Confirm no test sales, test products, activation codes, or test accounts need cleanup. Perform cleanup only in the approved test environment.
- [ ] Notify the system owner immediately for production-blocking failures: sign-in unavailable, data exposed across businesses, duplicate/missing sales, inventory corruption, backend/database outage, activation/email failure, or app crash.

## Daily sign-off

| Result | Tester signature/name | Time | Owner acknowledgement when conditional/failed |
| --- | --- | --- | --- |
| Pass / Conditional / Fail | | | |
