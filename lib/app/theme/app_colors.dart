import 'package:flutter/material.dart';

/// Palette ported 1:1 from the web client CSS custom properties
/// (`r16a-cloud_client/src/assets/styles/styles-{light,dark}.css`).
class AppColors {
  const AppColors._();

  // Light theme (`.light-theme`)
  static const lightPrimary = Color(0xFF006989);
  static const lightBackground = Color(0xFFEAEBED);
  static const lightForeground = Color(0xFF535355);
  static const lightCard = Color(0xFFF4F4F5);
  static const lightCardHover = Color(0xFFD1E2E8);
  static const lightAccent = Color(0xFFE0E0E3);
  static const lightAccentForeground = Color(0xFF18181B);

  // Dark theme (`.dark-theme`)
  static const darkPrimary = Color(0xFF10B981);
  static const darkBackground = Color(0xFF0A0A0B);
  static const darkForeground = Color(0xFFFAFAFA);
  static const darkCard = Color(0xFF18181B);
  static const darkCardHover = Color(0xFF27272A);
  static const darkAccent = Color(0xFF27272A);
  static const darkAccentForeground = Color(0xFFFAFAFA);

  // Shared
  static const folder = Color(0xFFFFBD21);
  static const alert = Color(0xFFEF4444);
}
