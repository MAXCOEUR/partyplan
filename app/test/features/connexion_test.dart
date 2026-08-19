import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/auth/connexion_page.dart';
import 'package:partyplan/features/auth/inscription_page.dart';

import '../doubles/session_store_double.dart';

void main() {
  group('Écran de connexion', () {
    testWidgets('affiche les deux champs et le bouton', (tester) async {
      await _monter(tester);

      expect(find.text('Adresse e-mail'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });

    testWidgets('refuse une soumission vide sans appeler le réseau', (
      tester,
    ) async {
      await _monter(tester);

      await _appuyer(tester, find.text('Se connecter'));

      // La validation locale évite un aller-retour pour une faute évidente.
      expect(find.text('Indique ton adresse e-mail.'), findsOneWidget);
      expect(find.text('Indique ton mot de passe.'), findsOneWidget);
    });

    testWidgets('signale une adresse manifestement invalide', (tester) async {
      await _monter(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'pas-une-adresse',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Trombone-Nuage-42x',
      );
      await _appuyer(tester, find.text('Se connecter'));

      expect(
        find.text('Cette adresse ne ressemble pas à une adresse e-mail.'),
        findsOneWidget,
      );
    });

    testWidgets('mène à l’inscription', (tester) async {
      await _monter(tester);

      // La surface de test est plus courte qu'un téléphone : le lien est sous la ligne
      // de flottaison et doit être amené à l'écran avant l'appui.
      await _appuyer(tester, find.text('Créer un compte'));

      expect(find.byType(InscriptionPage), findsOneWidget);
    });

    testWidgets('ne déborde pas sur un écran étroit', (tester) async {
      // 320 points de large : le plus petit écran encore en service. Un débordement ici
      // masquerait le lien d'inscription, c'est-à-dire le parcours d'acquisition.
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _monter(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Créer un compte'), findsOneWidget);
    });
  });

  group('Écran d’inscription', () {
    testWidgets('énonce la règle de mot de passe avant la faute', (
      tester,
    ) async {
      await _monter(tester, route: PpRoutes.inscription);

      // La règle est visible d'emblée : la découvrir en message d'erreur est une
      // mauvaise façon de la communiquer.
      expect(find.textContaining('12 caractères minimum'), findsOneWidget);
    });

    testWidgets('refuse un mot de passe trop court en local', (tester) async {
      await _monter(tester, route: PpRoutes.inscription);

      await tester.enterText(find.byType(TextFormField).at(0), 'Maxence');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'max@partyplan.local',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'court');
      await _appuyer(tester, find.text('Créer mon compte'));

      expect(find.textContaining('caractère(s)'), findsOneWidget);
    });
  });
}

/// Amène un élément à l'écran puis appuie dessus.
///
/// La surface de test par défaut est plus courte qu'un téléphone : sans défilement,
/// l'appui porte hors du viewport et n'a aucun effet, ce qui produit un échec trompeur.
Future<void> _appuyer(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

Future<void> _monter(
  WidgetTester tester, {
  String route = PpRoutes.connexion,
}) async {
  final conteneur = ProviderContainer(
    overrides: [sessionStoreProvider.overrideWithValue(SessionStoreDouble())],
  );
  addTearDown(conteneur.dispose);

  final routeur = conteneur.read(routeurProvider);
  routeur.go(route);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp.router(routerConfig: routeur),
    ),
  );
  await tester.pumpAndSettle();

  if (route == PpRoutes.connexion) {
    expect(find.byType(ConnexionPage), findsOneWidget);
  }
}
