import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Costruisce i temi chiaro e scuro dell'app basati interamente su
/// Atkinson Hyperlegible (font sviluppato dal Braille Institute of America
/// specificamente per persone con ipovisione e difficoltà di lettura)
/// e ottimizzati per gli standard di contrasto WCAG 2.1 AA/AAA.
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
        onSurface: const Color(0xFF2A1A14), // Contrasto > 15:1 su lightBackground
        onSurfaceVariant: const Color(0xFF4E3830), // Contrasto migliorato a > 8.5:1
        surfaceContainerLowest: AppColors.lightCard,
        surfaceContainerLow: AppColors.lightBackground,
        surfaceContainer: AppColors.lightMuted,
        surfaceContainerHigh: AppColors.lightMuted,
        surfaceContainerHighest: AppColors.lightBorder,
        outline: const Color(0xFF8A6B60),
        outlineVariant: AppColors.lightBorder,
      );
    }

    return base.copyWith(
      primary: const Color(0xFFFF8A3D),
      onPrimary: const Color(0xFF3A1400),
      primaryContainer: const Color(0xFF5A2200),
      onPrimaryContainer: const Color(0xFFFFDBCC),
      secondaryContainer: const Color(0xFF1B4D24),
      tertiaryContainer: const Color(0xFF00385A),
      surface: const Color(0xFF19120F),
      onSurface: const Color(0xFFF7ECE7), // Contrasto > 14:1 su dark surface
      onSurfaceVariant: const Color(0xFFDEC5BC), // Contrasto > 8:1
      surfaceContainerLowest: const Color(0xFF231A16),
      surfaceContainerLow: const Color(0xFF19120F),
      surfaceContainer: const Color(0xFF2C211C),
      surfaceContainerHigh: const Color(0xFF382C26),
      surfaceContainerHighest: const Color(0xFF453730),
      outline: const Color(0xFFA68D84),
      outlineVariant: const Color(0xFF5A4840),
    );
  }

  static TextTheme _textTheme(ColorScheme cs) {
    // Atkinson Hyperlegible su tutta la scala tipografica per massima distinzione
    // dei caratteri simili (1/l/I, 0/O) e massima leggibilità clinica.
    final font = GoogleFonts.atkinsonHyperlegibleTextTheme();

    return TextTheme(
      displayLarge: font.displayLarge?.copyWith(
          fontSize: 38, fontWeight: FontWeight.w800, height: 1.2, color: cs.onSurface),
      displayMedium: font.displayMedium?.copyWith(
          fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: cs.onSurface),
      displaySmall: font.displaySmall?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, color: cs.onSurface),
      headlineLarge: font.headlineLarge?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurface),
      headlineMedium: font.headlineMedium?.copyWith(
          fontSize: 24, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurface),
      headlineSmall: font.headlineSmall?.copyWith(
          fontSize: 21, fontWeight: FontWeight.w700, height: 1.3, color: cs.onSurface),
      titleLarge: font.titleLarge?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurface),
      titleMedium: font.titleMedium?.copyWith(
          fontSize: 19, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurface),
      titleSmall: font.titleSmall?.copyWith(
          fontSize: 17, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurface),
      bodyLarge: font.bodyLarge?.copyWith(
          fontSize: 19.5, fontWeight: FontWeight.w400, height: 1.45, color: cs.onSurface),
      bodyMedium: font.bodyMedium?.copyWith(
          fontSize: 17, fontWeight: FontWeight.w400, height: 1.45, color: cs.onSurface),
      bodySmall: font.bodySmall?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w500, height: 1.4, color: cs.onSurfaceVariant),
      labelLarge: font.labelLarge?.copyWith(
          fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, color: cs.onSurface),
      labelMedium: font.labelMedium?.copyWith(
          fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurfaceVariant),
      labelSmall: font.labelSmall?.copyWith(
          fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25, color: cs.onSurfaceVariant),
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
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.7 : 0.65),
            width: 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        hintStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size.fromHeight(56),
          textStyle: textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: isDark ? cs.primary : AppColors.accentText,
          side: BorderSide(color: isDark ? cs.primary : AppColors.accentText, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? cs.primary : AppColors.accentText,
          minimumSize: const Size(0, 48),
          textStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? cs.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? cs.primary.withValues(alpha: 0.45) : null,
        ),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 32),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}