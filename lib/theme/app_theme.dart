import 'package:flutter/material.dart';

class AppTheme {
  // Light theme colors (your existing)
  static const primaryBlue = Color(0xFF2196F3);
  static const accentBlue = Color(0xFF448AFF);
  static const vibrantRed = Color(0xFFFF5252);
  static const lightRed = Color.fromARGB(255, 225, 48, 32);
  static const backgroundStart = Color(0xFFF5F9FF);
  static const backgroundEnd = Color(0xFFFFEFEF);

  // 🌙 NEW: Dark theme colors
  static const darkPrimaryBlue = Color(0xFF64B5F6);
  static const darkAccentBlue = Color(0xFF82B1FF);
  static const darkVibrantRed = Color(0xFFFF6B6B);
  static const darkBackgroundStart = Color(0xFF0A0E1A);
  static const darkBackgroundEnd = Color(0xFF1A1A2E);
  static const darkSurface = Color(0xFF16213E);
  static const darkCard = Color(0xFF1E2749);
  static const darkText = Color(0xFFE3F2FD);
  static const darkTextSecondary = Color(0xFFB0BEC5);

  // 🎨 Your existing lightTheme (keeping it the same)
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundStart,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: vibrantRed,
        tertiary: accentBlue,
        background: backgroundStart,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        brightness: Brightness.light,
      ),
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryBlue,
        ),
        displayMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryBlue,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF2C3E50),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF34495E),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: primaryBlue.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shadowColor: primaryBlue.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: vibrantRed,
        elevation: 4,
        splashColor: lightRed,
        foregroundColor: Colors.white,
        hoverElevation: 6,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryBlue,
        linearTrackColor: backgroundEnd,
        circularTrackColor: backgroundEnd,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryBlue,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundEnd,
        selectedColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        labelStyle: const TextStyle(color: Color(0xFF2C3E50)),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        brightness: Brightness.light,
      ),
    );
  }

  // 🌙 NEW: Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkPrimaryBlue,
      scaffoldBackgroundColor: darkBackgroundStart,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimaryBlue,
        brightness: Brightness.dark,
        primary: darkPrimaryBlue,
        secondary: darkVibrantRed,
        tertiary: darkAccentBlue,
        background: darkBackgroundStart,
        surface: darkSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: darkText,
        error: darkVibrantRed,
      ),
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkPrimaryBlue,
        ),
        displayMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkPrimaryBlue,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: darkTextSecondary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryBlue,
          foregroundColor: Colors.black,
          elevation: 6,
          shadowColor: darkPrimaryBlue.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: darkSurface,
        foregroundColor: darkText,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkVibrantRed,
        elevation: 6,
        splashColor: darkVibrantRed.withOpacity(0.7),
        foregroundColor: Colors.white,
        hoverElevation: 8,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: darkPrimaryBlue,
        linearTrackColor: darkBackgroundEnd,
        circularTrackColor: darkBackgroundEnd,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: TextStyle(color: darkText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkBackgroundEnd,
        selectedColor: darkPrimaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        labelStyle: TextStyle(color: darkText),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        brightness: Brightness.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkPrimaryBlue,
        unselectedItemColor: darkTextSecondary,
        elevation: 8,
      ),
    );
  }

  // 🛠️ NEW: Helper methods for theme-aware colors
  static Color getBackgroundGradientStart(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackgroundStart
        : backgroundStart;
  }

  static Color getBackgroundGradientEnd(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackgroundEnd
        : backgroundEnd;
  }

  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryBlue
        : primaryBlue;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : Colors.white;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkText
        : const Color(0xFF2C3E50);
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : const Color(0xFF34495E);
  }

  // 🎨 Helper for creating gradient backgrounds
  static LinearGradient getBackgroundGradient(BuildContext context) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        getBackgroundGradientStart(context),
        getBackgroundGradientEnd(context),
      ],
    );
  }

  // 🩺 Pain level colors that work for both themes
  static Color getPainColor(BuildContext context, int painLevel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (painLevel <= 2) {
      return isDark ? Colors.green.shade300 : Colors.green;
    } else if (painLevel <= 4) {
      return isDark ? Colors.lightGreen.shade300 : Colors.lightGreen;
    } else if (painLevel <= 6) {
      return isDark ? Colors.orange.shade300 : Colors.orange;
    } else if (painLevel <= 8) {
      return isDark ? Colors.deepOrange.shade300 : Colors.deepOrange;
    } else {
      return isDark ? Colors.red.shade300 : Colors.red;
    }
  }
}
