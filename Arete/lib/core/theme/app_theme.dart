import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme => getTheme(palette: 'sage_coral', isDark: false);
  static ThemeData get darkTheme => getTheme(palette: 'sage_coral', isDark: true);

  static ThemeData getTheme({String palette = 'sage_coral', bool isDark = false}) {
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    // Dynamic Material 3 Palette Resolution
    final Color bg;
    final Color surface;
    final Color surfaceContainer;
    final Color surfaceContainerHighest;
    final Color primary;
    final Color primaryContainer;
    final Color onPrimary;
    final Color onPrimaryContainer;
    final Color secondary;
    final Color secondaryContainer;
    final Color onSecondary;
    final Color tertiary;
    final Color onTertiary;
    final Color outline;
    final Color onSurface;
    final Color textMuted;

    if (!isDark) {
      switch (palette) {
        case 'ocean_sunrise':
          bg = AppColors.oceanBgLight;
          surface = const Color(0xFFF1F5F9);
          surfaceContainer = const Color(0xFFF8FAFC);
          surfaceContainerHighest = const Color(0xFFE2E8F0);
          primary = AppColors.oceanPrimary;
          primaryContainer = AppColors.oceanPrimaryContainer;
          onPrimary = Colors.white;
          onPrimaryContainer = AppColors.oceanOnPrimaryContainer;
          secondary = AppColors.sunriseSecondary;
          secondaryContainer = AppColors.sunriseSecondaryContainer;
          onSecondary = const Color(0xFF7C2D12);
          tertiary = const Color(0xFFE0F2FE);
          onTertiary = const Color(0xFF082F49);
          outline = const Color(0xFFCBD5E1);
          onSurface = const Color(0xFF0F172A);
          textMuted = const Color(0xFF64748B);
          break;
        case 'berry_lavender':
          bg = AppColors.berryBgLight;
          surface = const Color(0xFFF7F2F6);
          surfaceContainer = const Color(0xFFFAF7F9);
          surfaceContainerHighest = const Color(0xFFEFE8EE);
          primary = AppColors.berryPrimary;
          primaryContainer = AppColors.berryPrimaryContainer;
          onPrimary = Colors.white;
          onPrimaryContainer = AppColors.berryOnPrimaryContainer;
          secondary = AppColors.berrySecondary;
          secondaryContainer = AppColors.berrySecondaryContainer;
          onSecondary = const Color(0xFF881337);
          tertiary = const Color(0xFFEDE9FE);
          onTertiary = const Color(0xFF3B0764);
          outline = const Color(0xFFE2D9E2);
          onSurface = const Color(0xFF211526);
          textMuted = const Color(0xFF756877);
          break;
        case 'cyber_lime':
          bg = AppColors.cyberBgLight;
          surface = const Color(0xFFF2F5EF);
          surfaceContainer = const Color(0xFFF8F9F5);
          surfaceContainerHighest = const Color(0xFFE6EBE2);
          primary = AppColors.cyberPrimary;
          primaryContainer = AppColors.cyberPrimaryContainer;
          onPrimary = Colors.white;
          onPrimaryContainer = AppColors.cyberOnPrimaryContainer;
          secondary = AppColors.cyberSecondary;
          secondaryContainer = AppColors.cyberSecondaryContainer;
          onSecondary = const Color(0xFF78350F);
          tertiary = const Color(0xFFE6F4EA);
          onTertiary = const Color(0xFF14532D);
          outline = const Color(0xFFD7DDD3);
          onSurface = const Color(0xFF151D18);
          textMuted = const Color(0xFF5F6862);
          break;
        case 'sage_coral':
        default:
          bg = AppColors.sageBgLight;
          surface = AppColors.sageSurfaceLight;
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = AppColors.sageSurfaceVariantLight;
          primary = AppColors.sagePrimary;
          primaryContainer = AppColors.sagePrimaryContainer;
          onPrimary = Colors.white;
          onPrimaryContainer = AppColors.sageOnPrimaryContainer;
          secondary = AppColors.coralSecondary;
          secondaryContainer = AppColors.coralSecondaryContainer;
          onSecondary = AppColors.coralOnSecondary;
          tertiary = AppColors.lavenderTertiary;
          onTertiary = AppColors.lavenderOnTertiary;
          outline = AppColors.sageOutlineLight;
          onSurface = AppColors.sageTextDark;
          textMuted = AppColors.sageTextMuted;
          break;
      }
    } else {
      // Dark Mode
      bg = const Color(0xFF131614);
      surface = const Color(0xFF1C201D);
      surfaceContainer = const Color(0xFF222823);
      surfaceContainerHighest = const Color(0xFF2C342E);
      primary = const Color(0xFF8CD49E);
      primaryContainer = const Color(0xFF24452E);
      onPrimary = const Color(0xFF0F291E);
      onPrimaryContainer = const Color(0xFFE2F1E4);
      secondary = const Color(0xFFFFDDB3);
      secondaryContainer = const Color(0xFF472808);
      onSecondary = const Color(0xFF241400);
      tertiary = const Color(0xFFD0BCFF);
      onTertiary = const Color(0xFF381E72);
      outline = const Color(0xFF3E4840);
      onSurface = const Color(0xFFE2E4DE);
      textMuted = const Color(0xFF8B948C);
    }

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondary,
      tertiary: tertiary,
      onTertiary: onTertiary,
      error: AppColors.dangerMuted,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: bg,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHighest,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceBright: surface,
      surfaceDim: bg,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.6),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline.withValues(alpha: 0.7), width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: onPrimaryContainer,
        unselectedItemColor: textMuted,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.dangerMuted, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.dangerMuted, width: 1.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: outline, width: 1),
        ),
        titleTextStyle: AppTypography.heading2.copyWith(color: onSurface),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surfaceContainer),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: outline, width: 1),
            ),
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.display.copyWith(color: onSurface),
        headlineLarge: AppTypography.heading1.copyWith(color: onSurface),
        headlineMedium: AppTypography.heading2.copyWith(color: onSurface),
        headlineSmall: AppTypography.heading3.copyWith(color: onSurface),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: onSurface),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: onSurface),
        bodySmall: AppTypography.bodySmall.copyWith(color: textMuted),
        labelLarge: AppTypography.label.copyWith(color: onSurface),
        labelMedium: AppTypography.label.copyWith(color: textMuted),
      ),
    );
  }
}
