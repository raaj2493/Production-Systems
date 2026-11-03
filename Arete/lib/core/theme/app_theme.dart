import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme => getTheme(palette: 'sage_coral', isDark: false);
  static ThemeData get darkTheme => getTheme(palette: 'sage_coral', isDark: true);

  static ThemeData getTheme({String palette = 'sage_coral', bool isDark = false}) {
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    // Map backwards-compatible names
    String resolvedPalette = palette;
    if (palette == 'ocean_sunrise') resolvedPalette = 'nordic_frost';
    if (palette == 'berry_lavender') resolvedPalette = 'candy_pop';
    if (palette == 'cyber_lime') resolvedPalette = 'cyberpunk_neon';
    if (palette == 'royal_amethyst') resolvedPalette = 'candy_pop';

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
      switch (resolvedPalette) {
        case 'obsidian_minimal':
          bg = AppColors.obsidianBgLight;
          surface = AppColors.obsidianSurfaceLight;
          surfaceContainer = const Color(0xFFEFEFEF);
          surfaceContainerHighest = AppColors.obsidianPrimaryContainerLight;
          primary = AppColors.obsidianPrimaryLight;
          primaryContainer = AppColors.obsidianPrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = const Color(0xFF18181B);
          secondary = const Color(0xFF52525B);
          secondaryContainer = const Color(0xFFE4E4E7);
          onSecondary = Colors.white;
          tertiary = const Color(0xFF71717A);
          onTertiary = Colors.white;
          outline = const Color(0xFFD4D4D8);
          onSurface = const Color(0xFF18181B);
          textMuted = const Color(0xFF71717A);
          break;

        case 'candy_pop':
          bg = AppColors.candyBgLight;
          surface = const Color(0xFFF7F2F3);
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = const Color(0xFFEFE6E8);
          primary = AppColors.candyPrimaryLight;
          primaryContainer = AppColors.candyPrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = const Color(0xFF38151D);
          secondary = AppColors.candySecondaryLight;
          secondaryContainer = AppColors.candySecondaryContainerLight;
          onSecondary = Colors.white;
          tertiary = AppColors.candyTertiaryLight;
          onTertiary = Colors.white;
          outline = const Color(0xFFE4D2D6);
          onSurface = const Color(0xFF26171B);
          textMuted = const Color(0xFF6B535A);
          break;

        case 'retro_synthwave':
          bg = AppColors.synthBgLight;
          surface = const Color(0xFFF1EFF8);
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = const Color(0xFFE7E3F1);
          primary = AppColors.synthPrimaryLight;
          primaryContainer = AppColors.synthPrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = const Color(0xFF221C3D);
          secondary = AppColors.synthSecondaryLight;
          secondaryContainer = AppColors.synthSecondaryContainerLight;
          onSecondary = Colors.white;
          tertiary = const Color(0xFF6B5876);
          onTertiary = Colors.white;
          outline = const Color(0xFFD6D1E8);
          onSurface = const Color(0xFF1E1A2D);
          textMuted = const Color(0xFF60597A);
          break;

        case 'sakura_blossom':
          bg = AppColors.sakuraBgLight;
          surface = const Color(0xFFF8F0F3);
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = const Color(0xFFEFE5E9);
          primary = AppColors.sakuraPrimaryLight;
          primaryContainer = AppColors.sakuraPrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = const Color(0xFF3D131F);
          secondary = AppColors.sakuraSecondaryLight;
          secondaryContainer = AppColors.sakuraSecondaryContainerLight;
          onSecondary = Colors.white;
          tertiary = const Color(0xFF825867);
          onTertiary = Colors.white;
          outline = const Color(0xFFE6D0D8);
          onSurface = const Color(0xFF25151B);
          textMuted = const Color(0xFF6E535C);
          break;

        case 'nordic_frost':
          bg = AppColors.nordicBgLight;
          surface = const Color(0xFFEDF3F5);
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = const Color(0xFFE0EAEF);
          primary = AppColors.nordicPrimaryLight;
          primaryContainer = AppColors.nordicPrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = const Color(0xFF112430);
          secondary = AppColors.nordicSecondaryLight;
          secondaryContainer = AppColors.nordicSecondaryContainerLight;
          onSecondary = Colors.white;
          tertiary = const Color(0xFF506B7B);
          onTertiary = Colors.white;
          outline = const Color(0xFFCBD8DF);
          onSurface = const Color(0xFF111E26);
          textMuted = const Color(0xFF506471);
          break;

        case 'sunset_terracotta':
          bg = AppColors.sunsetBgLight;
          surface = const Color(0xFFF3EFE8);
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = const Color(0xFFEAE2D8);
          primary = AppColors.sunsetPrimaryLight;
          primaryContainer = AppColors.sunsetPrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = const Color(0xFF411B10);
          secondary = AppColors.sunsetSecondaryLight;
          secondaryContainer = AppColors.sunsetSecondaryContainerLight;
          onSecondary = Colors.white;
          tertiary = const Color(0xFFA67153);
          onTertiary = Colors.white;
          outline = const Color(0xFFE2D6CB);
          onSurface = const Color(0xFF261914);
          textMuted = const Color(0xFF69544C);
          break;

        case 'cyberpunk_neon':
          bg = AppColors.cyberBgLight;
          surface = const Color(0xFFF2F5ED);
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = const Color(0xFFE3EADF);
          primary = AppColors.cyberPrimaryLight;
          primaryContainer = AppColors.cyberPrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = const Color(0xFF1A2B15);
          secondary = AppColors.cyberSecondaryLight;
          secondaryContainer = AppColors.cyberSecondaryContainerLight;
          onSecondary = Colors.white;
          tertiary = const Color(0xFF54704E);
          onTertiary = Colors.white;
          outline = const Color(0xFFD3DECF);
          onSurface = const Color(0xFF182215);
          textMuted = const Color(0xFF566752);
          break;

        case 'sage_coral':
        default:
          bg = AppColors.sageBgLight;
          surface = const Color(0xFFF4F3ED);
          surfaceContainer = const Color(0xFFFFFFFF);
          surfaceContainerHighest = const Color(0xFFECEAE2);
          primary = AppColors.sagePrimaryLight;
          primaryContainer = AppColors.sagePrimaryContainerLight;
          onPrimary = Colors.white;
          onPrimaryContainer = AppColors.sageOnPrimaryContainerLight;
          secondary = AppColors.coralSecondaryLight;
          secondaryContainer = AppColors.coralSecondaryContainerLight;
          onSecondary = AppColors.coralOnSecondaryLight;
          tertiary = AppColors.lavenderTertiaryLight;
          onTertiary = AppColors.lavenderOnTertiaryLight;
          outline = const Color(0xFFE0DDD5);
          onSurface = const Color(0xFF191C19);
          textMuted = const Color(0xFF5A645D);
          break;
      }
    } else {
      // Dark Mode (Tailored per palette, sleek, high-contrast, OLED-friendly!)
      switch (resolvedPalette) {
        case 'obsidian_minimal':
          bg = AppColors.obsidianBgDark;
          surface = AppColors.obsidianSurfaceDark;
          surfaceContainer = AppColors.obsidianSurfaceContainerDark;
          surfaceContainerHighest = AppColors.obsidianSurfaceVariantDark;
          primary = AppColors.obsidianPrimaryDark;
          primaryContainer = AppColors.obsidianPrimaryContainerDark;
          onPrimary = const Color(0xFF09090B);
          onPrimaryContainer = AppColors.obsidianOnPrimaryContainerDark;
          secondary = const Color(0xFFA1A1AA);
          secondaryContainer = const Color(0xFF27272A);
          onSecondary = const Color(0xFF09090B);
          tertiary = const Color(0xFF71717A);
          onTertiary = Colors.white;
          outline = AppColors.obsidianOutlineDark;
          onSurface = AppColors.obsidianTextLight;
          textMuted = AppColors.obsidianTextMutedDark;
          break;

        case 'candy_pop':
          bg = AppColors.candyBgDark;
          surface = AppColors.candySurfaceDark;
          surfaceContainer = AppColors.candySurfaceContainerDark;
          surfaceContainerHighest = AppColors.candySurfaceVariantDark;
          primary = AppColors.candyPrimaryDark;
          primaryContainer = AppColors.candyPrimaryContainerDark;
          onPrimary = const Color(0xFF38151D);
          onPrimaryContainer = AppColors.candyOnPrimaryContainerDark;
          secondary = const Color(0xFFC2A18A);
          secondaryContainer = const Color(0xFF4A3427);
          onSecondary = const Color(0xFF261810);
          tertiary = const Color(0xFFC4A8B3);
          onTertiary = const Color(0xFF38232B);
          outline = AppColors.candyOutlineDark;
          onSurface = AppColors.candyTextLight;
          textMuted = AppColors.candyTextMutedDark;
          break;

        case 'retro_synthwave':
          bg = AppColors.synthBgDark;
          surface = AppColors.synthSurfaceDark;
          surfaceContainer = AppColors.synthSurfaceContainerDark;
          surfaceContainerHighest = AppColors.synthSurfaceVariantDark;
          primary = AppColors.synthPrimaryDark;
          primaryContainer = AppColors.synthPrimaryContainerDark;
          onPrimary = const Color(0xFF1E173D);
          onPrimaryContainer = AppColors.synthOnPrimaryContainerDark;
          secondary = const Color(0xFF8FAEC4);
          secondaryContainer = const Color(0xFF233644);
          onSecondary = const Color(0xFF0E1C26);
          tertiary = const Color(0xFFB5A8C9);
          onTertiary = const Color(0xFF281F38);
          outline = AppColors.synthOutlineDark;
          onSurface = AppColors.synthTextLight;
          textMuted = AppColors.synthTextMutedDark;
          break;

        case 'sakura_blossom':
          bg = AppColors.sakuraBgDark;
          surface = AppColors.sakuraSurfaceDark;
          surfaceContainer = AppColors.sakuraSurfaceContainerDark;
          surfaceContainerHighest = AppColors.sakuraSurfaceVariantDark;
          primary = AppColors.sakuraPrimaryDark;
          primaryContainer = AppColors.sakuraPrimaryContainerDark;
          onPrimary = const Color(0xFF380E1A);
          onPrimaryContainer = AppColors.sakuraOnPrimaryContainerDark;
          secondary = const Color(0xFF8FA88B);
          secondaryContainer = const Color(0xFF253324);
          onSecondary = const Color(0xFF121C11);
          tertiary = const Color(0xFFD4A5B3);
          onTertiary = const Color(0xFF381F26);
          outline = AppColors.sakuraOutlineDark;
          onSurface = AppColors.sakuraTextLight;
          textMuted = AppColors.sakuraTextMutedDark;
          break;

        case 'nordic_frost':
          bg = AppColors.nordicBgDark;
          surface = AppColors.nordicSurfaceDark;
          surfaceContainer = AppColors.nordicSurfaceContainerDark;
          surfaceContainerHighest = AppColors.nordicSurfaceVariantDark;
          primary = AppColors.nordicPrimaryDark;
          primaryContainer = AppColors.nordicPrimaryContainerDark;
          onPrimary = const Color(0xFF0E2330);
          onPrimaryContainer = AppColors.nordicOnPrimaryContainerDark;
          secondary = const Color(0xFF88B7B7);
          secondaryContainer = const Color(0xFF1F3D3D);
          onSecondary = const Color(0xFF0D1E1E);
          tertiary = const Color(0xFFA1BED1);
          onTertiary = const Color(0xFF192C38);
          outline = AppColors.nordicOutlineDark;
          onSurface = AppColors.nordicTextLight;
          textMuted = AppColors.nordicTextMutedDark;
          break;

        case 'sunset_terracotta':
          bg = AppColors.sunsetBgDark;
          surface = AppColors.sunsetSurfaceDark;
          surfaceContainer = AppColors.sunsetSurfaceContainerDark;
          surfaceContainerHighest = AppColors.sunsetSurfaceVariantDark;
          primary = AppColors.sunsetPrimaryDark;
          primaryContainer = AppColors.sunsetPrimaryContainerDark;
          onPrimary = const Color(0xFF3B150A);
          onPrimaryContainer = AppColors.sunsetOnPrimaryContainerDark;
          secondary = const Color(0xFFDEB088);
          secondaryContainer = const Color(0xFF472D18);
          onSecondary = const Color(0xFF291708);
          tertiary = const Color(0xFFD6A596);
          onTertiary = const Color(0xFF3B1E16);
          outline = AppColors.sunsetOutlineDark;
          onSurface = AppColors.sunsetTextLight;
          textMuted = AppColors.sunsetTextMutedDark;
          break;

        case 'cyberpunk_neon':
          bg = AppColors.cyberBgDark;
          surface = AppColors.cyberSurfaceDark;
          surfaceContainer = AppColors.cyberSurfaceContainerDark;
          surfaceContainerHighest = AppColors.cyberSurfaceVariantDark;
          primary = AppColors.cyberPrimaryDark;
          primaryContainer = AppColors.cyberPrimaryContainerDark;
          onPrimary = const Color(0xFF12260E);
          onPrimaryContainer = AppColors.cyberOnPrimaryContainerDark;
          secondary = const Color(0xFFBA9477);
          secondaryContainer = const Color(0xFF3D2C1F);
          onSecondary = const Color(0xFF21150C);
          tertiary = const Color(0xFF91B889);
          onTertiary = const Color(0xFF1B2E18);
          outline = AppColors.cyberOutlineDark;
          onSurface = AppColors.cyberTextLight;
          textMuted = AppColors.cyberTextMutedDark;
          break;

        case 'sage_coral':
        default:
          bg = AppColors.sageBgDark;
          surface = AppColors.sageSurfaceDark;
          surfaceContainer = AppColors.sageSurfaceContainerDark;
          surfaceContainerHighest = AppColors.sageSurfaceVariantDark;
          primary = AppColors.sagePrimaryDark;
          primaryContainer = AppColors.sagePrimaryContainerDark;
          onPrimary = const Color(0xFF052E16);
          onPrimaryContainer = AppColors.sageOnPrimaryContainerDark;
          secondary = const Color(0xFFFDBA74);
          secondaryContainer = const Color(0xFF7C2D12);
          onSecondary = const Color(0xFF431407);
          tertiary = const Color(0xFFD8B4FE);
          onTertiary = const Color(0xFF3B0764);
          outline = AppColors.sageOutlineDark;
          onSurface = AppColors.sageTextLight;
          textMuted = AppColors.sageTextMutedDark;
          break;
      }
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
