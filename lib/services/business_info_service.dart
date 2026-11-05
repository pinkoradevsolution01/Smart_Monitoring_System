import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_info.dart';

class BusinessInfoService extends ChangeNotifier {
  static const String _businessConfiguredKey = 'business_setup_complete';
  static final BusinessInfoService _instance = BusinessInfoService._internal();
  factory BusinessInfoService() => _instance;
  BusinessInfoService._internal();

  BusinessInfo? _businessInfo;
  bool _isConfigured = false;

  BusinessInfo? get businessInfo => _businessInfo;
  bool get isConfigured => _isConfigured;

  // Default business info
  static final BusinessInfo _defaultInfo = BusinessInfo(
    storeName: 'Smart Store',
    businessType: 'Retail',
    storeAddress: null,
    logoPath: null,
  );

  Future<void> initialize() async {
    await loadBusinessInfo();
  }

  Future<void> loadBusinessInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeName = prefs.getString('business_store_name');
      final businessType = prefs.getString('business_business_type');
      final storeAddress = prefs.getString('business_store_address');
      final logoPath = prefs.getString('business_logo_path');
      _isConfigured = prefs.getBool(_businessConfiguredKey) ?? false;

      if (storeName != null && businessType != null) {
        _businessInfo = BusinessInfo(
          storeName: storeName,
          businessType: businessType,
          storeAddress: storeAddress,
          logoPath: logoPath,
        );
      } else {
        _businessInfo = _defaultInfo;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading business info: $e');
      _businessInfo = _defaultInfo;
      _isConfigured = false;
      notifyListeners();
    }
  }

  Future<bool> saveBusinessInfo(BusinessInfo info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('business_store_name', info.storeName);
      // Keep the owner-setup key aligned for flows created before the guided
      // business registration screen, including activation-code requests.
      await prefs.setString('business_name', info.storeName);
      await prefs.setString('business_business_type', info.businessType);
      await prefs.setBool(_businessConfiguredKey, true);
      if (info.storeAddress != null) {
        await prefs.setString('business_store_address', info.storeAddress!);
      } else {
        await prefs.remove('business_store_address');
      }
      if (info.logoPath != null) {
        await prefs.setString('business_logo_path', info.logoPath!);
      } else {
        await prefs.remove('business_logo_path');
      }

      _businessInfo = info;
      _isConfigured = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving business info: $e');
      return false;
    }
  }

  /// Restores the minimum business-profile state for an owner whose existing
  /// tenant was verified by the backend after a reinstall. Existing device
  /// details always win; this only fills missing local preferences and never
  /// creates or changes a backend business.
  Future<bool> restoreFromVerifiedBackendBusiness({
    required String storeName,
    String? storeAddress,
  }) async {
    final normalizedName = storeName.trim();
    if (normalizedName.isEmpty) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localName = prefs.getString('business_store_name')?.trim();
      final localType = prefs.getString('business_business_type')?.trim();
      final localAddress = prefs.getString('business_store_address')?.trim();
      final localLogo = prefs.getString('business_logo_path');

      return saveBusinessInfo(
        BusinessInfo(
          storeName: localName?.isNotEmpty == true
              ? localName!
              : normalizedName,
          // Older releases stored this only on the device. Preserve it where
          // available; otherwise use an editable neutral value instead of
          // forcing the owner through first-time onboarding again.
          businessType: localType?.isNotEmpty == true ? localType! : 'Other',
          storeAddress: localAddress?.isNotEmpty == true
              ? localAddress
              : storeAddress?.trim().isNotEmpty == true
              ? storeAddress!.trim()
              : null,
          logoPath: localLogo,
        ),
      );
    } catch (e) {
      debugPrint('Error restoring verified business info: $e');
      return false;
    }
  }

  Future<void> clearBusinessInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('business_store_name');
      await prefs.remove('business_business_type');
      await prefs.remove('business_store_address');
      await prefs.remove('business_logo_path');
      await prefs.remove(_businessConfiguredKey);

      _businessInfo = _defaultInfo;
      _isConfigured = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing business info: $e');
    }
  }
}
