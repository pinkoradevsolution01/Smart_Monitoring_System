import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_monitoring_system/models/user.dart';
import 'package:smart_monitoring_system/screens/developer/backend_connection_test.dart';
import 'package:smart_monitoring_system/screens/shared/developer_auth_screen.dart';
import 'package:smart_monitoring_system/services/backend_api_service.dart';
import 'package:smart_monitoring_system/services/developer_service.dart';
import 'package:smart_monitoring_system/services/google_auth_service.dart';
import 'package:smart_monitoring_system/services/user_service.dart';

class FakeGoogleAuth extends Fake implements GoogleAuthService {
  @override
  Future<void> signOut() async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<Map<String, dynamic>?> signInWithGoogle({
    GoogleAuthProfile profile = GoogleAuthProfile.developer,
  }) async {
    await (await SharedPreferences.getInstance()).setString(
      'backend_access_token',
      'google-token',
    );
    return {
      'email': 'developer@example.com',
      'name': 'Developer',
      'id': 'google-id',
    };
  }

  @override
  Future<void> storeSession() async {
    await (await SharedPreferences.getInstance()).setString(
      'backend_access_token',
      'google-token',
    );
  }
}

class FakeDeveloperService extends Fake implements DeveloperService {
  @override
  Future<bool> authenticateWithGoogle({
    required String email,
    required String name,
    required String googleSub,
    String? avatarUrl,
  }) async {
    await (await SharedPreferences.getInstance()).setString(
      'backend_access_token',
      'developer-token',
    );
    return true;
  }
}

class FakeUserService extends Fake implements UserService {
  @override
  List<User> getUsersByRoleIncludingInactive(UserRole role) => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'developer authorization stores its token for subsequent health requests',
    () async {
      SharedPreferences.setMockInitialValues({
        'backend_access_token': 'google-token',
      });
      final client = ApiClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/developer/google/register')) {
            expect(request.headers['authorization'], 'Bearer google-token');
            return http.Response(
              '{"success":true,"token":"developer-token"}',
              200,
            );
          }
          expect(request.headers['authorization'], 'Bearer developer-token');
          return http.Response('{"success":true}', 200);
        }),
      );
      final developer = DeveloperService.forTesting(client);
      expect(
        await developer.authenticateWithGoogle(
          email: 'dev@example.com',
          name: 'Dev',
          googleSub: 'id',
        ),
        isTrue,
      );
      await client.get('developer/system-health');
      developer.dispose();
    },
  );

  test(
    'developer authorization fails closed when a token is missing',
    () async {
      final developer = DeveloperService.forTesting(
        ApiClient(
          MockClient((_) async => http.Response('{"success":true}', 200)),
        ),
      );
      expect(
        await developer.authenticateWithGoogle(
          email: 'dev@example.com',
          name: 'Dev',
          googleSub: 'id',
        ),
        isFalse,
      );
      developer.dispose();
    },
  );

  testWidgets('Google developer login retains the authorized developer token', (
    tester,
  ) async {
    GetIt.I.registerSingleton<UserService>(FakeUserService());
    GetIt.I.registerSingleton<DeveloperService>(FakeDeveloperService());
    addTearDown(() async => GetIt.I.reset());
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DeveloperAuthScreen(googleAuth: FakeGoogleAuth()),
        routes: {
          '/developer-dashboard': (_) =>
              const Scaffold(body: Text('Developer dashboard')),
        },
      ),
    );
    await tester.ensureVisible(find.text('SIGN IN WITH GOOGLE'));
    await tester.tap(find.text('SIGN IN WITH GOOGLE'));
    await tester.pumpAndSettle();
    expect(find.text('Developer dashboard'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('backend_access_token'),
      'developer-token',
    );
  });

  for (final status in [401, 403]) {
    testWidgets(
      'health screen distinguishes developer authorization $status from connection failure',
      (tester) async {
        final requests = <String>[];
        final api = ApiClient(
          MockClient((request) async {
            requests.add(request.url.path);
            if (request.url.path.endsWith('/health/db')) {
              return http.Response(
                jsonEncode({'status': 'ok', 'database': 'smart_monitoring'}),
                200,
              );
            }
            if (request.url.path.endsWith('/health')) {
              return http.Response('{"status":"ok"}', 200);
            }
            return http.Response(
              '{"message":"Developer access is required."}',
              status,
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(home: BackendConnectionTest(apiClient: api)),
        );
        await tester.tap(find.text('Run Connection Test'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text('Backend API is reachable'), findsOneWidget);
        expect(
          find.text('MySQL database connection is healthy'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Developer access is required.'),
          findsOneWidget,
        );
        expect(find.text('❌ Connection failed!'), findsNothing);
        expect(requests.last, endsWith('/developer/system-health'));
      },
    );
  }
}
