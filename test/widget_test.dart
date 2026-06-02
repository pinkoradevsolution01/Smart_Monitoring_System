import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/main.dart';
import 'package:smart_monitoring_system/screens/auth/login_screen.dart';
import 'package:smart_monitoring_system/screens/admin/admin_dashboard.dart';
import 'package:smart_monitoring_system/screens/owner/owner_dashboard.dart';
import 'package:smart_monitoring_system/screens/cashier/cashier_dashboard.dart';
import 'package:smart_monitoring_system/screens/cashier/cashier_pos.dart';
import 'package:smart_monitoring_system/screens/shared/inventory_screen.dart';
import 'package:smart_monitoring_system/screens/owner/sales_report_screen.dart';
import 'package:smart_monitoring_system/screens/owner/cctv_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_monitoring_system/utils/app_localizations.dart';
import 'package:smart_monitoring_system/services/pos_service.dart';
import 'package:smart_monitoring_system/models/user.dart';

// Lightweight POSService fake for widget tests to avoid DB calls.
class _FakePOSService extends POSService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadProducts() async {}

  @override
  Future<void> loadRecentSales({int days = 7}) async {}
}

// Create test users for widget testing
User _createTestOwner() {
  return User(
    id: 'test-owner',
    name: 'Test Owner',
    email: 'owner@store.com',
    password: 'owner123',
    role: UserRole.owner,
    createdAt: DateTime.now(),
    isActive: true,
  );
}

User _createTestCashier() {
  return User(
    id: 'test-cashier',
    name: 'Test Cashier',
    email: 'cashier@store.com',
    password: 'cashier123',
    role: UserRole.cashier,
    createdAt: DateTime.now(),
    isActive: true,
  );
}

void main() {
  // Provide a lightweight fake POSService and localization for widget tests.
  setUpAll(() {
    // Ensure English locale for predictable labels
    // ignore: avoid_redundant_argument_values
    // LocaleController is not required here; AppLocalizations uses default 'en'
  });

  setUp(() {
    // Register a simple non-DB POSService to avoid hitting database in widget tests
    if (GetIt.I.isRegistered<POSService>()) {
      GetIt.I.unregister<POSService>();
    }

    final fake = _FakePOSService();
    GetIt.I.registerSingleton<POSService>(fake);
  });

  tearDown(() {
    if (GetIt.I.isRegistered<POSService>()) GetIt.I.unregister<POSService>();
  });
  // -----------------------------------------------------
  // 1. Test if the app loads successfully
  // -----------------------------------------------------
  testWidgets("App loads startup screen", (WidgetTester tester) async {
    await tester.pumpWidget(SmartStoreApp());
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  // -----------------------------------------------------
  // 2. Login Screen UI Test
  // -----------------------------------------------------
  testWidgets("Login screen contains email, password, and button", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen()));

    expect(find.text(AppLocalizations.t('email')), findsOneWidget);
    expect(find.text(AppLocalizations.t('password')), findsOneWidget);
    expect(find.text(AppLocalizations.t('login')), findsOneWidget);
  });

  // -----------------------------------------------------
  // 3. Routing test for ADMIN using fake credentials
  // -----------------------------------------------------
  testWidgets("Admin login navigates to Admin Dashboard", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextField).at(0), "admin@store.com");
    await tester.enterText(find.byType(TextField).at(1), "admin123");
    await tester.tap(find.text(AppLocalizations.t('login')));
    await tester.pumpAndSettle();

    expect(find.byType(AdminDashboard), findsOneWidget);
  });

  // -----------------------------------------------------
  // 4. Routing test for OWNER
  // -----------------------------------------------------
  testWidgets("Owner login navigates to Owner Dashboard", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextField).at(0), "owner@store.com");
    await tester.enterText(find.byType(TextField).at(1), "owner123");
    await tester.tap(find.text(AppLocalizations.t('login')));
    await tester.pumpAndSettle();

    expect(find.byType(OwnerDashboard), findsOneWidget);
  });

  // -----------------------------------------------------
  // 5. Routing test for CASHIER
  // -----------------------------------------------------
  testWidgets("Cashier login navigates to Cashier Dashboard", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextField).at(0), "cashier@store.com");
    await tester.enterText(find.byType(TextField).at(1), "cashier123");
    await tester.tap(find.text(AppLocalizations.t('login')));
    await tester.pumpAndSettle();

    expect(find.byType(CashierDashboard), findsOneWidget);
  });

  // -----------------------------------------------------
  // 6. Admin Dashboard buttons exist
  // -----------------------------------------------------
  testWidgets("Admin Dashboard loads menu list", (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AdminDashboard()));

    expect(find.text(AppLocalizations.t('manage_users')), findsOneWidget);
    expect(find.text(AppLocalizations.t('manage_products')), findsOneWidget);
  });

  // -----------------------------------------------------
  // 7. Owner Dashboard UI is visible
  // -----------------------------------------------------
  testWidgets("Owner Dashboard buttons appear", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OwnerDashboard(user: _createTestOwner())),
    );

    expect(find.text(AppLocalizations.t('view_sales_reports')), findsOneWidget);
    expect(find.text(AppLocalizations.t('monitor_cctv')), findsOneWidget);
  });

  // -----------------------------------------------------
  // 8. Cashier Dashboard UI loads
  // -----------------------------------------------------
  testWidgets("Cashier Dashboard loads POS button", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CashierDashboard(user: _createTestCashier())),
    );
    expect(find.text(AppLocalizations.t('open_pos')), findsOneWidget);
  });

  // -----------------------------------------------------
  // 9. POS UI loads
  // -----------------------------------------------------
  testWidgets("POS Screen loads placeholder text", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CashierPOS(cashierName: 'Test Cashier')),
    );
    expect(find.text(AppLocalizations.t('cashier_pos')), findsOneWidget);
  });

  // -----------------------------------------------------
  // 10. Inventory screen loads
  // -----------------------------------------------------
  testWidgets("Inventory Screen loads placeholder", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: InventoryScreen()));
    expect(find.text(AppLocalizations.t('inventory_status')), findsOneWidget);
  });

  // -----------------------------------------------------
  // 11. CCTV screen loads
  // -----------------------------------------------------
  testWidgets("CCTV Screen loads placeholder", (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: CCTVScreen()));
    expect(find.text('CCTV Monitoring'), findsOneWidget);
  });

  // -----------------------------------------------------
  // 12. Sales report screen loads
  // -----------------------------------------------------
  testWidgets("Sales Report Screen loads", (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SalesReportScreen()));
    expect(find.text('Sales Reports'), findsOneWidget);
  });
}
