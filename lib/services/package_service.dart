import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pricing_package.dart';
import 'backend_api_service.dart';
import 'backend_config.dart';

class PackageService extends ChangeNotifier {
  static const String _packageKey = 'selected_package';
  static const String _setupCompleteKey = 'setup_complete';
  static const String _activationStatusKey = 'activation_status';
  static const String _activationCodeKey = 'activation_code';
  static const String _activatedPackageNameKey = 'activated_package_name';

  PricingPackage? _selectedPackage;
  bool _setupComplete = false;
  PricingPackage? _packageBeforeDemo;
  bool _demoPackageActive = false;
  final ApiClient _api = ApiClient();

  PricingPackage? get selectedPackage => _selectedPackage;
  bool get setupComplete => _setupComplete;
  bool get hasPackage => _selectedPackage != null;

  /// Temporarily expose a package for demonstrations without changing local
  /// preferences or syncing the package to the backend.
  void enterDemoPackage(PricingPackage package) {
    if (!_demoPackageActive) {
      _packageBeforeDemo = _selectedPackage;
      _demoPackageActive = true;
    }
    _selectedPackage = package;
    notifyListeners();
  }

  /// Restore the package that was active before Demo Access was opened.
  void exitDemoPackage() {
    if (!_demoPackageActive) return;
    _selectedPackage = _packageBeforeDemo;
    _packageBeforeDemo = null;
    _demoPackageActive = false;
    notifyListeners();
  }

  // Feature checks
  bool get hasCCTVAccess => _selectedPackage?.hasCCTV ?? false;
  bool get hasCloudSyncAccess => _selectedPackage?.hasCloudSync ?? false;
  bool get hasSupplierManagementAccess =>
      _selectedPackage?.hasSupplierManagement ?? false;
  bool get hasEWalletAccess => _selectedPackage?.hasEWallet ?? false;
  bool get hasAdvancedAnalyticsAccess =>
      _selectedPackage?.hasAdvancedAnalytics ?? false;
  bool get hasPrioritySupportAccess =>
      _selectedPackage?.hasPrioritySupport ?? false;

  bool get hasAIHelpAccess => _selectedPackage?.hasAIHelp ?? false;

  // Attendance feature: available for Standard and above
  bool get hasAttendanceAccess {
    if (_selectedPackage == null) return false;
    return _selectedPackage!.type != PackageType.basic;
  }

  // Payroll feature: available for Standard and above (Basic package locked)
  bool get hasPayrollAccess {
    if (_selectedPackage == null) return false;
    return _selectedPackage!.type != PackageType.basic;
  }

  // Backup & Restore: treat Basic the same as Standard for backup/restore access
  bool get hasBackupRestoreAccess {
    if (_selectedPackage == null) return false;
    // Enforce Basic to have backup/restore same as Standard and above
    return true; // all selected packages (including Basic) get backup/restore
  }

  int get maxUsers => _selectedPackage?.maxUsers ?? 1;
  int get maxProducts => _selectedPackage?.maxProducts ?? 100;

  /// Returns whether another product may be added to the selected package.
  /// A negative product limit represents an unlimited package.
  bool isProductLimitReached(int currentProductCount) {
    final limit = _selectedPackage?.maxProducts;
    return limit != null && limit >= 0 && currentProductCount >= limit;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _setupComplete = prefs.getBool(_setupCompleteKey) ?? false;

    if (_setupComplete) {
      final packageData = prefs.getString(_packageKey);
      if (packageData != null) {
        try {
          final map = <String, dynamic>{};
          // Simple key=value parsing
          packageData.split('|').forEach((pair) {
            final parts = pair.split('=');
            if (parts.length == 2) {
              map[parts[0]] = parts[1];
            }
          });
          _selectedPackage = PricingPackage.fromMap(map);
        } catch (e) {
          debugPrint('Error loading package: $e');
          // If package fails to load, reset setup
          _setupComplete = false;
        }
      } else {
        // If no package data exists but setup was marked complete, reset
        debugPrint('No package data found, resetting setup');
        _setupComplete = false;
      }
    }

    // Recovery path: if package prefs were cleared but license is still activated,
    // rebuild package selection from stored activation details/backend.
    if (!_setupComplete || _selectedPackage == null) {
      await _recoverPackageFromActivation(prefs);
    }

    notifyListeners();
  }

  Future<void> _recoverPackageFromActivation(SharedPreferences prefs) async {
    final savedPackageName = prefs.getString(_activatedPackageNameKey);
    final savedPackage = _findPackageByName(savedPackageName);
    if (savedPackage != null) {
      await _persistRecoveredPackage(savedPackage, prefs);
      debugPrint(
        '✅ PackageService: recovered package from local activation info (${savedPackage.name})',
      );
      return;
    }

    final isActivated = prefs.getBool(_activationStatusKey) ?? false;
    if (!isActivated) return;

    final activationCode = prefs.getString(_activationCodeKey);
    if (activationCode != null &&
        activationCode.isNotEmpty &&
        BackendConfig.useRestBackend) {
      try {
        final response = await _api.getJson('license/code/$activationCode');
        String? packageName;

        if (response is Map<String, dynamic>) {
          packageName = response['package_name'] as String?;
          if (packageName == null && response['code'] is Map) {
            packageName =
                (response['code'] as Map<String, dynamic>)['package_name']
                    as String?;
          }
        }

        final recovered = _findPackageByName(packageName);
        if (recovered != null) {
          await _persistRecoveredPackage(recovered, prefs);
          debugPrint(
            '✅ PackageService: recovered package from backend (${recovered.name})',
          );
          return;
        }
      } catch (e) {
        debugPrint('⚠️ PackageService: backend package recovery failed: $e');
      }
    }

    // Final fallback for legacy activated installs where package metadata is missing.
    final fallback =
        _findPackageByName('Standard') ?? PricingPackage.packages.first;
    await _persistRecoveredPackage(fallback, prefs);
    debugPrint(
      '⚠️ PackageService: using fallback package recovery (${fallback.name})',
    );
  }

  Future<void> _persistRecoveredPackage(
    PricingPackage package,
    SharedPreferences prefs,
  ) async {
    _selectedPackage = package;
    _setupComplete = true;
    await prefs.setBool(_setupCompleteKey, true);
    await prefs.setString(_activatedPackageNameKey, package.name);
    await prefs.setString(
      _packageKey,
      'type=${package.type}|name=${package.name}',
    );
  }

  PricingPackage? _findPackageByName(String? packageName) {
    if (packageName == null || packageName.trim().isEmpty) return null;
    final normalized = packageName.trim().toLowerCase();
    for (final pkg in PricingPackage.packages) {
      if (pkg.name.toLowerCase() == normalized) {
        return pkg;
      }
    }
    return null;
  }

  Future<void> selectPackage(PricingPackage package) async {
    _selectedPackage = package;
    _setupComplete = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);

    // Save package data as simple string
    final packageData = 'type=${package.type}|name=${package.name}';
    await prefs.setString(_packageKey, packageData);

    notifyListeners();
  }

  Future<void> updatePackage(PricingPackage package) async {
    // Update package without resetting setup or deleting data
    _selectedPackage = package;

    final prefs = await SharedPreferences.getInstance();
    final packageData = 'type=${package.type}|name=${package.name}';
    await prefs.setString(_packageKey, packageData);

    notifyListeners();

    debugPrint('✅ Package updated to: ${package.name}');
  }

  Future<void> resetSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_packageKey);
    await prefs.remove(_setupCompleteKey);
    _selectedPackage = null;
    _setupComplete = false;
    notifyListeners();
  }

  bool canAccessFeature(String feature) {
    if (_selectedPackage == null) return false;

    switch (feature.toLowerCase()) {
      case 'backup':
      case 'restore':
        return hasBackupRestoreAccess;
      case 'cctv':
        return _selectedPackage!.hasCCTV;
      case 'cloud_sync':
        return _selectedPackage!.hasCloudSync;
      case 'supplier_management':
        return _selectedPackage!.hasSupplierManagement;
      case 'ewallet':
        return _selectedPackage!.hasEWallet;
      case 'ai_help':
        return _selectedPackage!.hasAIHelp;
      case 'advanced_analytics':
        return _selectedPackage!.hasAdvancedAnalytics;
      case 'multi_device':
        return _selectedPackage!.hasMultiDevice;
      default:
        return true; // Basic features are available to all
    }
  }
}
