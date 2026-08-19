import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/features/rejoindre/rejoindre_page.dart';

void main() {
  group('Routage', () {
    test('la route d’invitation se construit depuis un jeton', () {
      expect(PpRoutes.versRejoindre('ABC123'), '/join/ABC123');
    });

    test('la route d’événement se construit depuis un identifiant', () {
      expect(PpRoutes.versEvenement('0198-abcd'), '/events/0198-abcd');
    });

    testWidgets('l’accès direct à un lien d’invitation ouvre le parcours', (
      tester,
    ) async {
      final routeur = creerRouteur();
      // Un invité arrive toujours par un lien : cette route doit fonctionner en accès
      // direct, sans passer par l'accueil (EF-INV-01).
      routeur.go('/join/PLAN-8J4K');

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: routeur)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RejoindrePage), findsOneWidget);
    });

    testWidgets('l’application démarre sur l’accueil', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: PartyPlanApp()));
      await tester.pumpAndSettle();

      expect(find.text('PartyPlan'), findsOneWidget);
    });
  });
}
