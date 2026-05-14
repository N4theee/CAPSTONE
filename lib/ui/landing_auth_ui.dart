import 'package:flutter/material.dart';

/// Visual tokens for welcome + auth flows (navy, teal, purple).
class LandingAuthUi {
  LandingAuthUi._();

  static const Color background = Color(0xFF060A14);
  static const Color backgroundMid = Color(0xFF0C1224);
  static const Color surface = Color(0xFF121A2E);
  static const Color surfaceMuted = Color(0xFF1A2540);
  static const Color borderSubtle = Color(0xFF2A3550);
  static const Color teal = Color(0xFF14B8A6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const LinearGradient primaryCta = LinearGradient(
    colors: [teal, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient teacherBorder = LinearGradient(
    colors: [purple, Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient studentBorder = LinearGradient(
    colors: [teal, Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient segmentSelected = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData authThemeOverlay(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        surface: surface,
        primary: teal,
        onPrimary: Colors.white,
        secondary: purple,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.65)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: teal.withValues(alpha: 0.85), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return teal;
          }
          return surfaceMuted;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: borderSubtle, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
