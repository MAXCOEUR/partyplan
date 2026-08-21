import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/design/components/pp_barre_evenement.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

Future<void> _monter(WidgetTester tester, {ResumeEvenement? resume}) async {
  final conteneur = ProviderContainer(
    overrides: [
      evenementProvider(_evenement).overrideWith(
        (ref) async =>
            resume ??
            ResumeEvenement(
              id: _evenement,
              nom: 'Crémaillère chez Léa',
              description: null,
              debut: DateTime(2026, 9, 12, 20),
              fin: null,
              adresse: null,
              imageCouverture: null,
              nombreMembres: 8,
              nombrePresents: 5,
              nombrePeutEtre: 1,
              adhesionsOuvertes: true,
            ),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(
      appBar: PpBarreEvenement(evenementId: _evenement, section: 'SONDAGES'),
      body: SizedBox.shrink(),
    ),
    conteneur: conteneur,
  );
}

void main() {
  group('PpBarreEvenement', () {
    testWidgets('nomme l’événement et la section ouverte', (tester) async {
      // « Sondages » seul ne dit pas de quelle soirée il s'agit : on peut être membre
      // de plusieurs, et l'écran serait le même pour toutes.
      await _monter(tester);

      expect(find.text('Crémaillère chez Léa'), findsOneWidget);
      expect(find.textContaining('SONDAGES'), findsOneWidget);
    });

    testWidgets('rappelle l’état des présences', (tester) async {
      await _monter(tester);

      expect(find.textContaining('5 présents sur 8'), findsOneWidget);
    });

    testWidgets('un retour est proposé', (tester) async {
      await _monter(tester);

      expect(find.byType(BackButton), findsOneWidget);
    });
  });
}
