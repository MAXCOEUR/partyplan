import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/bandeau_notification.dart';
import 'package:partyplan/core/notifications/notification_recue.dart';
import 'package:partyplan/design/components/pp_bandeau_notification.dart';

import '../aide/monter_ecran.dart';

/// Le bandeau qui annonce une notification reçue pendant que l'application est ouverte.
///
/// Ce que ces tests tiennent : il paraît, il porte le texte reçu, il conduit à la
/// destination, il s'efface. Ce qu'il faut afficher se décide ailleurs — c'est la
/// règle d'affichage, éprouvée seule.
void main() {
  group('Bandeau de notification', () {
    testWidgets('ne montre rien tant qu’aucune notification n’arrive', (
      tester,
    ) async {
      final conteneur = ProviderContainer();
      addTearDown(conteneur.dispose);

      await _monter(tester, conteneur);

      expect(find.byKey(const Key('bandeau-notification')), findsNothing);
    });

    testWidgets('affiche le titre et le corps reçus', (tester) async {
      final conteneur = ProviderContainer();
      addTearDown(conteneur.dispose);
      await _monter(tester, conteneur);

      conteneur.read(bandeauNotificationProvider.notifier).montrer(_depense);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Nouvelle dépense'), findsOneWidget);
      expect(find.text('Maxence a ajouté « Courses »'), findsOneWidget);
    });

    testWidgets('taper ouvre la destination et efface le bandeau', (
      tester,
    ) async {
      final destinations = <String>[];
      final conteneur = ProviderContainer();
      addTearDown(conteneur.dispose);
      await _monter(tester, conteneur, aller: destinations.add);

      conteneur.read(bandeauNotificationProvider.notifier).montrer(_depense);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('bandeau-notification')));
      await tester.pumpAndSettle();

      expect(destinations, ['/events/42/depenses']);
      expect(conteneur.read(bandeauNotificationProvider), isNull);
    });

    testWidgets('une notification sans destination ne navigue nulle part', (
      tester,
    ) async {
      final destinations = <String>[];
      final conteneur = ProviderContainer();
      addTearDown(conteneur.dispose);
      await _monter(tester, conteneur, aller: destinations.add);

      conteneur
          .read(bandeauNotificationProvider.notifier)
          .montrer(
            const NotificationRecue(
              titre: 'Solde',
              corps: 'Tu dois 18,40 €',
              categorie: 'balance.due',
              evenementId: null,
              destination: null,
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('bandeau-notification')));
      await tester.pumpAndSettle();

      expect(destinations, isEmpty);
      expect(
        conteneur.read(bandeauNotificationProvider),
        isNull,
        reason: 'le bandeau s’efface quand même : il a été vu',
      );
    });

    testWidgets('s’efface seul au bout de quelques secondes', (tester) async {
      final conteneur = ProviderContainer();
      addTearDown(conteneur.dispose);
      await _monter(tester, conteneur);

      conteneur.read(bandeauNotificationProvider.notifier).montrer(_depense);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('bandeau-notification')), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(conteneur.read(bandeauNotificationProvider), isNull);
    });

    testWidgets('une notification chasse la précédente', (tester) async {
      // Aucune file : empiler des bandeaux par-dessus l'écran qu'on lit reproduirait le
      // bruit que la règle de suppression cherche à éviter.
      final conteneur = ProviderContainer();
      addTearDown(conteneur.dispose);
      await _monter(tester, conteneur);
      final notifier = conteneur.read(bandeauNotificationProvider.notifier);

      notifier.montrer(_depense);
      await tester.pump();
      notifier.montrer(
        const NotificationRecue(
          titre: 'Lucas',
          corps: 'On arrive.',
          categorie: 'discussion.message',
          evenementId: '42',
          destination: '/events/42',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Nouvelle dépense'), findsNothing);
      expect(find.text('Lucas'), findsOneWidget);
      expect(find.byKey(const Key('bandeau-notification')), findsOneWidget);
    });

    testWidgets('se ferme d’un glissement vers le haut', (tester) async {
      final conteneur = ProviderContainer();
      addTearDown(conteneur.dispose);
      await _monter(tester, conteneur);

      conteneur.read(bandeauNotificationProvider.notifier).montrer(_depense);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(
        find.byKey(const Key('bandeau-notification')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(conteneur.read(bandeauNotificationProvider), isNull);
    });
  });
}

const _depense = NotificationRecue(
  titre: 'Nouvelle dépense',
  corps: 'Maxence a ajouté « Courses »',
  categorie: 'expense.new',
  evenementId: '42',
  destination: '/events/42/depenses',
);

Future<void> _monter(
  WidgetTester tester,
  ProviderContainer conteneur, {
  void Function(String destination)? aller,
}) => monterEcran(
  tester,
  PpBandeauNotification(
    aller: aller ?? (_) {},
    child: const Scaffold(body: Center(child: Text('écran'))),
  ),
  conteneur: conteneur,
);
