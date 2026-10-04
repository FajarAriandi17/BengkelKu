import "package:flutter/material.dart";

import "app_colors.dart";
import "app_typography.dart";

/// Tema terang & gelap BengkelKu. Menyuntikkan AppColors sebagai ThemeExtension
/// dan memetakan skala tipografi ke TextTheme.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(AppColors.light, Brightness.light);
  static ThemeData dark() => _base(AppColors.dark, Brightness.dark);

  static ThemeData _base(AppColors c, Brightness brightness) {
    final textTheme = TextTheme(
      displayLarge: AppTypography.display.copyWith(color: c.ink),
      headlineMedium: AppTypography.h1.copyWith(color: c.ink),
      titleLarge: AppTypography.h2.copyWith(color: c.ink),
      bodyMedium: AppTypography.body.copyWith(color: c.ink),
      labelLarge: AppTypography.label.copyWith(color: c.ink),
      bodySmall: AppTypography.caption.copyWith(color: c.ink),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.panel2,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.blue,
        brightness: brightness,
        surface: c.panel,
      ),
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[c],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.label,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.blueSoft),
        ),
      ),
    );
  }
}
