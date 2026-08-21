import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/retour_auth.dart';
import 'package:partyplan/app/router.dart';

void main() {
  group('RetourAuth', () {
    test('accepte uniquement les deux formes d’invitation internes', () {
      expect(RetourAuth.destination('/join/JETON'), '/join/JETON');
      expect(
        RetourAuth.destination('/rejoindre/PLAN-K7M2X9'),
        '/rejoindre/PLAN-K7M2X9',
      );
    });

    test('refuse une redirection externe ou privilégiée', () {
      for (final valeur in [
        'https://evil.test/join/JETON',
        '//evil.test/join/JETON',
        '/admin/comptes',
        '/join/JETON/participer',
        '/join/JETON%2Fparticiper',
        '/join/JETON%2fparticiper',
        '/join/JETON%3Fx',
        '/join/JETON%23x',
        '/join/JETON#fragment',
        '/join/JETON?source=evil',
        '/join/',
        '/join/JETON/',
        '/rejoindre/',
        '/rejoindre/PLAN-K7M2X9/plus',
        'join/JETON',
      ]) {
        expect(
          RetourAuth.destination(valeur),
          PpRoutes.accueil,
          reason: valeur,
        );
      }
    });

    test('construit les URLs auth en encodant le retour', () {
      expect(
        RetourAuth.versConnexion('/join/JETON'),
        '/connexion?retour=%2Fjoin%2FJETON',
      );
      expect(
        RetourAuth.versInscription('/rejoindre/PLAN-K7M2X9'),
        '/inscription?retour=%2Frejoindre%2FPLAN-K7M2X9',
      );
    });
  });
}
