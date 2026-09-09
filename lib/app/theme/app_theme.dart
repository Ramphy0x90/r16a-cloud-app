import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the light and dark [ThemeData] for the app from [AppColors].
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        background: AppColors.lightBackground,
        foreground: AppColors.lightForeground,
        card: AppColors.lightCard,
        accent: AppColors.lightAccent,
        onAccent: AppColors.lightAccentForeground,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        background: AppColors.darkBackground,
        foreground: AppColors.darkForeground,
        card: AppColors.darkCard,
        accent: AppColors.darkAccent,
        onAccent: AppColors.darkAccentForeground,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color background,
    required Color foreground,
    required Color card,
    required Color accent,
    required Color onAccent,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      surface: background,
      onSurface: foreground,
      surfaceContainer: card,
      surfaceContainerHighest: accent,
      onSurfaceVariant: onAccent,
      error: AppColors.alert,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Rubik',
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Rubik',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}
