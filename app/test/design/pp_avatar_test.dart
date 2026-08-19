import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_avatar.dart';

void main() {
  group('PpAvatar.initiales', () {
    test('un seul prénom donne une initiale', () {
      expect(PpAvatar.initiales('Maxence'), 'M');
    });

    test('prénom et nom donnent deux initiales', () {
      expect(PpAvatar.initiales('Maxence Cœur'), 'MC');
    });

    test('les espaces superflus sont ignorés', () {
      expect(PpAvatar.initiales('  Lucas   Martin  '), 'LM');
    });

    test('un nom vide ne fait pas échouer l’affichage', () {
      expect(PpAvatar.initiales('   '), '?');
    });

    test('les caractères accentués sont conservés', () {
      expect(PpAvatar.initiales('Émilie Durand'), 'ÉD');
    });
  });

  group('PpAvatar.couleurPour', () {
    test('la couleur est stable pour un même nom', () {
      // Une personne doit garder son repère visuel d'un écran à l'autre.
      expect(PpAvatar.couleurPour('Lucas'), PpAvatar.couleurPour('Lucas'));
    });

    test('la couleur provient de la palette de la charte', () {
      for (final nom in [
        'Maxence',
        'Lucas',
        'Emma',
        'Thomas',
        'Rémi',
        'Julie',
      ]) {
        expect(PpAvatar.couleurPour(nom).a, 1.0);
      }
    });
  });
}
