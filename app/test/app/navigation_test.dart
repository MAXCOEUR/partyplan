import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/models/article_course.dart';
import 'package:partyplan/core/models/depense.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/models/sondage.dart';
import 'package:partyplan/core/providers.dart';

import '../aide/fabriques.dart';
import '../doubles/fil_discussion_double.dart';
import '../doubles/session_store_double.dart';

const _evenement = 'ev-1';

ProviderContainer _conteneur() {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(jetonAcces: 'jeton', jetonRafraichissement: 'r'),
      ),
      mesEvenementsProvider.overrideWith(
        (ref) async => [itemListe(id: _evenement, nom: 'Soirée test')],
      ),
      evenementProvider(_evenement).overrideWith((ref) async => resume()),
      membresProvider(_evenement).overrideWith((ref) async => []),
      listeCoursesProvider(_evenement).overrideWith(
        (ref) async => const ListeCourses(
          avancement: AvancementCourses(total: 0, pris: 0, achetes: 0),
          articles: [],
        ),
      ),
      depensesProvider(_evenement).overrideWith(
        (ref) async => const PageDepenses(total: 0, maPart: 0, depenses: []),
      ),
      filDiscussionProvider(
        _evenement,
      ).overrideWith(() => FilFige(const FilDiscussion(messages: []))),
      sondagesProvider(
        _evenement,
      ).overrideWith((ref) async => const PageSondages(sondages: [])),
      epinglesProvider(_evenement).overrideWith(
        (ref) async => const PageEpingles(dossiers: [], epingles: []),
      ),
    ],
  );
  addTearDown(conteneur.dispose);
  return conteneur;
}

void main() {
  group('Navigation', () {
    testWidgets('ouvrir un événement inscrit son adresse', (tester) async {
      // Sur le web, l'adresse est la mémoire de navigation : si elle ne suit pas, le
      // bouton « précédent » du navigateur ramène à la page d'entrée au lieu de
      // revenir à l'écran précédent.
      final conteneur = _conteneur();
      final routeur = conteneur.read(routeurProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      routeur.push(PpRoutes.versEvenement(_evenement));
      await tester.pumpAndSettle();

      expect(routeur.state.uri.toString(), PpRoutes.versEvenement(_evenement));
    });

    testWidgets('les écrans annexes ont chacun leur adresse', (tester) async {
      final conteneur = _conteneur();
      final routeur = conteneur.read(routeurProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final chemin in [
        PpRoutes.versSondages(_evenement),
        PpRoutes.versEpingles(_evenement),
        PpRoutes.versReglements(_evenement),
      ]) {
        routeur.push(chemin);
        await tester.pumpAndSettle();

        expect(routeur.state.uri.toString(), chemin);
      }
    });

    testWidgets('sans pile, revenir remonte à l’événement', (tester) async {
      // Après un rechargement de page, ou en arrivant par un lien direct, il n'y a
      // rien à dépiler : le retour renvoyait alors à la liste des soirées, en faisant
      // perdre l'événement dans lequel on se trouvait.
      final conteneur = _conteneur();
      final routeur = conteneur.read(routeurProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      // `go` remplace la pile : c'est l'état d'une page ouverte directement.
      routeur.go(PpRoutes.versSondages(_evenement));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(routeur.state.uri.toString(), PpRoutes.versEvenement(_evenement));
    });

    testWidgets('le retour du système remonte aussi à l’événement', (
      tester,
    ) async {
      // Le bouton matériel d'Android et le « précédent » du navigateur ne passent pas
      // par le bouton affiché : ils demandent un pop au routeur. Sans pile, celui-ci
      // n'a rien à dépiler — l'application se refermait sur Android, et le navigateur
      // quittait vers la page d'entrée.
      final conteneur = _conteneur();
      final routeur = conteneur.read(routeurProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      routeur.go(PpRoutes.versSondages(_evenement));
      await tester.pumpAndSettle();

      // Ce que déclenchent le bouton matériel et le « précédent » du navigateur.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(routeur.state.uri.toString(), PpRoutes.versEvenement(_evenement));
    });

    testWidgets('chaque écran annexe remonte à son parent', (tester) async {
      // La règle vaut pour tous : un écran atteint depuis un autre ne doit jamais
      // renvoyer à la liste des soirées, ni fermer l'application.
      final conteneur = _conteneur();
      final routeur = conteneur.read(routeurProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      final attendus = {
        PpRoutes.versSondages(_evenement): PpRoutes.versEvenement(_evenement),
        PpRoutes.versEpingles(_evenement): PpRoutes.versEvenement(_evenement),
        PpRoutes.versReglements(_evenement): PpRoutes.versEvenement(_evenement),
        PpRoutes.versInvites(_evenement): PpRoutes.versEvenement(_evenement),
        PpRoutes.profil: PpRoutes.accueil,
      };

      for (final entree in attendus.entries) {
        routeur.go(entree.key);
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(
          routeur.state.uri.toString(),
          entree.value,
          reason: 'depuis ${entree.key}',
        );
      }
    });

    testWidgets('revenir ramène à l’écran précédent, pas à l’accueil', (
      tester,
    ) async {
      final conteneur = _conteneur();
      final routeur = conteneur.read(routeurProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      routeur.push(PpRoutes.versEvenement(_evenement));
      await tester.pumpAndSettle();
      routeur.push(PpRoutes.versSondages(_evenement));
      await tester.pumpAndSettle();

      routeur.pop();
      await tester.pumpAndSettle();

      expect(routeur.state.uri.toString(), PpRoutes.versEvenement(_evenement));
    });
  });
}
