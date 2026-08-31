import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/notification_recue.dart';

/// Lecture d'une notification poussée.
///
/// La charge vient de l'extérieur : elle est traitée comme telle. Rien de ce qui manque
/// ou de ce qui est hostile ne doit lever — une notification mal formée se perd, elle ne
/// casse pas l'écran qu'on est en train de lire.
void main() {
  group('Notification reçue', () {
    test('lit une charge complète', () {
      final recue = NotificationRecue.depuis(
        const {
          'deepLink': '/events/42/depenses',
          'categorie': 'expense.new',
          'evenement': '42',
        },
        titre: 'Nouvelle dépense',
        corps: 'Maxence a ajouté « Courses »',
      );

      expect(recue, isNotNull);
      expect(recue!.categorie, 'expense.new');
      expect(recue.evenementId, '42');
      expect(recue.destination, '/events/42/depenses');
      expect(recue.titre, 'Nouvelle dépense');
      expect(recue.corps, 'Maxence a ajouté « Courses »');
    });

    test('accepte une notification sans soirée ni lien', () {
      final recue = NotificationRecue.depuis(
        const {'categorie': 'balance.due'},
        titre: 'Solde',
        corps: 'Tu dois 18,40 € à Maxence',
      );

      expect(recue, isNotNull);
      expect(recue!.evenementId, isNull);
      expect(recue.destination, isNull);
      expect(recue.categorie, 'balance.due');
    });

    test('accepte une notification sans catégorie', () {
      // Une catégorie absente n'est pas une raison de perdre l'avis : le titre et le
      // corps suffisent à l'afficher, et la règle d'affichage tranche en faveur de
      // l'affichage quand elle ne reconnaît rien.
      final recue = NotificationRecue.depuis(
        const <String, dynamic>{},
        titre: 'Titre',
        corps: 'Corps',
      );

      expect(recue, isNotNull);
      expect(recue!.categorie, isNull);
    });

    test('rejette une notification sans titre ni corps', () {
      // Rien à montrer : un bandeau vide serait une gêne sans information.
      expect(
        NotificationRecue.depuis(
          const {'categorie': 'activity'},
          titre: null,
          corps: null,
        ),
        isNull,
      );
    });

    test('écarte un lien qui sortirait de l’application', () {
      // Même validation que celle du tap, et pour la même raison : une adresse absolue
      // ou une autorité ouvrirait un site tiers depuis l'intérieur de l'application.
      final recue = NotificationRecue.depuis(
        const {'deepLink': 'https://exemple.test/vol', 'categorie': 'activity'},
        titre: 'Titre',
        corps: 'Corps',
      );

      expect(recue, isNotNull);
      expect(recue!.destination, isNull, reason: 'le lien hostile est écarté');
    });

    test('écarte une autorité déguisée en route', () {
      final recue = NotificationRecue.depuis(
        const {'deepLink': '//exemple.test/vol', 'categorie': 'activity'},
        titre: 'Titre',
        corps: 'Corps',
      );

      expect(recue!.destination, isNull);
    });

    test('ignore un champ qui n’est pas du texte', () {
      final recue = NotificationRecue.depuis(
        const {
          'categorie': 42,
          'evenement': ['x'],
        },
        titre: 'Titre',
        corps: 'Corps',
      );

      expect(recue, isNotNull);
      expect(recue!.categorie, isNull);
      expect(recue.evenementId, isNull);
    });
  });
}
