import 'package:flutter/material.dart';

/// Material 3 theme tuned for children: bright but not garish, generous type
/// sizes, and touch targets that never drop below 56dp (spec §UI: large touch
/// targets, accessible, designed for under-15s).
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF2E8B8B); // friendly teal

  /// Minimum size for anything a child must tap during an assessment.
  static const double minTouchTarget = 56;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(minTouchTarget * 2, minTouchTarget),
          textStyle: base.textTheme.titleMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minTouchTarget * 2, minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      ),
      appBarTheme: base.appBarTheme.copyWith(centerTitle: true),
    );
  }
}
