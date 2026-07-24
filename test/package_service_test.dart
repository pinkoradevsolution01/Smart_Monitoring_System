import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_monitoring_system/models/pricing_package.dart';
import 'package:smart_monitoring_system/services/package_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('unlimited packages allow adding the first product', () async {
    final service = PackageService();
    await service.selectPackage(
      PricingPackage.packages.firstWhere((p) => p.type == PackageType.premium),
    );

    expect(service.isProductLimitReached(0), isFalse);
    expect(service.isProductLimitReached(100000), isFalse);
  });

  test('finite package limit is enforced at the boundary', () async {
    final service = PackageService();
    await service.selectPackage(
      PricingPackage.packages.firstWhere((p) => p.type == PackageType.basic),
    );

    expect(service.isProductLimitReached(99), isFalse);
    expect(service.isProductLimitReached(100), isTrue);
  });
}
