import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 900;
  static const double desktopContentMaxWidth = 1200;

  static bool isMobile(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < mobileMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMaxWidth && width < tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletMaxWidth;
  }

  static int columnsForWidth(double width) {
    if (width >= 1100) return 4;
    if (width >= 760) return 3;
    if (width >= 520) return 2;
    return 1;
  }

  static double spacingForWidth(double width) {
    if (width >= 1000) return 24;
    if (width >= 700) return 20;
    return 16;
  }

  static EdgeInsets responsivePadding(double width) {
    if (width >= 1200) return const EdgeInsets.all(32);
    if (width >= 900) return const EdgeInsets.all(24);
    if (width >= 600) return const EdgeInsets.all(20);
    return const EdgeInsets.all(12);
  }

  static double contentWidth(double width) =>
      width > desktopContentMaxWidth ? desktopContentMaxWidth : width;

  static double dialogWidth(double width, {double max = 520}) {
    final horizontalInset = width < mobileMaxWidth ? 24 : 48;
    return (width - horizontalInset).clamp(280.0, max).toDouble();
  }
}
