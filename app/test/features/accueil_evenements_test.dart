import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/design/components/pp_date_pastille.dart';
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
      // Le nom paraît deux fois : dans l'annonce de la prochaine soirée et sur son
      // carton.
      expect(find.text('Crémaillère'), findsWidgets);
      expect(find.text('Nouvel an dernier'), findsOneWidget);
    });

    testWidgets('propose de créer ou de rejoindre quand il n’y a rien', (
      tester,
    ) async {
      await _monter(tester, []);

      expect(find.text('Créer un événement'), findsWidgets);
      expect(find.text('Rejoindre avec un code'), findsOneWidget);
    });

    testWidgets('met la prochaine soirée en avant, avec son décompte', (
      tester,
    ) async {
      // L'accueil d'une application de soirées doit répondre à « c'est bientôt ? »
      // avant tout le reste. Une liste plate ne répond à rien.
      await _monter(tester, [
        itemListe(
          id: 'a',
          nom: 'Crémaillère',
          debut: DateTime.now().add(const Duration(days: 11, hours: 2)),
        ),
        itemListe(
          id: 'b',
          nom: 'Plus tard',
          debut: DateTime.now().add(const Duration(days: 40)),
        ),
      ]);

      expect(find.textContaining('Dans 11 jours'), findsOneWidget);
      // La soirée annoncée est la plus proche, pas la première venue.
      expect(find.text('Crémaillère'), findsWidgets);
    });

    testWidgets('sans soirée à venir, aucun décompte n’est affiché', (
      tester,
    ) async {
      await _monter(tester, [
        itemListe(id: 'a', nom: 'Nouvel an dernier', estPasse: true),
      ]);

      expect(find.textContaining('Dans'), findsNothing);
    });

    testWidgets('porte la date en pastille, lisible sans lire', (tester) async {
      // « C'est quand ? » est la première question devant une liste de soirées : la
      // date noyée dans une ligne de texte oblige à lire pour l'obtenir.
      await _monter(tester, [
        itemListe(id: 'a', nom: 'Crémaillère', debut: DateTime(2026, 9, 12, 20)),
      ]);

      expect(find.byType(PpDatePastille), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('sept.'), findsOneWidget);
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

      expect(
        find.text('Impossible de charger tes événements.'),
        findsOneWidget,
      );
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
