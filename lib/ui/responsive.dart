import 'package:flutter/material.dart';

/// Shared breakpoints and helpers for small phones through tablets.
class AppBreakpoints {
  AppBreakpoints._();

  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static EdgeInsets safePadding(BuildContext context) =>
      MediaQuery.paddingOf(context);

  /// Top dashboard: overflow risk — collapse icon row into a menu.
  static bool useCompactDashboardActions(BuildContext context) =>
      width(context) < 520;

  /// Course grid: 1 column on very narrow devices, 2 on phones, 3 on tablets.
  static int courseGridColumns(BuildContext context) {
    final w = width(context);
    if (w < 340) return 1;
    if (w < 720) return 2;
    return 3;
  }

  static double courseGridChildAspectRatio(BuildContext context, int cols) {
    final h = height(context);
    if (cols == 1) {
      if (h < 640) return 1.35;
      return 1.2;
    }
    if (cols == 2) {
      if (h < 640) return 0.88;
      return 0.78;
    }
    return 0.92;
  }

  static double sessionRadarHeight(BuildContext context, {double max = 260}) {
    final h = height(context);
    final scale = (h / 800).clamp(0.72, 1.0);
    return (max * scale).clamp(180.0, max);
  }

  static double horizontalPadding(BuildContext context) {
    final w = width(context);
    if (w < 360) return 14;
    if (w < 600) return 18;
    return 24;
  }
}
