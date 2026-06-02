// Firebase Service - DISABLED for Windows builds
// This service is not available when building for Windows
// All functionality runs in offline mode

import 'package:flutter/foundation.dart';

/// Firebase Service for cloud sync (disabled for Windows)
/// All methods return empty/false responses in offline mode
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  Future<void> initialize() async {
    debugPrint('ℹ️ Firebase Service: Not available (offline mode)');
  }

  bool get isAuthenticated => false;

  Future<bool> signIn({required String email, required String password}) async {
    debugPrint('ℹ️ Firebase Service: Sign in not available (offline mode)');
    return false;
  }

  Future<void> signOut() async {
    debugPrint('ℹ️ Firebase Service: Sign out not available (offline mode)');
  }

  Future<void> syncData() async {
    debugPrint('ℹ️ Firebase Service: Sync not available (offline mode)');
  }

  // Stub methods for compatibility
  Future<void> syncProducts() async {}
  Future<void> syncSales() async {}
  Future<void> syncUsers() async {}
  Future<void> uploadImage(String path) async {}
  Future<void> deleteImage(String url) async {}
}
