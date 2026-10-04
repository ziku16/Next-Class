import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// NextClass Typography System based on Manrope with tabular figures.
class NextClassTypography {
  NextClassTypography._();

  static TextStyle _style({
    required double fontSize,
    required double lineHeight,
    required FontWeight fontWeight,
    required double letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Builds a complete TextTheme populated with the exact NextClass typography scale.
  static TextTheme buildTextTheme(Color defaultTextColor) {
    return TextTheme(
      displaySmall: _style(
        fontSize: 36,
        lineHeight: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: defaultTextColor,
      ),
      headlineMedium: _style(
        fontSize: 28,
        lineHeight: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        color: defaultTextColor,
      ),
      headlineSmall: _style(
        fontSize: 24,
        lineHeight: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
        color: defaultTextColor,
      ),
      titleLarge: _style(
        fontSize: 22,
        lineHeight: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
        color: defaultTextColor,
      ),
      titleMedium: _style(
        fontSize: 16,
        lineHeight: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: defaultTextColor,
      ),
      titleSmall: _style(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: defaultTextColor,
      ),
      bodyLarge: _style(
        fontSize: 16,
        lineHeight: 24,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: defaultTextColor,
      ),
      bodyMedium: _style(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: defaultTextColor,
      ),
      bodySmall: _style(
        fontSize: 12,
        lineHeight: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: defaultTextColor,
      ),
      labelLarge: _style(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: defaultTextColor,
      ),
      labelMedium: _style(
        fontSize: 12,
        lineHeight: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: defaultTextColor,
      ),
      labelSmall: _style(
        fontSize: 11,
        lineHeight: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: defaultTextColor,
      ),
    );
  }
}
