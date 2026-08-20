import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/offline/etat_reseau.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/design/components/pp_bandeau_hors_ligne.dart';

import '../aide/monter_ecran.dart';

void main() {
  testWidgets('reste invisible en ligne', (tester) async {
    await _monter(tester, EtatReseau());

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('affiche la date de fraîcheur en JJ/MM/AAAA', (tester) async {
    await _monter(
      tester,
      EtatReseau()..signalerHorsLigne(fraicheur: DateTime(2026, 8, 20, 14, 32)),
    );

    expect(find.textContaining('20/08/2026'), findsOneWidget);
  });

  testWidgets('annonce les écritures en attente', (tester) async {
    await _monter(
      tester,
      EtatReseau()
        ..signalerHorsLigne()
        ..majEnAttente(2),
    );

    expect(find.textContaining('2 modifications'), findsOneWidget);
  });

  testWidgets('se met à jour quand l’état change, sans reconstruire l’écran', (
    tester,
  ) async {
    final etat = EtatReseau();
    await _monter(tester, etat);

    expect(find.byType(Card), findsNothing);

    etat.signalerHorsLigne(fraicheur: DateTime(2026, 8, 20, 14, 32));
    await tester.pumpAndSettle();

    // Le bandeau s'abonne lui-même : l'écran appelant n'a rien à observer, et ne se
    // reconstruit donc pas à chaque requête réseau.
    expect(find.textContaining('20/08/2026'), findsOneWidget);
  });
}

Future<void> _monter(WidgetTester tester, EtatReseau etat) async {
  final conteneur = ProviderContainer(
    overrides: [etatReseauProvider.overrideWithValue(etat)],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: PpBandeauHorsLigne()),
    conteneur: conteneur,
  );
}
