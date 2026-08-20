import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/creation_evenement_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Assistant de création', () {
    testWidgets('démarre à l’étape 1 sur la question du nom', (tester) async {
      await _monter(tester);

      expect(find.text('Ça s’appelle comment ?'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('refuse de passer à l’étape 2 sans nom', (tester) async {
      await _monter(tester);

      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      expect(find.text('Donne un nom à ton événement.'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('le retour à l’étape précédente ne perd pas la saisie', (
      tester,
    ) async {
      await _monter(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      // Appui direct sur le premier segment de la barre de progression.
      await tester.tap(find.byKey(const ValueKey('etape-1')));
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Crémaillère'), findsOneWidget);
    });

    testWidgets('« Créer » est actif dès l’étape 2', (tester) async {
      await _monter(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      // Nom et date suffisent à l'API : imposer l'étape 3 ferait de la description un
      // champ obligatoire de fait.
      expect(find.text('Créer l’événement'), findsOneWidget);
    });

    testWidgets('la barre de progression ne mène pas au-delà sans nom', (
      tester,
    ) async {
      await _monter(tester);

      // La clé porte sur l'InkWell lui-même : un segment inaccessible n'a pas de
      // rappel d'appui, il n'est pas seulement grisé.
      final segment = tester.widget<InkWell>(
        find.byKey(const ValueKey('etape-2')),
      );

      expect(segment.onTap, isNull);
    });

    testWidgets('NF-A11Y-02 : chaque segment mesure au moins 44 points', (
      tester,
    ) async {
      await _monter(tester);

      for (var i = 1; i <= 3; i++) {
        final taille = tester.getSize(find.byKey(ValueKey('etape-$i')));
        expect(taille.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('NF-A11Y-03 : chaque segment porte un libellé sémantique', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _monter(tester);

      expect(find.bySemanticsLabel('Aller à l’étape 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Aller à l’étape 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Aller à l’étape 3'), findsOneWidget);

      handle.dispose();
    });
  });
}

Future<void> _monter(WidgetTester tester) async {
  final conteneur = ProviderContainer(
    overrides: [sessionStoreProvider.overrideWithValue(SessionStoreDouble())],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const CreationEvenementPage(),
    conteneur: conteneur,
  );
}
