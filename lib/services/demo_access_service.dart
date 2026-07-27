import '../models/user.dart' as user_model;

/// Provides temporary, in-memory users for client demonstrations.
/// This service intentionally has no persistence, database, package, or sync
/// dependencies.
class DemoAccessService {
  static const Map<String, Map<String, String>> demoAccounts = {
    'owner': {
      'email': 'demo.owner@test.local',
      'password': 'demo123',
      'name': 'Demo Owner',
    },
    'cashier': {
      'email': 'demo.cashier@test.local',
      'password': 'demo123',
      'name': 'Demo Cashier',
    },
    'manager': {
      'email': 'demo.manager@test.local',
      'password': 'demo123',
      'name': 'Demo Manager',
    },
    'inventoryClerk': {
      'email': 'demo.inventory@test.local',
      'password': 'demo123',
      'name': 'Demo Inventory Clerk',
    },
    'salesPromoter': {
      'email': 'demo.promoter@test.local',
      'password': 'demo123',
      'name': 'Demo Sales Promoter',
    },
    'deliveryReceiver': {
      'email': 'demo.delivery@test.local',
      'password': 'demo123',
      'name': 'Demo Delivery Receiver',
    },
  };

  Map<String, String>? getDemoAccountByRole(String role) => demoAccounts[role];

  List<String> getAvailableDemoRoles() => demoAccounts.keys.toList();

  /// Creates a user only in memory for the current demonstration session.
  user_model.User? createDemoUser(String role) {
    final account = demoAccounts[role];
    if (account == null) return null;
    return user_model.User(
      id: 'demo-session-$role',
      name: account['name']!,
      email: account['email']!,
      password: account['password']!,
      pin: '1234',
      role: _getRoleFromString(role),
      createdAt: DateTime.now(),
      isActive: true,
    );
  }

  user_model.UserRole _getRoleFromString(String role) {
    switch (role) {
      case 'owner':
        return user_model.UserRole.owner;
      case 'cashier':
        return user_model.UserRole.cashier;
      case 'manager':
        return user_model.UserRole.manager;
      case 'inventoryClerk':
        return user_model.UserRole.inventoryClerk;
      case 'salesPromoter':
        return user_model.UserRole.salesPromoter;
      case 'deliveryReceiver':
        return user_model.UserRole.deliveryReceiver;
      default:
        return user_model.UserRole.staff;
    }
  }

  static String formatRoleForDisplay(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'cashier':
        return 'Cashier';
      case 'manager':
        return 'Manager';
      case 'inventoryClerk':
        return 'Inventory Clerk';
      case 'salesPromoter':
        return 'Sales Promoter';
      case 'deliveryReceiver':
        return 'Delivery Receiver';
      default:
        return role;
    }
  }
}
