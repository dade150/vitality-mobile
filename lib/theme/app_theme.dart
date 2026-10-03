import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Costruisce i temi chiaro e scuro dell'app a partire dai colori e dalla
/// tipografia definiti nel design system "Vitality Assist" (vedi DESIGN.md
/// esportato da Google Stitch): Atkinson Hyperlegible per i titoli/etichette
/// (massima leggibilità) e Open Sans per il testo corrente.
class AppTheme {
  AppTheme._();

  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
      secondary: AppColors.secondarySeed,
      tertiary: AppColors.tertiarySeed,
      error: AppColors.errorSeed,
    );

    if (brightness == Brightness.light) {
      return base.copyWith(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        primaryContainer: AppColors.lightPeach,
        onPrimaryContainer: const Color(0xFF3A1400),
        secondaryContainer: AppColors.lightGreenContainer,
        tertiaryContainer: AppColors.lightBlueContainer,
        surface: AppColors.lightBackground,
        onSurface: const Color(0xFF2A1A14),
        onSurfaceVariant: const Color(0xFF5A453D),
        surfaceContainerLowest: AppColors.lightCard,
        surfaceContainerLow: AppColors.lightBackground,
        surfaceContainer: AppColors.lightMuted,
        surfaceContainerHigh: AppColors.lightMuted,
        surfaceContainerHighest: AppColors.lightBorder,
        outlineVariant: AppColors.lightBorder,
      );
    }

    return base.copyWith(
      primary: const Color(0xFFFF8A3D),
      onPrimary: const Color(0xFF3A1400),
    );
  }

  static TextTheme _textTheme(ColorScheme cs) {
    final headline = GoogleFonts.atkinsonHyperlegibleTextTheme();
    final body = GoogleFonts.openSansTextTheme();

    return TextTheme(
      displayLarge: headline.displayLarge?.copyWith(
          fontSize: 40, fontWeight: FontWeight.w800, height: 1.2, color: cs.onSurface),
      displayMedium: headline.displayMedium?.copyWith(
          fontSize: 34, fontWeight: FontWeight.w800, height: 1.2, color: cs.onSurface),
      displaySmall: headline.displaySmall?.copyWith(
          fontSize: 30, fontWeight: FontWeight.w800, height: 1.2, color: cs.onSurface),
      headlineLarge: headline.headlineLarge?.copyWith(
          fontSize: 32, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurface),
      headlineMedium: headline.headlineMedium?.copyWith(
          fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurface),
      headlineSmall: headline.headlineSmall?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, height: 1.3, color: cs.onSurface),
      titleLarge: headline.titleLarge?.copyWith(
          fontSize: 24, fontWeight: FontWeight.w600, height: 1.25, color: cs.onSurface),
      titleMedium: headline.titleMedium?.copyWith(
          fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, color: cs.onSurface),
      titleSmall: headline.titleSmall?.copyWith(
          fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, color: cs.onSurface),
      bodyLarge: body.bodyLarge?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w400, height: 1.45, color: cs.onSurface),
      bodyMedium: body.bodyMedium?.copyWith(
          fontSize: 18, fontWeight: FontWeight.w400, height: 1.55, color: cs.onSurface),
      bodySmall: body.bodySmall?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, color: cs.onSurfaceVariant),
      labelLarge: headline.labelLarge?.copyWith(
          fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, color: cs.onSurface),
      labelMedium: body.labelMedium?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: cs.onSurfaceVariant),
      labelSmall: body.labelSmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w600, height: 1.3, color: cs.onSurfaceVariant),
    );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final cs = _scheme(brightness);
    final textTheme = _textTheme(cs);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: isDark ? 1 : 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: textTheme.labelLarge,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size.fromHeight(60),
          textStyle: textTheme.labelLarge?.copyWith(color: cs.onPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(0, 48),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? cs.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? cs.primary.withValues(alpha: 0.4) : null,
        ),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 32),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}