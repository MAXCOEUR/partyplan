import 'package:flutter/material.dart';

/// Typographie. Poppins seul, en trois rôles distincts.
///
/// `display` porte les chiffres clés et les titres d'écran, `body` le texte courant,
/// `utility` les libellés courts en majuscules. Le rôle `utility` existe pour éviter
/// que des libellés de catégorie soient rendus avec le style du corps de texte, ce qui
/// aplatit la hiérarchie.
abstract final class PpTypography {
  static const famille = 'Poppins';

  /// Chiffres à largeur fixe. Indispensable pour les montants : sans cela, une colonne
  /// de sommes ne s'aligne pas et le total semble bouger d'une ligne à l'autre.
  static const chiffresTabulaires = [FontFeature.tabularFigures()];

  static TextTheme theme(Color principal, Color secondaire) => TextTheme(
    displayLarge: TextStyle(
      fontFamily: famille,
      fontSize: 40,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
      color: principal,
    ),
    displayMedium: TextStyle(
      fontFamily: famille,
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      color: principal,
    ),
    titleLarge: TextStyle(
      fontFamily: famille,
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: principal,
    ),
    titleMedium: TextStyle(
      fontFamily: famille,
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: principal,
    ),
    bodyLarge: TextStyle(
      fontFamily: famille,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: principal,
    ),
    bodyMedium: TextStyle(
      fontFamily: famille,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: principal,
    ),
    bodySmall: TextStyle(
      fontFamily: famille,
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: secondaire,
    ),
    labelLarge: TextStyle(
      fontFamily: famille,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: principal,
    ),
    labelMedium: TextStyle(
      fontFamily: famille,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: secondaire,
    ),
  );
}
