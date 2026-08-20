import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Accueil', () {
    testWidgets('sépare les événements à venir des événements passés', (
      tester,
    ) async {
      await _monter(tester, [
        itemListe(id: 'a', nom: 'Crémaillère'),
        itemListe(id: 'b', nom: 'Nouvel an dernier', estPasse: true),
      ]);

      expect(find.text('À VENIR'), findsOneWidget);
      expect(find.text('PASSÉS'), findsOneWidget);
      expect(find.text('Crémaillère'), findsOneWidget);
      expect(find.text('Nouvel an dernier'), findsOneWidget);
    });

    testWidgets('propose de créer ou de rejoindre quand il n’y a rien', (
      tester,
    ) async {
      await _monter(tester, []);

      expect(find.text('Créer un événement'), findsWidgets);
      expect(find.text('Rejoindre avec un code'), findsOneWidget);
    });

    testWidgets('affiche la synthèse des présences sur chaque carte', (
      tester,
    ) async {
      await _monter(tester, [itemListe(presents: 5, invites: 8)]);

      expect(find.text('5 présents sur 8 invités'), findsOneWidget);
    });

    testWidgets('signale le rôle d’organisateur, pas celui de simple membre', (
      tester,
    ) async {
      await _monter(tester, [
        itemListe(id: 'a', nom: 'La mienne', monRole: RoleMembre.proprietaire),
        itemListe(id: 'b', nom: 'Celle d’un autre'),
      ]);

      expect(find.text('ORGANISATEUR'), findsOneWidget);
    });

    testWidgets('offre une reprise après une erreur de chargement', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
          mesEvenementsProvider.overrideWith(
            (ref) async => throw Exception('réseau'),
          ),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(tester, const AccueilPage(), conteneur: conteneur);

      expect(find.text('Impossible de charger tes événements.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}

Future<void> _monter(
  WidgetTester tester,
  List<EvenementDeLaListe> evenements,
) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      mesEvenementsProvider.overrideWith((ref) async => evenements),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const AccueilPage(), conteneur: conteneur);
}
