import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/service_notifications.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/core/notifications/notification_recue.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';
import 'package:partyplan/features/evenement/sections/section_notifications.dart';

import '../doubles/activite_api_double.dart';

import '../aide/monter_ecran.dart';

/// RG-NOT-03 : la boîte système ne s'ouvre jamais d'autorité, mais l'invitation à faire
/// le geste est proposée tant que la question n'est pas tranchée.
///
/// Ce qui est irréversible, c'est la boîte système : refusée par réflexe, elle ne se
/// redemande jamais. Une carte dans l'application est réversible, donc elle peut
/// insister — sur l'accueil comme sur le tableau de bord d'une soirée.
void main() {
  group('Consentement aux notifications', () {
    testWidgets('la section propose d’activer quand rien n’a été décidé', (
      tester,
    ) async {
      final service = _ServiceDouble(etat: EtatNotifications.aDemander);
      await _monter(tester, service);

      expect(find.textContaining('notification'), findsWidgets);
      expect(find.byKey(const Key('notifications-activer')), findsOneWidget);
    });

    testWidgets('rien ne s’affiche lorsque c’est déjà accordé', (tester) async {
      final service = _ServiceDouble(etat: EtatNotifications.accorde);
      await _monter(tester, service);

      expect(find.byKey(const Key('notifications-activer')), findsNothing);
    });

    testWidgets('un refus n’est plus redemandé', (tester) async {
      // Un refus système ne peut pas être redemandé par l'application : reproposer le
      // bouton donnerait un geste sans effet, ce qui est pire que ne rien proposer.
      final service = _ServiceDouble(etat: EtatNotifications.refuse);
      await _monter(tester, service);

      expect(find.byKey(const Key('notifications-activer')), findsNothing);
    });

    testWidgets('appuyer demande la permission et enregistre le jeton', (
      tester,
    ) async {
      final service = _ServiceDouble(etat: EtatNotifications.aDemander);
      await _monter(tester, service);

      await tester.tap(find.byKey(const Key('notifications-activer')));
      await tester.pumpAndSettle();

      expect(service.demandes, 1);
    });

    testWidgets('rien ne s’affiche quand Firebase n’est pas configuré', (
      tester,
    ) async {
      // Règle 5 : un clone sans compte Firebase reste utilisable. Proposer un bouton
      // sans effet serait pire que ne rien proposer.
      final service = _ServiceDouble(etat: EtatNotifications.indisponible);
      await _monter(tester, service);

      expect(find.byKey(const Key('notifications-activer')), findsNothing);
    });
  });

  group('Consentement depuis l’accueil', () {
    testWidgets('la carte est proposée tant que la question n’est pas tranchée', (
      tester,
    ) async {
      // Quelqu'un qui n'ouvre jamais le tableau de bord d'une soirée ne voyait jamais
      // la proposition, et n'avait aucune notification sans savoir pourquoi.
      await _monterAccueil(tester, EtatNotifications.aDemander);

      expect(find.byKey(const Key('notifications-activer')), findsOneWidget);
    });

    testWidgets('elle disparaît une fois la question tranchée', (tester) async {
      await _monterAccueil(tester, EtatNotifications.accorde);

      expect(find.byKey(const Key('notifications-activer')), findsNothing);
    });
  });
}

Future<void> _monterAccueil(WidgetTester tester, EtatNotifications etat) async {
  final conteneur = ProviderContainer(
    overrides: [
      serviceNotificationsProvider.overrideWithValue(
        _ServiceDouble(etat: etat),
      ),
      mesEvenementsProvider.overrideWith((ref) async => const []),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const AccueilPage(), conteneur: conteneur);
}

Future<void> _monter(WidgetTester tester, ServiceNotifications service) async {
  final conteneur = ProviderContainer(
    overrides: [
      serviceNotificationsProvider.overrideWithValue(service),
      // Le tableau de bord porte désormais un aperçu du fil d'activité :
      // sans cette substitution, il partirait chercher le réseau.
      activiteApiProvider.overrideWithValue(ActiviteApiDouble()),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: SectionNotifications()),
    conteneur: conteneur,
  );
}

class _ServiceDouble implements ServiceNotifications {
  _ServiceDouble({required this.etat});

  final EtatNotifications etat;
  int demandes = 0;

  @override
  Future<EtatNotifications> etatCourant() async => etat;

  @override
  Future<void> demanderEtEnregistrer() async => demandes++;

  @override
  Future<void> retirerAppareilCourant() async {}

  @override
  Future<void> ecouterRafraichissements() async {}

  @override
  Future<void> ecouterOuvertures(
    void Function(String destination) aller,
  ) async {}

  @override
  Future<void> ecouterPremierPlan(
    void Function(NotificationRecue recue) montrer,
  ) async {}

  @override
  Future<void> reinscrireAppareil() async {}
}
