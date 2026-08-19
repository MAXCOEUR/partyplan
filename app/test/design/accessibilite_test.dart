import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/tokens.dart';

/// Contraste WCAG 2.1 entre deux couleurs opaques.
double _contraste(Color premier, Color second) {
  double luminance(Color couleur) {
    double canal(double valeur) => valeur <= 0.03928
        ? valeur / 12.92
        : math.pow((valeur + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * canal(couleur.r) +
        0.7152 * canal(couleur.g) +
        0.0722 * canal(couleur.b);
  }

  final a = luminance(premier);
  final b = luminance(second);

  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  // NF-A11Y-01 : WCAG 2.1 AA, soit 4,5:1 pour du texte de taille courante.
  const seuilTexte = 4.5;

  group('Contraste des textes sur fond clair', () {
    const fond = PpColors.fondClair;
    const surface = PpColors.surfaceClaire;

    test('texte principal', () {
      expect(
        _contraste(PpColors.texteClair, fond),
        greaterThanOrEqualTo(seuilTexte),
      );
      expect(
        _contraste(PpColors.texteClair, surface),
        greaterThanOrEqualTo(seuilTexte),
      );
    });

    test('texte secondaire', () {
      expect(
        _contraste(PpColors.texteSecondaireClair, fond),
        greaterThanOrEqualTo(seuilTexte),
      );
    });

    test('les variantes d’accent atteignent le seuil', () {
      // Les couleurs vives de la charte échouent ici : c'est précisément la raison
      // d'être des variantes assombries.
      for (final couleur in [
        PpColors.vertTexte,
        PpColors.roseTexte,
        PpColors.orangeTexte,
        PpColors.rougeTexte,
      ]) {
        expect(_contraste(couleur, fond), greaterThanOrEqualTo(seuilTexte));
        expect(_contraste(couleur, surface), greaterThanOrEqualTo(seuilTexte));
      }
    });

    test(
      'les couleurs vives de la charte ne sont pas utilisables comme texte',
      () {
        // Test de garde : si l'une venait à passer, c'est que la charte a changé, et
        // texteSur pourrait alors être simplifié.
        expect(_contraste(PpColors.vert, fond), lessThan(seuilTexte));
        expect(_contraste(PpColors.orange, fond), lessThan(seuilTexte));
      },
    );
  });

  group('Contraste des aplats portant du texte blanc', () {
    test('bouton principal violet', () {
      expect(
        _contraste(Colors.white, PpColors.violet),
        greaterThanOrEqualTo(seuilTexte),
      );
    });

    test('pastille d’attribution', () {
      // Le rose de charte n'atteint que 3,14:1 avec du blanc : l'aplat est assombri.
      expect(
        _contraste(Colors.white, PpColors.roseAplat),
        greaterThanOrEqualTo(seuilTexte),
      );
    });
  });

  group('Contraste sur fond sombre', () {
    test('textes et accents', () {
      expect(
        _contraste(PpColors.texteSombre, PpColors.fondSombre),
        greaterThanOrEqualTo(seuilTexte),
      );
      expect(
        _contraste(PpColors.texteSecondaireSombre, PpColors.surfaceSombre),
        greaterThanOrEqualTo(seuilTexte),
      );
      // Sur fond sombre les couleurs vives passent : les assombrir les rendrait pires.
      expect(
        _contraste(PpColors.vert, PpColors.surfaceSombre),
        greaterThanOrEqualTo(seuilTexte),
      );
      expect(
        _contraste(PpColors.rose, PpColors.surfaceSombre),
        greaterThanOrEqualTo(seuilTexte),
      );
    });
  });

  group('PpColors.texteSur', () {
    test('assombrit en thème clair', () {
      expect(
        PpColors.texteSur(PpColors.vert, Brightness.light),
        PpColors.vertTexte,
      );
      expect(
        PpColors.texteSur(PpColors.rose, Brightness.light),
        PpColors.roseTexte,
      );
    });

    test('conserve la couleur en thème sombre', () {
      expect(PpColors.texteSur(PpColors.vert, Brightness.dark), PpColors.vert);
    });

    test('laisse passer une couleur inconnue', () {
      expect(
        PpColors.texteSur(PpColors.violet, Brightness.light),
        PpColors.violet,
      );
    });
  });
}
