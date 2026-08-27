import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/service_notifications.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/sections/section_notifications.dart';

import '../doubles/activite_api_double.dart';

import '../aide/monter_ecran.dart';

/// RG-NOT-03 : le consentement est demandé au moment utile, pas au premier lancement.
///
/// Le moment utile est l'entrée dans une soirée : c'est là qu'on acquiert pour la
/// première fois quelque chose à être notifié. Demander au lancement fait refuser par
/// réflexe, et un refus système ne se redemande pas.
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
  });
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
}
