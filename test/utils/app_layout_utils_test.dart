import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/utils/app_layout_utils.dart';

void main() {
  test('clampedTextScaler caps oversized text scaling on compact layouts', () {
    const mediaQuery = MediaQueryData(
      size: Size(375, 812),
      textScaler: TextScaler.linear(2),
    );

    final clamped = AppLayoutUtils.clampedTextScaler(mediaQuery);

    expect(clamped.scale(1), 1.1);
  });

  test('clampedTextScaler preserves smaller accessible text scales', () {
    const mediaQuery = MediaQueryData(
      size: Size(375, 812),
      textScaler: TextScaler.linear(1.05),
    );

    final clamped = AppLayoutUtils.clampedTextScaler(mediaQuery);

    expect(clamped.scale(1), 1.05);
  });
}
