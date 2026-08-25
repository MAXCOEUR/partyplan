import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/l10n/validateurs.dart';

/// Validation locale des mots de passe (`RG-AUTH-01`).
///
/// Elle double celle du serveur et ne la remplace pas. Son intérêt est d'éviter un
/// aller-retour réseau pour une faute évidente : les messages doivent donc dire
/// précisément ce qui manque, sinon la personne corrige au hasard.
void main() {
  group('Validateurs.motDePasse', () {
    test('un mot de passe vide est refusé', () {
      expect(Validateurs.motDePasse(''), isNotNull);
      expect(Validateurs.motDePasse(null), isNotNull);
    });

    test('moins de huit caractères est refusé', () {
      expect(Validateurs.motDePasse('Kx7!vw'), contains('8'));
    });

    test('plus de trente caractères est refusé', () {
      expect(Validateurs.motDePasse('Kx7!vwqm' * 5), contains('30'));
    });

    test('une classe manquante est refusée, et nommée', () {
      // Le message nomme ce qui manque. « Mot de passe invalide » obligerait à
      // deviner laquelle des quatre exigences n'est pas remplie.
      expect(Validateurs.motDePasse('minuscule1!'), contains('majuscule'));
      expect(Validateurs.motDePasse('MAJUSCULE1!'), contains('minuscule'));
      expect(Validateurs.motDePasse('MajusculeSans!'), contains('chiffre'));
      expect(Validateurs.motDePasse('MajusculeAvec1'), contains('spécial'));
    });

    test('un mot de passe complet est accepté', () {
      expect(Validateurs.motDePasse('Kx7!vwqm'), isNull);
    });
  });

  group('Validateurs.confirmation', () {
    test('une confirmation vide est refusée', () {
      expect(Validateurs.confirmation('Kx7!vwqm', ''), isNotNull);
    });

    test('deux saisies différentes sont refusées', () {
      expect(
        Validateurs.confirmation('Kx7!vwqm', 'Kx7!vwqn'),
        contains('correspondent pas'),
      );
    });

    test('deux saisies identiques sont acceptées', () {
      expect(Validateurs.confirmation('Kx7!vwqm', 'Kx7!vwqm'), isNull);
    });
  });
}
