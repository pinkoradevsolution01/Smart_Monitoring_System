import 'package:flutter/material.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shared/shared_data_screen.dart';
import 'screens/developer/demo_access_screen.dart';

/// App Router for named routes.
/// Note: Owner and Cashier dashboards now require user parameters,
/// so they should be navigated to using MaterialPageRoute with user data.
/// These routes are kept for backward compatibility with admin-only navigation.
class AppRouter {
  static Map<String, WidgetBuilder> routes = {
    '/admin': (context) => const AdminDashboard(),
    '/login': (context) => const LoginScreen(),
    '/shared-data': (context) => const SharedDataScreen(),
    '/demo-access': (context) => const DemoAccessScreen(),
    // Owner and Cashier routes removed as they now require user parameters
    // Use MaterialPageRoute(builder: (_) => OwnerDashboard(user: user)) instead
  };
}
