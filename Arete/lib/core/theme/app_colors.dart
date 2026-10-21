import 'package:flutter/material.dart';

/// Material You (Material 3) expressive dynamic color palettes for Areté.
/// Zero AI-slop gradients: curated tonal ceramic, olive, coral, and sage tones.
class AppColors {
  // --- Sage & Coral (Default Material You) ---
  static const Color sageBgLight = Color(0xFFFBFBF6);
  static const Color sagePrimary = Color(0xFF2A4E35); // Natural Olive & Forest
  static const Color sagePrimaryContainer = Color(0xFFD2E8D4); // Light Mint/Sage
  static const Color sageOnPrimaryContainer = Color(0xFF1B3623); // Deep Forest

  static const Color coralSecondary = Color(0xFFFFDDB3); // Pastel Warm Amber
  static const Color coralSecondaryContainer = Color(0xFFFDE8E1); // Soft Coral
  static const Color coralOnSecondary = Color(0xFF5A2D00); // Deep Warm Amber

  static const Color lavenderTertiary = Color(0xFFE8DEF8); // Soft Lavender
  static const Color lavenderOnTertiary = Color(0xFF382A4C); // Deep Plum
  static const Color vividCoralAccent = Color(0xFFFF7A59); // Active Vivid Peach/Coral

  // Surface & Neutrals for Sage & Coral
  static const Color sageSurfaceLight = Color(0xFFF4F3ED);
  static const Color sageSurfaceVariantLight = Color(0xFFECEAE2);
  static const Color sageOutlineLight = Color(0xFFE0DDD5);
  static const Color sageTextDark = Color(0xFF191C19);
  static const Color sageTextMuted = Color(0xFF5A645D);

  // Dark Neutrals for Sage & Coral
  static const Color sageBgDark = Color(0xFF131614);
  static const Color sageSurfaceDark = Color(0xFF1C201D);
  static const Color sageSurfaceVariantDark = Color(0xFF262C27);
  static const Color sageOutlineDark = Color(0xFF3B433C);
  static const Color sageTextLight = Color(0xFFE2E4DE);
  static const Color sageTextMutedDark = Color(0xFF8B948C);

  // --- Ocean & Sunrise Palette ---
  static const Color oceanBgLight = Color(0xFFF8FAFC);
  static const Color oceanPrimary = Color(0xFF1E3A8A);
  static const Color oceanPrimaryContainer = Color(0xFFCFFAFE);
  static const Color oceanOnPrimaryContainer = Color(0xFF0F172A);
  static const Color sunriseSecondary = Color(0xFFFED7AA);
  static const Color sunriseSecondaryContainer = Color(0xFFFFEDD5);
  static const Color sunriseAccent = Color(0xFFF97316);

  // --- Berry Lavender Palette ---
  static const Color berryBgLight = Color(0xFFFAF7F9);
  static const Color berryPrimary = Color(0xFF5B21B6);
  static const Color berryPrimaryContainer = Color(0xFFF3E8FF);
  static const Color berryOnPrimaryContainer = Color(0xFF2E1065);
  static const Color berrySecondary = Color(0xFFFFE4E6);
  static const Color berrySecondaryContainer = Color(0xFFFFF1F2);
  static const Color berryAccent = Color(0xFFF43F5E);

  // --- Cyber Lime Palette ---
  static const Color cyberBgLight = Color(0xFFF8F9F5);
  static const Color cyberPrimary = Color(0xFF064E3B);
  static const Color cyberPrimaryContainer = Color(0xFFD1FAE5);
  static const Color cyberOnPrimaryContainer = Color(0xFF022C22);
  static const Color cyberSecondary = Color(0xFFFEF3C7);
  static const Color cyberSecondaryContainer = Color(0xFFFFFBEB);
  static const Color cyberAccent = Color(0xFF84CC16);

  // --- Pastel Habit Card Palette ---
  static const List<Color> habitPastels = [
    Color(0xFFFFDDB3), // Warm Pastel Amber
    Color(0xFFFDE8E1), // Soft Peach / Coral
    Color(0xFFD2E8D4), // Soft Sage Mint
    Color(0xFFE8DEF8), // Lavender
    Color(0xFFCFFAFE), // Soft Sky Cyan
    Color(0xFFFEF3C7), // Morning Butter
  ];

  // Functional Status
  static const Color errorRed = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color successGreen = Color(0xFF2A4E35);

  // Preserved backwards-compatibility getters
  static const Color lightBackground = sageBgLight;
  static const Color lightSurface = sageSurfaceLight;
  static const Color lightSurfaceVariant = sageSurfaceVariantLight;
  static const Color lightPrimaryText = sageTextDark;
  static const Color lightSecondaryText = sageTextMuted;
  static const Color lightPrimaryAccent = sagePrimary;
  static const Color lightAccentHover = Color(0xFF1F3C28);
  static const Color lightAccentLight = sagePrimaryContainer;
  static const Color lightBorder = sageOutlineLight;
  static const Color lightDivider = Color(0xFFE7E5DC);

  static const Color darkBackground = sageBgDark;
  static const Color darkSurface = sageSurfaceDark;
  static const Color darkSurfaceVariant = sageSurfaceVariantDark;
  static const Color darkPrimaryText = sageTextLight;
  static const Color darkSecondaryText = sageTextMutedDark;
  static const Color darkPrimaryAccent = Color(0xFF8CD49E);
  static const Color darkAccentHover = Color(0xFFA5E6B4);
  static const Color darkAccentLight = Color(0xFF1E3825);
  static const Color darkBorder = sageOutlineDark;
  static const Color darkDivider = Color(0xFF2E352F);

  static const Color dangerMuted = errorRed;
  static const Color dangerMutedLight = errorContainer;
  static const Color dangerMutedDark = Color(0xFF410002);
  static const Color amberMuted = Color(0xFFD97706);
  static const Color amberMutedLight = Color(0xFFFEF3C7);
  static const Color amberMutedDark = Color(0xFF78350F);
  static const Color blueMuted = Color(0xFF2563EB);
  static const Color blueMutedLight = Color(0xFFDBEAFE);
  static const Color blueMutedDark = Color(0xFF1E3A8A);
  static const Color purpleMuted = Color(0xFF7C3AED);
  static const Color purpleMutedLight = Color(0xFFEDE9FE);
  static const Color purpleMutedDark = Color(0xFF4C1D95);

  static const List<Color> categoryPalette = habitPastels;
}
