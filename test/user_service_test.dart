import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_monitoring_system/models/user.dart';
import 'package:smart_monitoring_system/services/user_service.dart';

void main() {
  late UserService userService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    userService = UserService();
    await userService.resetForTesting();
  });

  tearDown(() async {
    await userService.resetForTesting();
  });

  test('loads legacy user records and normalizes them', () async {
    SharedPreferences.setMockInitialValues({
      'users_data': jsonEncode([
        {
          'id': 'legacy-user-1',
          'full_name': 'Legacy Manager',
          'email': 'legacy@store.com',
          'password_hash': 'secret123',
          'contact_number': '1234',
          'role': 'manager',
          'business_id': 'biz-1',
          'created_at': '2026-07-01T10:00:00.000Z',
          'is_active': 1,
          'auth_method': 'password',
        },
      ]),
    });

    await userService.resetForTesting();
    await userService.initialize();

    final loaded = userService.getUserByEmail('legacy@store.com');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Legacy Manager');
    expect(loaded.password, 'secret123');
    expect(loaded.pin, '1234');
    expect(loaded.role, UserRole.manager);
    expect(loaded.businessId, 'biz-1');
    expect(loaded.isActive, isTrue);
    expect(loaded.authMethod, 'password');

    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('users_data');
    expect(savedData, isNotNull);
    final savedUsers = jsonDecode(savedData!) as List<dynamic>;
    expect(savedUsers, hasLength(1));
    expect(
      Map<String, dynamic>.from(savedUsers.first as Map)['email'],
      'legacy@store.com',
    );
  });

  test('addUser persists a new user to SharedPreferences', () async {
    await userService.initialize();

    final success = await userService.addUser(
      User(
        id: 'user-100',
        name: 'New User',
        email: 'new@store.com',
        password: 'password123',
        pin: '9876',
        role: UserRole.cashier,
        createdAt: DateTime.parse('2026-07-05T00:00:00.000Z'),
      ),
      queueCloudSync: false,
    );

    expect(success, isTrue);
    expect(userService.getUserByEmail('new@store.com'), isNotNull);

    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('users_data');
    expect(savedData, isNotNull);

    final savedUsers = (jsonDecode(savedData!) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    expect(
      savedUsers.any((u) => u['email'] == 'new@store.com'),
      isTrue,
    );
  });
}
