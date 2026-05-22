import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Palette
  // ---------------------------------------------------------------------------

  static const Color background     = Color(0xFF0A0E17);
  static const Color surface        = Color(0xFF111827);
  static const Color surfaceRaised  = Color(0xFF1C2333);
  static const Color border         = Color(0xFF2D3748);
  static const Color textPrimary    = Color(0xFFE2E8F0);
  static const Color textSecondary  = Color(0xFF94A3B8);
  static const Color textMuted      = Color(0xFF4A5568);
  static const Color accent         = Color(0xFF38BDF8); // sky blue
  static const Color accentDim      = Color(0xFF0C4A6E);
  static const Color success        = Color(0xFF34D399);
  static const Color warning        = Color(0xFFFBBF24);
  static const Color danger         = Color(0xFFF87171);
  static const Color evaluating     = Color(0xFFA78BFA);

  // Amino acid physicochemical property colours
  // Reference: Taylor (1997) colouring scheme, widely used in bioinformatics
  static const Map<String, Color> aminoAcidColors = {
    // Hydrophobic
    'A': Color(0xFFD4C253), 'V': Color(0xFFD4C253),
    'I': Color(0xFFD4C253), 'L': Color(0xFFD4C253),
    'M': Color(0xFFD4C253), 'F': Color(0xFFD4C253),
    'W': Color(0xFFD4C253), 'P': Color(0xFFD4C253),
    // Polar uncharged
    'S': Color(0xFF6BCB77), 'T': Color(0xFF6BCB77),
    'N': Color(0xFF6BCB77), 'Q': Color(0xFF6BCB77),
    // Charged positive
    'K': Color(0xFF4D96FF), 'R': Color(0xFF4D96FF),
    'H': Color(0xFF4D96FF),
    // Charged negative
    'D': Color(0xFFF87171), 'E': Color(0xFFF87171),
    // Special
    'C': Color(0xFFFFD166), 'Y': Color(0xFF06D6A0),
    'G': Color(0xFF9D9D9D),
  };

  static Color colorForAminoAcid(String aa) =>
      aminoAcidColors[aa] ?? const Color(0xFF9D9D9D);

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: accent,
      secondary: success,
      error: danger,
    ),
    fontFamily: 'JetBrainsMono',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: textMuted, letterSpacing: 0.5,
      ),
    ),
    dividerColor: border,
    cardColor: surfaceRaised,
  );
}