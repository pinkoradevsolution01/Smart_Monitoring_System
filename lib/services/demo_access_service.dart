import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../models/user.dart' as user_model;
import '../models/pricing_package.dart';
import 'user_service.dart';
import 'database_service.dart';
import 'seed_service.dart';
import 'package_service.dart';

/// DemoAccessService provides functionality for developers to quickly
/// access the system with pre-configured demo accounts and data.
class DemoAccessService {
  final UserService _userService = GetIt.I.get<UserService>();
  final DatabaseService _db = DatabaseService();
  final PackageService _packageService = GetIt.I.get<PackageService>();

  /// Demo account credentials for different roles
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

  /// Initialize demo accounts and set package to Standard
  Future<bool> initializeDemoAccounts() async {
    try {
      // Set package to Standard for demo mode
      final standardPackage = PricingPackage.packages.firstWhere(
        (p) => p.type == PackageType.standard,
      );
      await _packageService.selectPackage(standardPackage);
      debugPrint('✅ Demo package set to Standard');

      // Check if demo accounts already exist
      for (final entry in demoAccounts.entries) {
        final user = _userService.getUserByEmail(entry.value['email']!);
        if (user == null) {
          // Create demo account
          final newUser = user_model.User(
            id: 'demo_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
            name: entry.value['name']!,
            email: entry.value['email']!,
            password: entry.value['password']!,
            pin: '1234',
            role: _getRoleFromString(entry.key),
            createdAt: DateTime.now(),
            isActive: true,
          );
          await _userService.addUser(newUser);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error initializing demo accounts: $e');
      return false;
    }
  }

  /// Seed demo products into the database
  Future<bool> seedDemoProducts() async {
    try {
      final existing = await _db.getAllProducts();
      if (existing.isNotEmpty) {
        debugPrint('Database already has ${existing.length} products.');
        return false;
      }

      final success = await SeedService.seedSampleProducts();
      return success;
    } catch (e) {
      debugPrint('Error seeding demo products: $e');
      return false;
    }
  }

  /// Get demo account details by role
  Map<String, String>? getDemoAccountByRole(String role) {
    return demoAccounts[role];
  }

  /// Get all available demo roles
  List<String> getAvailableDemoRoles() {
    return demoAccounts.keys.toList();
  }

  /// Clear all demo data (accounts only - products can be cleared via seeding)
  Future<bool> clearAllDemoData() async {
    try {
      // Delete demo accounts
      for (final entry in demoAccounts.entries) {
        await _userService.deleteUserByEmail(entry.value['email']!);
      }

      debugPrint('Cleared all demo accounts');
      return true;
    } catch (e) {
      debugPrint('Error clearing demo data: $e');
      return false;
    }
  }

  /// Convert string role to UserRole enum
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

  /// Format role string for display
  static String formatRoleForDisplay(String role) {
    switch (role) {
      case 'owner':
        return '👑 Owner';
      case 'cashier':
        return '💳 Cashier';
      case 'manager':
        return '📊 Manager';
      case 'inventoryClerk':
        return '📦 Inventory Clerk';
      case 'salesPromoter':
        return '🎯 Sales Promoter';
      case 'deliveryReceiver':
        return '🚚 Delivery Receiver';
      default:
        return role;
    }
  }
}
