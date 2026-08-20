import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/parametres_evenement_page.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Paramètres de l’événement', () {
    testWidgets('RG-ROLE-02 : le transfert précède « quitter »', (
      tester,
    ) async {
      await _monter(tester, monRole: RoleMembre.proprietaire);

      final transfert = tester.getTopLeft(find.text('Transférer la propriété'));
      final quitter = tester.getTopLeft(find.text('Quitter l’événement'));

      // Découvrir l'interdiction après avoir appuyé sur « quitter » serait un
      // cul-de-sac.
      expect(transfert.dy, lessThan(quitter.dy));
    });

    testWidgets('un propriétaire ne quitte pas sans transférer', (
      tester,
    ) async {
      await _monter(tester, monRole: RoleMembre.proprietaire);

      await tester.tap(find.text('Quitter l’événement'));
      await tester.pumpAndSettle();

      expect(
        find.text('Transfère d’abord la propriété à quelqu’un d’autre.'),
        findsOneWidget,
      );
    });

    testWidgets('le transfert ne propose que des membres avec compte', (
      tester,
    ) async {
      await _monter(
        tester,
        monRole: RoleMembre.proprietaire,
        membres: [
          membre(
            id: 'moi',
            nom: 'Moi',
            role: RoleMembre.proprietaire,
            cestMoi: true,
          ),
          membre(id: 'lea', nom: 'Léa'),
          membre(id: 'inv', nom: 'Invité', aUnCompte: false),
        ],
      );

      await tester.tap(find.text('Transférer la propriété'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('repreneur-lea')), findsOneWidget);
      expect(find.byKey(const ValueKey('repreneur-inv')), findsNothing);
      expect(
        find.textContaining(
          'un invité sans compte ne retrouverait pas l’événement',
        ),
        findsOneWidget,
      );
    });

    testWidgets('RG-ROLE-01 : un co-organisateur ne supprime pas', (
      tester,
    ) async {
      await _monter(tester, monRole: RoleMembre.administrateur);

      expect(find.text('Supprimer l’événement'), findsNothing);
      // Il peut en revanche modifier l'événement.
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('un simple membre ne modifie rien', (tester) async {
      await _monter(tester);

      expect(find.text('Enregistrer'), findsNothing);
      expect(find.text('Transférer la propriété'), findsNothing);
      expect(find.text('Quitter l’événement'), findsOneWidget);
    });

    testWidgets('EF-EVT-07 : la suppression exige la saisie du nom', (
      tester,
    ) async {
      await _monter(tester, monRole: RoleMembre.proprietaire);

      await tester.tap(find.text('Supprimer l’événement'));
      await tester.pumpAndSettle();

      final bouton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Supprimer l’événement'),
      );
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Crémaillère chez Léa',
      );
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(bouton).onPressed, isNotNull);
    });
  });
}

Future<void> _monter(
  WidgetTester tester, {
  RoleMembre monRole = RoleMembre.membre,
  List<Membre>? membres,
}) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      evenementProvider.overrideWith((ref, id) async => resume()),
      membresProvider.overrideWith(
        (ref, id) async =>
            membres ??
            [membre(id: 'moi', nom: 'Moi', role: monRole, cestMoi: true)],
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const ParametresEvenementPage(evenementId: 'e1'),
    conteneur: conteneur,
  );
}
