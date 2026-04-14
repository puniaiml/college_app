import 'package:flutter/material.dart';

/// Helper class for theme-aware color access
class ThemeHelper {
  /// Get the current theme brightness
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get surface color (card/container background)
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  /// Get background color
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.background;
  }

  /// Get primary color
  static Color primaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Get secondary color
  static Color secondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  /// Get text color for body text
  static Color textColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Get text color for primary text
  static Color primaryTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }

  /// Get card color (elevated surface)
  static Color cardColor(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.surface;
    }
    return Colors.white;
  }

  /// Get divider color
  static Color dividerColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  /// Get error color
  static Color errorColor(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  /// Get success color (green)
  static Color successColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF4ADE80) : const Color(0xFF10B981);
  }

  /// Get warning color (orange/yellow)
  static Color warningColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  }

  /// Get info color (blue)
  static Color infoColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  }

  /// Get a color that contrasts with the background
  static Color contrastColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }

  /// Get a subtle background color for containers
  static Color subtleBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark 
        ? const Color(0xFF1E1E1E) 
        : const Color(0xFFF9FAFB);
  }

  /// Get shadow color based on theme
  static Color shadowColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark 
        ? Colors.black.withOpacity(0.5) 
        : Colors.black.withOpacity(0.1);
  }

  /// Get a color with opacity based on theme
  static Color colorWithOpacity(BuildContext context, Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  /// Get status bar brightness
  static Brightness statusBarBrightness(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
  }

  /// Get system navigation bar color
  static Color systemNavBarColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF121212) : Colors.white;
  }
}

