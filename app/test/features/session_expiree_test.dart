import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';
import 'package:partyplan/features/auth/connexion_page.dart';

import '../doubles/magasin_local_double.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Session perdue', () {
    testWidgets('la perte de session ramène à l’écran de connexion', (
      tester,
    ) async {
      final conteneur = _conteneurConnecte();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccueilPage), findsOneWidget);

      // Ce que signale le client HTTP quand le renouvellement est définitivement
      // refusé : jeton révoqué, session expirée, compte suspendu.
      conteneur.read(sessionProvider.notifier).sessionPerdue();
      await tester.pumpAndSettle();

      // Sans cette conduite, l'accueil reste affiché avec son erreur d'API, et la
      // seule sortie est d'effacer les données de l'application.
      expect(find.byType(ConnexionPage), findsOneWidget);
      expect(find.byType(AccueilPage), findsNothing);
    });

    testWidgets('un changement de mot de passe imposé ne survit pas à la perte', (
      tester,
    ) async {
      final conteneur = _conteneurConnecte();
      conteneur.read(motDePasseAChangerProvider.notifier).exiger();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      conteneur.read(sessionProvider.notifier).sessionPerdue();
      await tester.pumpAndSettle();

      // Sans cette remise à zéro, le compte suivant serait conduit vers un formulaire
      // de changement de mot de passe qui ne le concerne pas.
      expect(conteneur.read(motDePasseAChangerProvider), isFalse);
      expect(find.byType(ConnexionPage), findsOneWidget);
    });
    testWidgets('la perte de session vide le cache de lecture', (tester) async {
      final magasin = MagasinLocalDouble();
      final conteneur = _conteneurConnecte(magasin: magasin);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      await conteneur.read(cacheLectureProvider).enregistrer('/events', null, [
        {'id': 'e1'},
      ], DateTime(2026, 9, 1));

      conteneur.read(sessionProvider.notifier).sessionPerdue();
      await tester.pumpAndSettle();

      // Le cache contient le contenu d'événements privés. Le laisser en place après une
      // session perdue démentirait la promesse d'événement privé sur un appareil
      // partagé, exactement comme après une déconnexion volontaire.
      expect(magasin.contenu, isEmpty);
    });
  });
}

ProviderContainer _conteneurConnecte({MagasinLocalDouble? magasin}) {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(
          jetonAcces: 'jeton-test',
          jetonRafraichissement: 'rafraichissement-test',
        ),
      ),
      // L'accueil lancerait sinon un véritable appel réseau, dont le délai d'attente
      // survit à la fin du test.
      mesEvenementsProvider.overrideWith((ref) async => []),
      if (magasin != null) magasinLocalProvider.overrideWithValue(magasin),
    ],
  );
  addTearDown(conteneur.dispose);
  return conteneur;
}
