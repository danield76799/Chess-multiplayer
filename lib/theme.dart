import 'package:flutter/material.dart';

/// Gedeeld uiterlijk van P2P Chess: donkergroen clubhuis met goud accent.
class ChessTheme {
  const ChessTheme._();

  static const Color gold = Color(0xFFE3B764);
  static const Color goldDark = Color(0xFFC69A3F);
  static const Color background = Color(0xFF0E1512);
  static const Color surface = Color(0xFF16211B);
  static const Color surfaceHigh = Color(0xFF1F2C24);
  static const Color surfaceHighest = Color(0xFF28382F);
  static const Color line = Color(0xFF2A3B32);
  static const Color text = Color(0xFFECEFE8);
  static const Color textDim = Color(0xFF9DB3A6);
  static const Color green = Color(0xFF8FD0A0);
  static const Color red = Color(0xFFFF8A80);

  /// Achtergrond met diepe groentinten (linksboven → rechtsonder).
  static const BoxDecoration backgroundDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF16241D), Color(0xFF0E1512), Color(0xFF090E0C)],
      stops: [0.0, 0.55, 1.0],
    ),
  );

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: gold,
      onPrimary: Color(0xFF241A05),
      primaryContainer: Color(0xFF4A3B1B),
      onPrimaryContainer: Color(0xFFF6E3AC),
      secondary: Color(0xFF8FD0A0),
      onSecondary: Color(0xFF0E2415),
      secondaryContainer: Color(0xFF24401F),
      onSecondaryContainer: Color(0xFFB9EBC6),
      tertiary: Color(0xFFE8C9A0),
      onTertiary: Color(0xFF3A2408),
      error: red,
      onError: Color(0xFF5B1008),
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceHighest,
      onSurfaceVariant: textDim,
      outline: Color(0xFF3A4B41),
      outlineVariant: line,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: text,
      onInverseSurface: Color(0xFF1B2620),
      inversePrimary: goldDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: ThemeData(brightness: Brightness.dark)
          .textTheme
          .apply(bodyColor: text, displayColor: text),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: text,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF241A05),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: Color(0xFF4A3B1B),
        labelStyle: TextStyle(color: text),
        secondaryLabelStyle: TextStyle(color: Color(0xFFF6E3AC)),
        side: BorderSide(color: line),
        shape: StadiumBorder(),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      iconTheme: const IconThemeData(color: text),
    );
  }

}
