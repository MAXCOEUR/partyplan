import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/invitation.dart';
import 'package:partyplan/core/network/evenements_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/rejoindre/adhesion_page.dart';
import 'package:partyplan/features/rejoindre/apercu_invitation_page.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Aperçu d’invitation', () {
    testWidgets('RG-INV-04 : ni liste nominative, ni dépenses', (tester) async {
      await _monterApercu(tester, apercu(participants: 8));

      expect(find.text('Crémaillère chez Léa'), findsOneWidget);
      expect(find.text('8 participants'), findsOneWidget);
      // Le modèle ApercuInvitation ne porte aucun nom de membre : ce qui n'existe pas
      // ne peut pas fuiter.
      expect(find.text('Léa'), findsNothing);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets('EF-INV-06 : l’aperçu reste lisible quand les arrivées sont fermées', (
      tester,
    ) async {
      await _monterApercu(tester, apercu(adhesionsOuvertes: false));

      // L'aperçu explique le refus au lieu de renvoyer une erreur opaque.
      expect(find.text('Crémaillère chez Léa'), findsOneWidget);
      expect(
        find.text('L’organisateur a fermé les nouvelles arrivées.'),
        findsOneWidget,
      );
      expect(find.text('Participer'), findsNothing);
    });

    testWidgets('un membre déjà inscrit va directement à l’événement', (
      tester,
    ) async {
      await _monterApercu(tester, apercu(dejaMembre: true));

      expect(find.text('Voir l’événement'), findsOneWidget);
      expect(find.text('Participer'), findsNothing);
    });
  });

  group('Adhésion sans compte', () {
    testWidgets('RG-INV-05 : deux écrans, prénom puis statut', (tester) async {
      await _monterAdhesion(tester);

      expect(find.text('Comment tu t’appelles ?'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Léa');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Tu viens ?'), findsOneWidget);
    });

    testWidgets('EF-INV-04 : aucune saisie d’adresse n’est demandée', (
      tester,
    ) async {
      await _monterAdhesion(tester);

      expect(find.textContaining('e-mail'), findsNothing);
      expect(find.textContaining('mail'), findsNothing);
      expect(find.text('Pas besoin de créer un compte.'), findsOneWidget);
    });

    testWidgets('un prénom vide est refusé sans appel réseau', (tester) async {
      await _monterAdhesion(tester);

      // Par le bouton : sans champ actif, aucune action clavier n'est délivrée.
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      expect(find.text('Indique ton prénom.'), findsOneWidget);
      expect(find.text('Tu viens ?'), findsNothing);
    });

    testWidgets('les cinq statuts sont proposés à l’étape 2', (tester) async {
      await _monterAdhesion(tester);
      await tester.enterText(find.byType(TextFormField), 'Léa');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      for (final cle in ['Going', 'Maybe', 'Late', 'EarlyLeave', 'NotGoing']) {
        expect(find.byKey(ValueKey('adhesion-$cle')), findsOneWidget);
      }
    });
  });

  group('Code court', () {
    test('la saisie est tolérante', () {
      for (final saisie in [
        'PLAN-K7M2X9',
        'plan-k7m2x9',
        ' plan k7m 2x9 ',
        'K7M2X9',
        'k7m-2x9',
      ]) {
        expect(EvenementsApi.normaliserCode(saisie), 'K7M2X9', reason: saisie);
      }
    });
  });
}

Future<void> _monterApercu(WidgetTester tester, ApercuInvitation donnees) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      apercuInvitationProvider.overrideWith((ref, cle) async => donnees),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const ApercuInvitationPage(jeton: 'JETON'),
    conteneur: conteneur,
  );
}

Future<void> _monterAdhesion(WidgetTester tester) async {
  final conteneur = ProviderContainer(
    overrides: [sessionStoreProvider.overrideWithValue(SessionStoreDouble())],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const AdhesionPage(jeton: 'JETON'),
    conteneur: conteneur,
  );
}
