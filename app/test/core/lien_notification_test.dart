import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/lien_notification.dart';

/// Le lien porté par une notification vient de l'extérieur : il est traité comme une
/// entrée non fiable, exactement comme le « retour » d'invitation l'est déjà.
void main() {
  group('LienNotification.destination', () {
    test('une route interne est conservée', () {
      expect(
        LienNotification.destination({'deepLink': '/events/42'}),
        '/events/42',
      );
    });

    test('des données absentes ne donnent aucune destination', () {
      expect(LienNotification.destination(null), isNull);
      expect(LienNotification.destination({}), isNull);
    });

    test('une adresse absolue est rejetée', () {
      // Sans ce refus, une notification forgée ouvrirait un site tiers dans l'application.
      expect(
        LienNotification.destination({
          'deepLink': 'https://exemple.fr/phishing',
        }),
        isNull,
      );
    });

    test('un préfixe protocole-relatif est rejeté', () {
      expect(
        LienNotification.destination({'deepLink': '//exemple.fr'}),
        isNull,
      );
    });

    test('un chemin sans barre initiale est rejeté', () {
      expect(LienNotification.destination({'deepLink': 'events/42'}), isNull);
    });
  });
}
