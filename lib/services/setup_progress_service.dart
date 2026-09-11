import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sale.dart';
import '../models/user.dart';
import 'business_info_service.dart';
import 'package_service.dart';
import 'pos_service.dart';
import 'user_service.dart';

/// Central source of truth for the Owner's first-time business setup. It only
/// observes existing services; it never creates records or changes package data.
class SetupProgressService extends ChangeNotifier {
  static const String _celebratedKeyPrefix = 'owner_setup_celebrated_';

  final BusinessInfoService _business;
  final PackageService _package;
  final POSService _pos;
  final UserService _users;
  bool _isComplete = false;

  SetupProgressService({
    required BusinessInfoService business,
    required PackageService package,
    required POSService pos,
    required UserService users,
  }) : _business = business,
       _package = package,
       _pos = pos,
       _users = users {
    _business.addListener(_refresh);
    _package.addListener(_refresh);
    _pos.addListener(_refresh);
    _users.addListener(_refresh);
    _refresh();
  }

  bool get isComplete => _isComplete;

  void _refresh() {
    final hasOwner = _users.activeUsers.any(
      (user) => user.role == UserRole.owner,
    );
    final hasCashier = _users.activeUsers.any(
      (user) => user.role == UserRole.cashier && user.id != 'cashier-1',
    );
    final hasFirstSale = _pos.recentSales.any(
      (sale) => sale.status == SaleStatus.completed,
    );
    final next =
        hasOwner &&
        _business.isConfigured &&
        _package.setupComplete &&
        _package.hasPackage &&
        _pos.products.isNotEmpty &&
        hasCashier &&
        hasFirstSale;
    if (next == _isComplete) return;
    _isComplete = next;
    notifyListeners();
  }

  Future<bool> hasCelebrated(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_celebratedKeyPrefix$ownerId') ?? false;
  }

  Future<void> markCelebrated(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_celebratedKeyPrefix$ownerId', true);
  }

  @override
  void dispose() {
    _business.removeListener(_refresh);
    _package.removeListener(_refresh);
    _pos.removeListener(_refresh);
    _users.removeListener(_refresh);
    super.dispose();
  }
}
