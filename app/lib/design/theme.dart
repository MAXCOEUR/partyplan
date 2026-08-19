import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Thèmes clair et sombre.
///
/// Aucun appel à `ThemeData()` par défaut : toutes les surfaces, bordures et cibles
/// tactiles sont fixées explicitement, de façon qu'un composant Material non
/// personnalisé reste cohérent avec la charte.
abstract final class PpTheme {
  static ThemeData clair() => _construire(
    brightness: Brightness.light,
    fond: PpColors.fondClair,
    surface: PpColors.surfaceClaire,
    bordure: PpColors.bordureClaire,
    texte: PpColors.texteClair,
    texteSecondaire: PpColors.texteSecondaireClair,
  );

  static ThemeData sombre() => _construire(
    brightness: Brightness.dark,
    fond: PpColors.fondSombre,
    surface: PpColors.surfaceSombre,
    bordure: PpColors.bordureSombre,
    texte: PpColors.texteSombre,
    texteSecondaire: PpColors.texteSecondaireSombre,
  );

  static ThemeData _construire({
    required Brightness brightness,
    required Color fond,
    required Color surface,
    required Color bordure,
    required Color texte,
    required Color texteSecondaire,
  }) {
    final schema = ColorScheme(
      brightness: brightness,
      primary: PpColors.violet,
      onPrimary: Colors.white,
      primaryContainer: PpColors.violetClair,
      onPrimaryContainer: Colors.white,
      secondary: PpColors.rose,
      onSecondary: Colors.white,
      tertiary: PpColors.vert,
      onTertiary: Colors.white,
      error: PpColors.rouge,
      onError: Colors.white,
      surface: surface,
      onSurface: texte,
      onSurfaceVariant: texteSecondaire,
      outline: bordure,
      outlineVariant: bordure,
      surfaceContainerLowest: fond,
      surfaceContainerLow: fond,
      surfaceContainer: surface,
    );

    final textes = PpTypography.theme(texte, texteSecondaire);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: schema,
      scaffoldBackgroundColor: fond,
      fontFamily: PpTypography.famille,
      textTheme: textes,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: fond,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textes.titleLarge,
        foregroundColor: texte,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PpRadius.card),
          side: BorderSide(color: bordure),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, PpA11y.cibleMinimale + 4),
          padding: const EdgeInsets.symmetric(horizontal: PpSpacing.xl),
          textStyle: textes.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PpRadius.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, PpA11y.cibleMinimale + 4),
          padding: const EdgeInsets.symmetric(horizontal: PpSpacing.xl),
          textStyle: textes.labelLarge,
          side: BorderSide(color: bordure),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PpRadius.pill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PpSpacing.lg,
          vertical: PpSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PpRadius.md),
          borderSide: BorderSide(color: bordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PpRadius.md),
          borderSide: BorderSide(color: bordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PpRadius.md),
          borderSide: const BorderSide(color: PpColors.violet, width: 2),
        ),
        labelStyle: textes.bodyMedium,
        hintStyle: textes.bodyMedium?.copyWith(color: texteSecondaire),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: PpColors.violet.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(textes.labelMedium),
      ),
      dividerTheme: DividerThemeData(color: bordure, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: bordure),
        labelStyle: textes.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PpRadius.pill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PpColors.fondSombre,
        contentTextStyle: textes.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PpRadius.md),
        ),
      ),
    );
  }
}
