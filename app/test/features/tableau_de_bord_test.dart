import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/tableau_de_bord_page.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Tableau de bord', () {
    testWidgets('affiche le nom, la date et le lieu', (tester) async {
      await _monter(tester);

      expect(find.text('Crémaillère chez Léa'), findsOneWidget);
      expect(find.textContaining('12 septembre 2026'), findsOneWidget);
      expect(find.text('12 rue des Lilas, Lyon'), findsOneWidget);
    });

    testWidgets('RG-PRES-01 : pose la question tant qu’il n’y a pas de réponse', (
      tester,
    ) async {
      await _monter(
        tester,
        membres: [membre(nom: 'Moi', statut: StatutPresence.inconnu, cestMoi: true)],
      );

      expect(find.text('Tu viens ?'), findsOneWidget);
    });

    testWidgets('n’insiste plus une fois la réponse donnée', (tester) async {
      await _monter(
        tester,
        membres: [membre(nom: 'Moi', statut: StatutPresence.present, cestMoi: true)],
      );

      expect(find.text('Tu viens ?'), findsNothing);
      expect(find.text('Modifier ma réponse'), findsOneWidget);
    });

    testWidgets('RG-PRES-03 : les peut-être sont annoncés à part', (tester) async {
      await _monter(tester);

      expect(find.text('5 présents sur 8 invités'), findsOneWidget);
      expect(find.text('2 peut-être'), findsOneWidget);
    });

    testWidgets('RG-PRES-04 : les têtes sont un décompte distinct des présents', (
      tester,
    ) async {
      // 5 présents annoncés par le serveur, dont un avec deux accompagnants.
      await _monter(
        tester,
        membres: [
          membre(id: 'm1', nom: 'Léa', accompagnants: 2, cestMoi: true),
          membre(id: 'm2', nom: 'Tom'),
          membre(id: 'm3', nom: 'Zoé'),
          membre(id: 'm4', nom: 'Max'),
          membre(id: 'm5', nom: 'Ana'),
        ],
      );

      // Confondre les deux fausserait toutes les quantités de courses.
      expect(find.text('5 présents sur 8 invités'), findsOneWidget);
      expect(find.text('7 têtes à prévoir'), findsOneWidget);
    });

    testWidgets('la section de partage est cachée à un simple membre', (
      tester,
    ) async {
      await _monter(
        tester,
        membres: [membre(nom: 'Moi', cestMoi: true)],
      );

      expect(find.text('Partager l’invitation'), findsNothing);
    });

    testWidgets('la section de partage apparaît pour un co-organisateur', (
      tester,
    ) async {
      await _monter(
        tester,
        membres: [
          membre(nom: 'Moi', role: RoleMembre.administrateur, cestMoi: true),
        ],
      );

      expect(find.text('Partager l’invitation'), findsOneWidget);
    });

    testWidgets('RG-SEC-02 : hors périmètre, le message est « introuvable »', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
          evenementProvider.overrideWith(
            (ref, id) async => throw Exception('404'),
          ),
          membresProvider.overrideWith((ref, id) async => []),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const TableauDeBordPage(evenementId: 'e1'),
        conteneur: conteneur,
      );

      // « Introuvable » et non « accès refusé » : dire « refusé » révélerait que la
      // ressource existe.
      expect(find.text('Cet événement est introuvable.'), findsOneWidget);
      expect(find.textContaining('refus'), findsNothing);
    });
  });
}

Future<void> _monter(
  WidgetTester tester, {
  ResumeEvenement? evenement,
  List<Membre>? membres,
}) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      evenementProvider.overrideWith((ref, id) async => evenement ?? resume()),
      membresProvider.overrideWith(
        (ref, id) async => membres ?? [membre(nom: 'Moi', cestMoi: true)],
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const TableauDeBordPage(evenementId: 'e1'),
    conteneur: conteneur,
  );
}
