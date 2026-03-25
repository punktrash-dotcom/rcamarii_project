import 'package:flutter/widgets.dart';

class AppLayoutUtils {
  const AppLayoutUtils._();

  static double maxSafeTextScale(Size size) {
    final shortestSide = size.shortestSide;

    if (shortestSide < 360) {
      return 1.05;
    }
    if (shortestSide < 400) {
      return 1.1;
    }
    if (shortestSide < 600) {
      return 1.15;
    }
    if (shortestSide < 900) {
      return 1.25;
    }
    return 1.35;
  }

  static TextScaler clampedTextScaler(MediaQueryData mediaQuery) {
    final currentScale = mediaQuery.textScaler.scale(1);
    final maxScale = maxSafeTextScale(mediaQuery.size);

    if (currentScale <= maxScale) {
      return mediaQuery.textScaler;
    }

    return TextScaler.linear(maxScale);
  }

  static bool shouldStackHeader(
    BuildContext context, {
    double widthBreakpoint = 520,
    double scaleBreakpoint = 1.12,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveScale = mediaQuery.textScaler.scale(1);
    return mediaQuery.size.width < widthBreakpoint ||
        effectiveScale > scaleBreakpoint;
  }
}
