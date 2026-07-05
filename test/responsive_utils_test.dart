import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/utils/responsive_utils.dart';

void main() {
  group('ResponsiveUtils', () {
    test('uses a single column on narrow screens', () {
      expect(ResponsiveUtils.columnsForWidth(360), 1);
      expect(ResponsiveUtils.columnsForWidth(480), 1);
    });

    test('uses two columns on tablet width', () {
      expect(ResponsiveUtils.columnsForWidth(700), 2);
    });

    test('uses more columns on wide screens', () {
      expect(ResponsiveUtils.columnsForWidth(1100), 4);
    });

    test('scales spacing based on width', () {
      expect(ResponsiveUtils.spacingForWidth(320), 16.0);
      expect(ResponsiveUtils.spacingForWidth(760), 20.0);
      expect(ResponsiveUtils.spacingForWidth(1200), 24.0);
    });
  });
}
