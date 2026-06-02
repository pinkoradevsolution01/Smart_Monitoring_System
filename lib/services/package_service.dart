import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pricing_package.dart';

class PackageService extends ChangeNotifier {
  static const String _packageKey = 'selected_package';
  static const String _setupCompleteKey = 'setup_complete';

  PricingPackage? _selectedPackage;
  bool _setupComplete = false;

  PricingPackage? get selectedPackage => _selectedPackage;
  bool get setupComplete => _setupComplete;
  bool get hasPackage => _selectedPackage != null;

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

    notifyListeners();
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
