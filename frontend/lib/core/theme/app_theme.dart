import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kairos_palette.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: KairosPalette.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KairosPalette.primary,
        primary: KairosPalette.primary,
        secondary: KairosPalette.secondary,
        surface: KairosPalette.card,
      ),
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      headlineLarge: const TextStyle(
        fontWeight: FontWeight.w800,
        color: KairosPalette.secondary,
      ),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w800,
        color: KairosPalette.secondary,
      ),
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: KairosPalette.secondary,
      ),
      titleMedium: const TextStyle(
        fontWeight: FontWeight.w700,
        color: KairosPalette.secondary,
      ),
      bodyLarge: const TextStyle(color: KairosPalette.foreground),
      bodyMedium: const TextStyle(color: KairosPalette.foreground),
      bodySmall: const TextStyle(color: KairosPalette.secondary),
    );

    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: KairosPalette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: KairosPalette.border, width: 1.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KairosPalette.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KairosPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KairosPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: KairosPalette.primary,
            width: 1.6,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: KairosPalette.primary,
          foregroundColor: Colors.white,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: KairosPalette.border),
        backgroundColor: KairosPalette.muted,
        // Keep chip hit areas keyboard and touch friendly at larger text sizes.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(color: KairosPalette.border),
    );
  }
}
