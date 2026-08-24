# Smart Monitoring System — Web Analytics Build Specification

## Purpose

Build a responsive, production-ready **web analytics dashboard** connected to the Smart Monitoring System. It is an operational reporting interface for a retail business: it must show sales, inventory, customers, staff attendance, purchasing, damage/returns, CCTV event markers, and subscription status. It is **not** a replacement for the Flutter POS or a direct camera-stream viewer.

Use this document as the source prompt/specification for the web application builder.

## Existing system context

The source system is a multi-tenant Flutter application used on desktop and mobile. Its Node.js/Express backend uses MySQL and exposes REST endpoints under a base URL ending in `/api`. Each business is a tenant, identified by `businessId`. Relevant current modules are:

- POS sales, sale items, discounts, payment methods, delivery orders and receipts
- Product inventory, restocks, purchase orders, stock movements and damage reports
- Customers and loyalty points
- Users/roles, attendance and payroll inputs
- CCTV camera configuration and manually recorded timestamp events
- License activation, subscriptions and developer operations
- Local-first app data, with explicit cloud synchronization

Suggested deployment topology:

```text
Smart Monitoring Flutter app ─┐
                              ├→ Same Node.js / Express API → Same MySQL database
Web analytics dashboard ──────┘
```

The dashboard is a second client of the **same backend and database**, not a separate system. A subscriber/business registered in Smart Monitoring System uses the same email/password account to log into the dashboard. After the backend verifies that account, it uses the account’s assigned `businessId` to return only that subscriber’s synchronized operational data.

The dashboard reads centralized MySQL-backed data after the Flutter client has synchronized it. It must clearly show a **last refreshed** time; it is not guaranteed to be real-time while a client is offline.

### Shared subscriber login and data flow

```text
1. Subscriber registers/activates Smart Monitoring System
       ↓
2. Backend stores the tenant in businesses and the account in users
   (users.business_id → businesses.id)
       ↓
3. Flutter app synchronizes that business's operational data to the same MySQL database
       ↓
4. Subscriber logs in to the web analytics using the same email and password
       ↓
5. POST /api/auth/login returns a JWT containing the user's role and businessId
       ↓
6. /api/analytics endpoints verify the JWT and query WHERE business_id = JWT businessId
       ↓
7. Web dashboard displays only that subscriber/business's data
```

There must be **no separate web `users`, `subscribers`, or analytics database**. The web application must never ask a subscriber to enter a business ID or select a tenant. The server owns the association between the authenticated account and its business.

## Recommended technology stack

Use the following stack to keep the analytics website compatible with the existing Smart Monitoring System backend while providing a modern, maintainable web interface.

| Layer | Technology | Purpose |
| --- | --- | --- |
| Web application | **React 18 + TypeScript + Vite** | Fast, type-safe single-page dashboard application. |
| UI and styling | **Tailwind CSS + shadcn/ui** | Responsive, accessible dashboard layouts and reusable controls. |
| Charts | **Recharts** | Sales trends, payment breakdowns, inventory status, and operational charts. |
| Data fetching/cache | **TanStack Query** | Typed API requests, caching, loading/error states, and controlled refreshes. |
| Routing | **React Router** | Protected routes and navigation between analytics pages. |
| Tables | **TanStack Table** | Sortable, filterable, paginated analytics tables. |
| Date/range handling | **date-fns** | Date-range selectors, comparison periods, and timezone-aware display helpers. |
| Existing API | **Node.js 20 + Express** | Extend the repository’s backend with a protected `/api/analytics` router. |
| Authentication | **JWT + Express middleware** | Reuse the existing login token and enforce roles/business scope on the server. |
| Database | **MySQL 8** | Continue using the system’s existing centralized operational database. |
| Database access | **mysql2/promise** | Existing backend database driver; use parameterized SQL for analytics queries. |
| API validation | **Zod** (recommended) | Validate query parameters, date ranges, filter values, and API response contracts. |
| CSV export | Server-generated CSV response | Secure exports that use the same authorization and tenant scope as reports. |
| Deployment: web | **Vercel** | Host the React/Vite dashboard and configure its custom domain. |
| Deployment: API | **DigitalOcean Droplet + Nginx + PM2** | Run the persistent Express API over HTTPS. |
| Automated tests | **Vitest + React Testing Library**; **Jest/Supertest** for API | Test calculations, UI states, authorization, and endpoint behavior. |
| End-to-end tests | **Playwright** | Verify login, filtering, charts, protected routes, and export workflows. |

### Recommended project structure

Keep the web application as a separate folder/project so it can be deployed independently without disrupting the existing Flutter application:

```text
Smart_Monitoring_System/
├── backend/                     # Existing Express + MySQL API
│   └── routes/analytics.js       # New protected analytics endpoints
└── web-analytics/                # New React + TypeScript + Vite application
    ├── src/
    │   ├── api/                  # Typed API client and request hooks
    │   ├── components/           # Cards, charts, tables, filters
    │   ├── pages/                # Overview, Sales, Inventory, etc.
    │   ├── auth/                 # Session and protected-route logic
    │   ├── types/                # Shared API/domain types
    │   └── test/                 # Frontend tests
    └── .env.example              # VITE_API_BASE_URL only; no secrets
```

### Why this stack

- It reuses the current **Express/MySQL/JWT** operation instead of duplicating business data in another platform.
- React, TypeScript, TanStack Query, and Tailwind provide a strong foundation for data-heavy analytics interfaces.
- The analytics router keeps sensitive aggregation logic, authorization, tenant isolation, CSV generation, and large-data queries on the server.
- Vercel and a DigitalOcean-hosted API match the deployment architecture already documented for this system.

Do not use Firebase, Supabase, or direct browser-to-MySQL connections for the new analytics application. Existing Supabase/Firebase features may remain in the Flutter system, but analytics should use the Node.js API as its single controlled data access layer.

## Step-by-step implementation process

Follow these steps in order. Do not make the web dashboard publicly available until the authentication and tenant-enforcement steps are complete.

### Step 1 — Confirm the production data source

1. Use the existing Smart Monitoring **Node.js/Express backend and MySQL database** as the only backend/data source for both the Flutter app and the new website. Do not create a second database for website subscribers or analytics records.
2. Confirm that Smart Monitoring registration/onboarding creates a row in `businesses` and creates or links the owner/staff account in `users` with the correct `users.business_id`.
3. Confirm that the Flutter application synchronizes operational records to that same MySQL database through `POST /api/sync/push`.
4. Confirm the API base URL, HTTPS domain, MySQL database name, and the production timezone (`Asia/Manila` initially). Configure the dashboard's `VITE_API_BASE_URL` to this same API base.
5. Check that each participating business has a stable `businesses.id`, and that every synchronized operational record has the correct `business_id`.
6. Create a safe test subscriber by registering/activating through Smart Monitoring System. Sign in with the same email/password in the Flutter app and the website; confirm both sessions resolve to the same `businessId`.
7. Populate the test business with representative products, completed and cancelled sales, sale items, customers, restocks, movements, attendance entries, CCTV timestamps, and damage reports.
8. Do not point a development dashboard at production until server authorization tests have passed.

**Deliverable:** a verified shared API/database environment, plus a test subscriber that can log in to both applications and see the same assigned business data.

### Step 2 — Add backend authorization middleware

1. Create reusable Express middleware that requires a valid JWT and rejects missing, invalid, or expired tokens with HTTP `401`.
2. Add role middleware that permits only `owner`, `admin`, and `manager` for business analytics; create a separate developer-only guard for platform-wide subscription analytics.
3. Reuse the existing `POST /api/auth/login` endpoint for the web login. It validates the same `users` records and password hashes used by Smart Monitoring System and returns a JWT containing `userId`, `role`, and `businessId`.
4. Derive the business scope from `req.auth.businessId` only. Do not trust `businessId` query parameters, request-body values, or `x-business-id` headers from browser clients.
5. Reject a business analytics request if the verified token has no business ID, if the user is inactive, or if the linked business is inactive/cancelled.
6. Apply this middleware to every new `/api/analytics/*` endpoint before any database query executes.
7. Add tests proving that a user cannot query, export, or infer another business’s data—even if they change a URL parameter to a known `businessId`.

**Deliverable:** tested shared-login authentication, role checks, and tenant-isolation middleware.

### Step 3 — Create the dedicated analytics API

1. Create `backend/routes/analytics.js` and mount it in `backend/app.js` at `/api/analytics`.
2. Add a shared validator for `from`, `to`, `groupBy`, pagination, filter values, and export report names. Require ISO date values and restrict the maximum range to 366 days.
3. Implement `GET /api/analytics/overview` first. Return KPI values, sales time series, payment-method breakdown, top products, low-stock products, recent activity, and metadata in one response.
4. Add the Sales, Inventory, Customers, Operations, CCTV Events, CSV Export, and developer-only Subscription endpoints described in **Required analytics API layer**.
5. Use parameterized SQL only. Filter every tenant query by the server-derived business ID.
6. Return paginated tables with `page`, `pageSize`, and `total`; never rely on the generic CRUD endpoint’s 1,000-row maximum for totals.
7. Exclude sensitive fields at query level, particularly credentials, hashes, stream URLs, raw tokens, and unnecessary PII.
8. Add or verify MySQL indexes after observing actual query plans; begin with `(business_id, datetime, status)` for sales.

**Deliverable:** authenticated, documented analytics endpoints with stable response types.

### Step 4 — Verify metric accuracy

1. Write API tests for each metric in **Analytics definitions**.
2. Include completed sales, cancelled sales, discounts, refunds/adjustments if used, no-sale date ranges, timezone-boundary transactions, low/out-of-stock products, and incomplete buying prices.
3. Confirm that all revenue figures include completed sales only and use `sales.datetime` for date filtering.
4. Compare endpoint results with a manually checked set of MySQL records.
5. Test perpetual (`expires_at = null`), active, expired, and cancelled subscription cases.

**Deliverable:** calculation test suite and manually verified expected results.

### Step 5 — Scaffold the web analytics application

1. Create `web-analytics/` using React, TypeScript, and Vite.
2. Install and configure Tailwind CSS, shadcn/ui, React Router, TanStack Query, TanStack Table, Recharts, date-fns, and a validation library.
3. Add `.env.example` with `VITE_API_BASE_URL=https://your-api-domain/api`; do not commit production values, credentials, or secrets.
4. Create a typed API client and TypeScript response models that match the analytics endpoint contracts.
5. Configure global query error handling, retry behavior for transient failures, and a visible session-expired flow.
6. Add shared layout components: application shell, sidebar, header, date-range filter, loading state, empty state, error state, KPI card, chart wrapper, and paginated table.

**Deliverable:** runnable dashboard shell connected to a local/mock analytics API contract.

### Step 6 — Implement authentication and protected navigation

1. Build the login screen using the existing `POST /api/auth/login`; do not add a website-only registration form, users table, or authentication provider.
2. Let a registered Smart Monitoring subscriber enter the same email and password they already use in the app. Include `businessId` only when the existing login endpoint needs it to disambiguate duplicate email accounts; preferably expose a safe account/business selection flow from the backend rather than allowing arbitrary IDs.
3. Store the access token in the chosen secure session mechanism and attach it to all protected API calls as a Bearer token.
4. Fetch `GET /api/auth/me` to restore the session and obtain user/role/business context. Display the resolved business name, not an editable business selector.
5. Add route guards for owner/admin/manager screens and a separate guard for developer screens.
6. Remove the token and return to login after logout, token expiry, deactivation, or an authorization failure.
7. Test one subscriber account in both the Flutter app and web dashboard: data entered/synchronized in the app must appear under the same assigned business on the website.
8. Test that manually changing URLs, query parameters, browser storage, or client state cannot reveal another tenant’s data.

**Deliverable:** same-account login across Flutter and web, plus secure session restoration, logout, and role-protected routes.

### Step 7 — Build the Overview dashboard

1. Add date presets (Today, Last 7 Days, Last 30 Days, This Month, Custom) and prior-period comparison.
2. Load the overview endpoint through TanStack Query using the selected filters.
3. Display gross sales, discounts, net sales, transaction count, average order value, items sold, active customers, low-stock count, and last refreshed time.
4. Add sales trend, payment-method, top-product, and low-stock visualizations with accessible table alternatives.
5. Support manual refresh and show the API `generatedAt` value.
6. Ensure all cards and charts have correct loading, empty, and error states.

**Deliverable:** complete, responsive overview dashboard.

### Step 8 — Build detailed analytics pages

1. Build the Sales page with trends, cashier/payment/product breakdowns, filters, and a paginated transaction table.
2. Build the Inventory page with stock status, inventory value, movement/restock/damage trends, and reorder candidates.
3. Build the Customers page with aggregate customer/loyalty metrics and role-restricted detail tables.
4. Build the Operations page for attendance, purchase orders, suppliers, and damage-report statuses.
5. Build the CCTV Events page using timestamp events and safe camera labels only; never request or display camera credentials or stream links.
6. Build the developer-only subscriptions page separately, using developer-authorized endpoints only.

**Deliverable:** all required analytics pages with consistent date filters, tables, and permissions.

### Step 9 — Add exports and operational polish

1. Add report export controls that call the server-side CSV endpoint with the active filters.
2. Name exported files with report name and selected date range.
3. Add print-friendly report layouts if required; keep CSV as the minimum supported export format.
4. Add responsive behavior for tablet screens, keyboard navigation, visible focus styles, aria labels, and color-independent status indicators.
5. Add an unobtrusive sync/refresh notice explaining that data reflects completed synchronization from Flutter clients.

**Deliverable:** secure exports and an accessible, polished reporting experience.

### Step 10 — Test, deploy, and monitor

1. Run API unit/integration tests with Jest/Supertest and frontend component tests with Vitest/React Testing Library.
2. Run Playwright end-to-end tests for login, tenant isolation, filtering, error states, exports, and session expiration.
3. Run a production build and check bundle size, page performance, responsiveness, and accessibility.
4. Deploy the React application to Vercel and the Express API to the secured DigitalOcean/Nginx/PM2 environment.
5. Set production CORS to the web dashboard domain, enable HTTPS, configure environment variables, and verify database backups.
6. Monitor API errors, slow queries, failed exports, authentication failures, and dashboard access logs. Review indexes as data volume grows.
7. Perform an owner acceptance test against a non-production tenant before releasing the dashboard to live users.

**Deliverable:** tested production deployment with monitoring and a release checklist.

## Required application behavior

### Users and access

- Provide a login page using the existing `POST /api/auth/login` flow.
- Store the JWT in a secure, short-lived browser session mechanism. Send `Authorization: Bearer <token>` on every protected request.
- Determine the tenant from the authenticated token’s `businessId`; do not let a standard user choose or override another `businessId`.
- Allow owner, admin, and manager dashboards. Cashier and staff roles should have no access unless a later policy explicitly grants it.
- A developer-only global view may aggregate subscription/license information, but must be entirely separate from a business analytics view.
- Include logout and session-expired handling.

### Dashboard pages

1. **Overview** — default page with date range, comparison period, business name, last sync/refresh timestamp, KPI cards, sales trend, payment mix, top products, low-stock list, and recent activity.
2. **Sales analytics** — gross sales, completed/cancelled transaction counts, discounts, net sales, average order value, items per order, trend by day/hour, payment method, cashier ranking, category/product performance, and transaction table.
3. **Inventory analytics** — stock on hand, low/out-of-stock products, stock value (using `buying_price` where present), inventory movement trend, restocks, damage quantities/cost, and reorder candidates.
4. **Customers and loyalty** — active customers, new customers, repeat customer rate when derivable, loyalty balances/earned/redeemed points, and top customers. Do not expose customer PII in aggregate charts; restrict detailed customer tables to authorized roles.
5. **Operations** — attendance clock-in/out events, purchase order status and amount, supplier activity, and damage-report status.
6. **CCTV events** — camera inventory and time-stamped event log filtered by camera/date. Show labels, descriptions and event times only. Never expose stream URLs, camera usernames, or camera passwords.
7. **Reports and export** — export the currently filtered result as CSV. PDF export/print is optional. Export must respect the same role and business scope as the screen.
8. **Developer subscription view** — only for a developer account: activation-code and subscription counts by package/status, upcoming expirations, and pending activation requests. Do not mix these metrics with a business owner’s daily sales dashboard.

### Usability and design

- Desktop-first responsive dashboard, usable at 1280 px and above and readable on tablet widths.
- Professional, calm operations design: sidebar navigation, compact header, clear status colors, accessible contrast, keyboard-friendly controls, loading/empty/error states.
- Default date range: last 30 days. Support Today, Last 7 days, Last 30 days, This Month, custom range, and prior-period comparison.
- Display money in the business-configured currency; until configuration exists, use PHP with `en-PH` formatting.
- Treat all backend timestamps as server time and state the timezone in the UI. Use `Asia/Manila` as the initial product default unless business-level settings are later added.
- Charts need tooltips, labels/legends, responsive resizing, and downloadable table data. Never make a chart the only way to access important values.

## Data contract

### Existing REST base and conventions

Configure `VITE_API_BASE_URL` (or equivalent) to the complete API base, for example `https://api.example.com/api`. JSON requests use `Content-Type: application/json`. Most current list responses look like:

```json
{ "success": true, "data": [] }
```

Business-scoped resource reads currently accept `businessId` as `?businessId=...`, `x-business-id`, or from a JWT claim. The existing generic resource endpoints support `limit` (1–1000), `offset`, `orderBy`, `orderDirection`, plus selected exact-match filters.

**Security rule:** the web client must not rely on the query parameter as its authorization boundary. The server must derive/enforce the tenant from the verified JWT.

### Existing business-scoped resources

| Resource | Existing endpoint | Key fields used by analytics |
| --- | --- | --- |
| Sales | `GET /sales` | `id`, `cashier_name`, `customer_id`, `payment_method`, `status`, `subtotal`, `discount`, `total_amount`, `item_count`, `datetime`, `transaction_type`, `delivery_status` |
| Sale items | `GET /sale-items` | `sale_id`, `product_id`, `product_name`, `quantity`, `unit_price`, `discount`, `subtotal`, `shoe_size` |
| Products | `GET /products` | `id`, `barcode`, `name`, `category`, `buying_price`, `selling_price`, `quantity`, `low_stock_threshold`, `updated_at` |
| Inventory movements | `GET /inventory-movements` | `product_id`, `product_name`, `movement_type`, `quantity`, `reference`, `performed_by`, `timestamp` |
| Restocks | `GET /restock-records` | `product_id`, `product_name`, `quantity`, `supplier_name`, `damage_quantity`, `restock_date` |
| Damage reports | `GET /damage-reports` | `product_id`, `product_name`, `quantity`, `damage_type`, `status`, `reported_at` |
| Purchase orders | `GET /purchase-orders` | `supplier_id`, `order_number`, `order_date`, `expected_delivery`, `status`, `total_amount` |
| Suppliers | `GET /suppliers` | `name`, `contact_person`, `is_active`, `created_at` |
| Customers | `GET /customers` | `full_name`, `points_balance`, `lifetime_points`, `created_at`, `is_active` |
| Loyalty ledger | `GET /loyalty-ledger` | `customer_id`, `sale_id`, `entry_type`, `points`, `balance_after`, `created_at` |
| Attendance | `GET /attendance-entries` | `user_id`, `time`, `type` |
| CCTV event markers | `GET /cctv-timestamps` | `camera_id`, `label`, `description`, `timestamp`, `created_by` |
| Cameras | `GET /cameras` | safe display fields only: `id`, `name`, `location`, `type`, `is_active` |
| Activity log | `GET /activity-logs` | `type`, `message`, `meta`, `created_at` |

All endpoints in this table are relative to the configured `/api` base and require a business scope. Do not retrieve the `password` or `stream_url` columns from camera records in any analytics response.

### Developer-wide endpoints

The following data is not business-scoped and must be exposed only through a hardened developer authorization policy:

- `GET /license/subscriptions?status=active|expired|cancelled`
- `GET /license/codes?status=unused|used|assigned|revoked&packageName=...&includeSubscription=true`
- `GET /license/requests?status=pending|fulfilled|cancelled`
- `GET /license/subscription-renewals?subscriptionId=...`

Fields include package name, activation/expiry dates, status, device name, and request state. Never display activation codes in overview charts; mask them in tables unless the developer deliberately reveals/copies one.

## Analytics definitions

Use server-side calculations as the source of truth. Unless a screen explicitly says otherwise, sales metrics include `status = 'completed'` only.

| Metric | Definition |
| --- | --- |
| Gross sales | `SUM(sales.subtotal)` for completed sales in the range |
| Discounts | `SUM(sales.discount)` for completed sales |
| Net sales | `SUM(sales.total_amount)` for completed sales |
| Transactions | `COUNT(sales.id)` for completed sales |
| Average order value | Net sales ÷ transactions; zero when there are no transactions |
| Items sold | `SUM(sales.item_count)` or, when itemized, `SUM(sale_items.quantity)` for completed parent sales |
| Top products | Group sale items from completed sales by product, ordered by quantity/revenue |
| Sales by payment | Group completed sales by `payment_method` |
| Low stock | Products where `quantity > 0 AND quantity <= low_stock_threshold` |
| Out of stock | Products where `quantity <= 0` |
| Inventory cost value | `SUM(products.quantity * products.buying_price)`; label as unavailable if cost data is incomplete |
| Inventory retail value | `SUM(products.quantity * products.selling_price)` |
| Damage rate | Damaged quantity ÷ (restocked quantity + damaged quantity), for the selected range; show N/A if denominator is zero |
| New customers | Customers with `created_at` inside the selected range |
| Subscription active | `status = 'active'` and (`expires_at` is null for a perpetual license or `expires_at >= now`) |

Do not infer a transaction’s date from `created_at` when `sales.datetime` exists. Do not count cancelled sales as revenue. Preserve decimal money precision: use decimal strings/server calculations, never floating-point accumulation in the browser.

## Required analytics API layer

The existing CRUD API is appropriate for app synchronization, but inefficient and unsafe as the sole public analytics interface: it allows broad resource reads, pagination maxes at 1,000 rows, and route-level authorization is not consistently enforced. Implement a dedicated server-side analytics router before production use.

Recommended endpoints (all require a valid JWT, authorize role, and derive business ID from the token):

```text
GET /api/analytics/overview?from=YYYY-MM-DD&to=YYYY-MM-DD&compare=true
GET /api/analytics/sales?from=&to=&groupBy=day|week|month&cashierId=&paymentMethod=&page=&pageSize=
GET /api/analytics/inventory?from=&to=&category=&status=all|low|out
GET /api/analytics/customers?from=&to=&page=&pageSize=
GET /api/analytics/operations?from=&to=
GET /api/analytics/cctv-events?from=&to=&cameraId=&page=&pageSize=
GET /api/analytics/export?report=sales|inventory|customers|operations&from=&to=&format=csv
GET /api/analytics/developer/subscriptions?from=&to=  (developer role only)
```

The server should use parameterized SQL, validate ISO dates and a maximum date window (such as 366 days), cap page sizes, return only the necessary fields, and return an envelope such as:

```json
{
  "success": true,
  "data": { "kpis": {}, "series": [], "breakdowns": {} },
  "meta": {
    "businessId": "derived-on-server",
    "from": "2026-08-01",
    "to": "2026-08-20",
    "timezone": "Asia/Manila",
    "generatedAt": "2026-08-20T12:00:00.000Z"
  }
}
```

The overview request should minimize round trips by returning all dashboard cards and chart data in one response. Return pagination metadata (`page`, `pageSize`, `total`) for record tables. Create MySQL composite indexes for the actual query paths, beginning with `(business_id, datetime, status)` on `sales`, `(business_id, created_at)` on `sale_items`, and existing business/date indexes for movement and attendance tables; verify query plans against real data.

## Security and privacy requirements

- Enforce authentication and role checks in backend middleware, before every analytics query. A decoded but invalid/missing token is unauthenticated.
- For tenant users, ignore `businessId`, `x-business-id`, and similar client-supplied scope values when they conflict with the verified JWT.
- Do not expose password hashes, PIN hashes, camera URLs/credentials, raw email/phone lists, OTP/reset tokens, or secrets.
- Restrict CORS in production to the dashboard domain. Use HTTPS only.
- Validate/allow-list export report names, sort keys, filters, and grouping values. Apply rate limits to authentication and export endpoints.
- Log dashboard access and export actions without recording sensitive payloads.
- Use a dedicated database account with read-only access for analytics where deployment permits.

## Non-functional requirements and acceptance criteria

- No dashboard query may silently load only the first 1,000 records and present it as a complete report.
- Every visual and export respects both selected dates and server-enforced tenant scope.
- Each KPI and chart states whether it is based on synced central data and shows `generatedAt`/last refresh.
- Empty data has an explanatory state, not a zero-value claim where the data source is unavailable.
- Dashboard has loading and retriable error states, including a clear authentication-expired state.
- Test calculations with fixtures covering cancelled sales, zero transactions, discounts, perpetual/expired subscriptions, low/out-of-stock products, and timezone boundaries.
- Ensure responsive, accessible UI; charts have tabular equivalents and controls have visible labels.

## Builder implementation constraints

- Recommended web stack: React + TypeScript + Vite, with a component library and a chart library selected by the builder. Keep API calls in a typed service layer, separate from page components.
- The dashboard must connect through environment configuration only; do not hardcode the current server IP, credentials, JWT, database settings, or Google client secrets.
- Build the frontend against the dedicated analytics endpoints above. If they are not available yet, use a mock adapter with the same response shapes and mark it as development-only rather than attempting production aggregation in the browser.
- Do not alter existing Flutter flows, synchronization payloads, or MySQL schema semantics unless explicitly requested.

## Source files for validation

- `backend/app.js` — Express API entry point and route mounting
- `backend/routes/crud.js` — existing generic business-scoped REST resources
- `backend/routes/auth.js` — JWT login and account flows
- `backend/routes/license.js` — activation and subscription data
- `backend/schema.sql` — authoritative MySQL schema
- `lib/services/backend_config.dart` — client API base configuration
- `SYSTEM_DOCUMENTATION.md` — operational module and role overview
