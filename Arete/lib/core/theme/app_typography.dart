import 'package:flutter/material.dart';

/// App typography definitions providing calm, intentional readability (Inter / Notion / Linear style).
class AppTypography {
  static const String fontFamily = 'Inter';
  static const List<String> fontFallbacks = ['Roboto', '-apple-system', 'sans-serif'];

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static const TextStyle timerLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 64,
    fontWeight: FontWeight.w300,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
