import 'package:flutter/material.dart';

/// MindSprint design system — translated from the AI Studio prototype's
/// visual language: deep near-black surfaces, indigo primary, glassy borders,
/// generous radii, uppercase micro-labels, mono accents for data. Child
/// requirements are non-negotiable: 56dp+ touch targets, high contrast,
/// readable type.
class AppTheme {
  AppTheme._();

  // Core palette (prototype: Tailwind gray-950/900/800 + indigo-500).
  static const Color bg = Color(0xFF030712); // gray-950
  static const Color surface = Color(0xFF111827); // gray-900
  static const Color surfaceHigh = Color(0xFF1F2937); // gray-800
  static const Color border = Color(0xFF283548); // gray-800/80 glassy
  static const Color primary = Color(0xFF6366F1); // indigo-500
  static const Color success = Color(0xFF34D399); // emerald-400
  static const Color danger = Color(0xFFFB7185); // rose-400
  static const Color textDim = Color(0xFF9CA3AF); // gray-400

  /// Minimum size for anything a child must tap during an assessment.
  static const double minTouchTarget = 56;

  static const BorderRadius radiusL = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(28));

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: bg,
      surfaceContainerLow: surface,
      surfaceContainerHighest: surfaceHigh,
      primary: primary,
      error: danger,
      outlineVariant: border,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineSmall: base.textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.25),
        titleLarge:
            base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        labelSmall: base.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2, fontWeight: FontWeight.w700, color: textDim),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(minTouchTarget * 2, minTouchTarget),
          textStyle:
              base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: radiusL),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minTouchTarget * 2, minTouchTarget),
          side: const BorderSide(color: border),
          shape: const RoundedRectangleBorder(borderRadius: radiusL),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
            borderRadius: radiusL, borderSide: BorderSide(color: border)),
        enabledBorder: const OutlineInputBorder(
            borderRadius: radiusL, borderSide: BorderSide(color: border)),
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: radiusXl,
          side: BorderSide(color: border),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        backgroundColor: bg,
        elevation: 0,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: radiusXl,
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}
