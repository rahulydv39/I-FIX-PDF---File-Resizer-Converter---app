/// App color palette
/// Defines the color scheme for the application with a modern, premium look
library;

import 'package:flutter/material.dart';

/// Application color constants
class AppColors {
  AppColors._();

  // Primary Colors - Deep Purple gradient for premium feel
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  // Secondary Colors - Teal accent
  static const Color secondary = Color(0xFF14B8A6); // Teal
  static const Color secondaryDark = Color(0xFF0D9488);
  static const Color secondaryLight = Color(0xFF2DD4BF);

  // Accent Colors - Purple/Magenta for special features
  static const Color accent = Color(0xFFA855F7); // Purple
  static const Color accentDark = Color(0xFF9333EA);
  static const Color accentLight = Color(0xFFC084FC);

  // Background Colors
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color backgroundMedium = Color(0xFF1E293B); // Slate 800
  static const Color backgroundLight = Color(0xFF334155); // Slate 700

  // Surface Colors
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardDark = Color(0xFF334155);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500

  // Status Colors
  static const Color success = Color(0xFF22C55E); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Premium Colors
  static const Color premiumGold = Color(0xFFD4AF37);
  static const Color premiumGradientStart = Color(0xFFFFD700);
  static const Color premiumGradientEnd = Color(0xFFB8860B);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [premiumGradientStart, premiumGradientEnd],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark, backgroundMedium],
  );
}
