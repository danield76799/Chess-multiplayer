import 'package:flutter/material.dart';

/// Gedeeld uiterlijk van P2P Chess: donkergroen clubhuis met goud accent.
class ChessTheme {
  const ChessTheme._();

  static const Color gold = Color(0xFFFFC53D);
  static const Color goldDark = Color(0xFFE0A32E);
  static const Color background = Color(0xFF130E28);
  static const Color surface = Color(0xFF1E1736);
  static const Color surfaceHigh = Color(0xFF2A2048);
  static const Color surfaceHighest = Color(0xFF342952);
  static const Color line = Color(0xFF3A2E5C);
  static const Color text = Color(0xFFF5F0FF);
  static const Color textDim = Color(0xFFB0A6D6);
  static const Color green = Color(0xFF6FDD8B);
  static const Color red = Color(0xFFFF7A6B);

  /// Achtergrond met diepe groentinten (linksboven → rechtsonder).
  static const BoxDecoration backgroundDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF241A4E), Color(0xFF1A1236), Color(0xFF100A22)],
      stops: [0.0, 0.55, 1.0],
    ),
  );

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: gold,
      onPrimary: Color(0xFF3A2600),
      primaryContainer: Color(0xFF4A3410),
      onPrimaryContainer: Color(0xFFFFE9A8),
      secondary: Color(0xFF5CE8C0),
      onSecondary: Color(0xFF053220),
      secondaryContainer: Color(0xFF17473B),
      onSecondaryContainer: Color(0xFFA9F2D3),
      tertiary: Color(0xFFFF9EC6),
      onTertiary: Color(0xFF3F0A22),
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
          foregroundColor: const Color(0xFF3A2600),
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
        selectedColor: Color(0xFF4A3410),
        labelStyle: TextStyle(color: text),
        secondaryLabelStyle: TextStyle(color: Color(0xFFFFE9A8)),
        side: BorderSide(color: line),
        shape: StadiumBorder(),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      iconTheme: const IconThemeData(color: text),
    );
  }

}
