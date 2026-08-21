import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/article_course.dart';
import 'package:partyplan/core/models/depense.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/coquille_evenement.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

final _resume = ResumeEvenement(
  id: _evenement,
  nom: 'Crémaillère chez Léa',
  description: null,
  debut: DateTime(2026, 9, 12, 20),
  fin: null,
  adresse: '12 rue des Lilas',
  imageCouverture: null,
  nombreMembres: 8,
  nombrePresents: 5,
  nombrePeutEtre: 1,
  adhesionsOuvertes: true,
);

Future<void> _monter(WidgetTester tester, {required Size taille}) async {
  final conteneur = ProviderContainer(
    overrides: [
      evenementProvider(_evenement).overrideWith((ref) async => _resume),
      membresProvider(_evenement).overrideWith((ref) async => []),
      // Chaque onglet de la coquille est construit d'emblée par l'IndexedStack : un
      // provider laissé au vrai réseau lance un appel dont le délai d'attente survit
      // à la fin du test.
      filDiscussionProvider(_evenement).overrideWith(
        (ref) async => const FilDiscussion(messages: []),
      ),
      depensesProvider(_evenement).overrideWith(
        (ref) async =>
            const PageDepenses(total: 0, maPart: 0, depenses: []),
      ),
      listeCoursesProvider(_evenement).overrideWith(
        (ref) async => const ListeCourses(
          avancement: AvancementCourses(total: 0, pris: 0, achetes: 0),
          articles: [],
        ),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const CoquilleEvenement(eventId: _evenement),
    conteneur: conteneur,
  );

  // Posée après le montage : `monterEcran` impose sa propre surface, et la régler
  // avant reviendrait à tester une taille qui n'est pas celle du rendu.
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpAndSettle();
}

void main() {
  group('Coquille d’événement', () {
    testWidgets('nomme l’événement sur tous ses onglets', (tester) async {
      // « Courses » en titre ne dit pas de quelle soirée il s'agit. Une personne
      // membre de trois événements ne sait plus où elle est.
      await _monter(tester, taille: const Size(400, 900));

      await tester.tap(find.text('Courses').first);
      await tester.pumpAndSettle();

      expect(find.text('Crémaillère chez Léa'), findsWidgets);
    });

    testWidgets('la discussion mène aux sondages et aux épingles', (
      tester,
    ) async {
      // Les deux prolongent la conversation : les chercher sous « Plus » oblige à
      // quitter le fil pour y revenir.
      await _monter(tester, taille: const Size(400, 900));

      await tester.tap(find.text('Discussion').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('acces-sondages')), findsOneWidget);
      expect(find.byKey(const Key('acces-epingles')), findsOneWidget);
    });

    testWidgets('les autres onglets n’affichent pas ces raccourcis', (
      tester,
    ) async {
      // Ils n'ont de sens qu'au-dessus du fil : ailleurs, ce serait deux icônes de
      // plus dans une barre déjà chargée.
      await _monter(tester, taille: const Size(400, 900));

      expect(find.byKey(const Key('acces-sondages')), findsNothing);
    });

    testWidgets('sur téléphone, la navigation reste en bas', (tester) async {
      await _monter(tester, taille: const Size(400, 900));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('sur écran large, la navigation passe sur le côté', (
      tester,
    ) async {
      // Une barre basse étalée sur 1280 px laisse le pouce à un endroit et les
      // libellés à un autre : sur un écran de bureau, la place est à gauche.
      await _monter(tester, taille: const Size(1280, 900));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
