import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Centralized breakpoints and helpers for responsive layouts.
///
/// We keep the logic here so all admin pages can use the same rules:
/// - Mobile: < 600
/// - Tablet: 600–1024
/// - Desktop: > 1024
class ResponsiveBreakpoints {
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  static bool isMobile(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < mobileMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMaxWidth && width <= tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width > tabletMaxWidth;
  }

  static bool isDesktopWidth(double width) => width > tabletMaxWidth;

  /// Convenience: true when running in a browser on a wide screen.
  static bool isWebDesktop(BuildContext context) {
    return kIsWeb && isDesktop(context);
  }
}


