import 'package:flutter/material.dart';

class AppTheme {
  // Color palette - industrial dark with amber accents
  static const Color bgPrimary    = Color(0xFF0D0F14);
  static const Color bgSecondary  = Color(0xFF161A22);
  static const Color bgPanel      = Color(0xFF1C2130);
  static const Color bgCard       = Color(0xFF232838);
  static const Color borderColor  = Color(0xFF2D3448);
  static const Color accent       = Color(0xFFE8A020);
  static const Color accentLight  = Color(0xFFFFBF47);
  static const Color accentDim    = Color(0xFF8B6012);
  static const Color textPrimary  = Color(0xFFE8EAF0);
  static const Color textSecondary= Color(0xFF8892A8);
  static const Color textMuted    = Color(0xFF4A5568);
  static const Color success      = Color(0xFF48BB78);
  static const Color danger       = Color(0xFFFC8181);
  static const Color boneColor    = Color(0xFF64D8CB);
  static const Color boneSelected = Color(0xFF00E5CC);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: boneColor,
      surface: bgPanel,
      onSurface: textPrimary,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: bgSecondary,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    dividerColor: borderColor,
    cardColor: bgCard,
    iconTheme: const IconThemeData(color: textSecondary, size: 18),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: bgPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textSecondary,
        textStyle: const TextStyle(fontSize: 12, letterSpacing: 0.3),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: bgCard,
      thumbColor: accentLight,
      overlayColor: Color(0x22E8A020),
      trackHeight: 2,
    ),
  );
}
