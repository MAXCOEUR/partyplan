import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/offline/etat_reseau.dart';
import 'package:partyplan/design/components/pp_bandeau_hors_ligne.dart';

import '../aide/monter.dart';

void main() {
  testWidgets('reste invisible en ligne', (tester) async {
    await monterWidget(tester, PpBandeauHorsLigne(etat: EtatReseau()));

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('affiche la date de fraîcheur en JJ/MM/AAAA', (tester) async {
    final etat = EtatReseau()
      ..signalerHorsLigne(fraicheur: DateTime(2026, 8, 20, 14, 32));

    await monterWidget(tester, PpBandeauHorsLigne(etat: etat));

    expect(find.textContaining('20/08/2026'), findsOneWidget);
  });

  testWidgets('annonce les écritures en attente', (tester) async {
    final etat = EtatReseau()
      ..signalerHorsLigne()
      ..majEnAttente(2);

    await monterWidget(tester, PpBandeauHorsLigne(etat: etat));

    expect(find.textContaining('2 modifications'), findsOneWidget);
  });
}
