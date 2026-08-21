import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/sondage.dart';
import 'package:partyplan/core/network/sondages_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/sondages/sondages_page.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

/// Client de sondages en mémoire.
class _SondagesApiDouble implements SondagesApi {
  _SondagesApiDouble(this._page);

  final PageSondages _page;
  final List<String> appels = [];

  @override
  Future<PageSondages> lister(String evenementId) async {
    appels.add('lister');
    return _page;
  }

  @override
  Future<Sondage> voter(
    String evenementId,
    String sondageId, {
    required List<String> optionIds,
  }) async {
    appels.add('voter|$sondageId|${optionIds.join(',')}');
    return _page.sondages.firstWhere((s) => s.id == sondageId);
  }

  @override
  Future<Sondage> creer(
    String evenementId, {
    required String question,
    required List<String> options,
    bool choixMultiple = false,
  }) async {
    appels.add('creer|$question|${options.join(',')}|$choixMultiple');
    return _page.sondages.first;
  }

  @override
  Future<Sondage> clore(String evenementId, String sondageId) async {
    appels.add('clore|$sondageId');
    return _page.sondages.firstWhere((s) => s.id == sondageId);
  }

  @override
  Future<void> supprimer(String evenementId, String sondageId) async {
    appels.add('supprimer|$sondageId');
  }
}

Sondage _sondage({
  required String id,
  String question = 'On commande quoi ?',
  bool clos = false,
  bool jAiVote = false,
  bool choixMultiple = false,
  int votants = 0,
  List<OptionSondage>? options,
}) => Sondage(
  id: id,
  question: question,
  choixMultiple: choixMultiple,
  clos: clos,
  jAiVote: jAiVote,
  votants: votants,
  auteur: 'Lucas',
  creeLe: DateTime(2026, 8, 21, 20),
  options:
      options ??
      const [
        OptionSondage(id: 'o1', libelle: 'Pizza', voix: 0, laMienne: false),
        OptionSondage(id: 'o2', libelle: 'Sushi', voix: 0, laMienne: false),
      ],
);

Future<_SondagesApiDouble> _monter(
  WidgetTester tester,
  List<Sondage> sondages,
) async {
  final api = _SondagesApiDouble(PageSondages(sondages: sondages));

  final conteneur = ProviderContainer(
    overrides: [sondagesApiProvider.overrideWithValue(api)],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const SondagesPage(evenementId: _evenement),
    conteneur: conteneur,
  );

  return api;
}

void main() {
  group('Écran des sondages', () {
    testWidgets('aucun sondage se dit et explique le geste', (tester) async {
      await _monter(tester, const []);

      expect(find.textContaining('Aucun sondage'), findsOneWidget);
    });

    testWidgets('affiche la question et ses réponses', (tester) async {
      await _monter(tester, [_sondage(id: 's1')]);

      expect(find.text('On commande quoi ?'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Sushi'), findsOneWidget);
    });

    testWidgets('voter transmet le choix', (tester) async {
      final api = await _monter(tester, [_sondage(id: 's1')]);

      await tester.tap(find.text('Pizza'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('voter|s1|o1'));
    });

    testWidgets('en choix unique, voter remplace le précédent', (tester) async {
      final api = await _monter(tester, [
        _sondage(
          id: 's1',
          jAiVote: true,
          votants: 1,
          options: const [
            OptionSondage(id: 'o1', libelle: 'Pizza', voix: 1, laMienne: true),
            OptionSondage(id: 'o2', libelle: 'Sushi', voix: 0, laMienne: false),
          ],
        ),
      ]);

      await tester.tap(find.text('Sushi'));
      await tester.pumpAndSettle();

      // Un seul identifiant : le précédent n'est pas conservé.
      expect(api.appels, contains('voter|s1|o2'));
    });

    testWidgets('en choix multiple, cocher ajoute au lieu de remplacer', (
      tester,
    ) async {
      final api = await _monter(tester, [
        _sondage(
          id: 's1',
          question: 'Tu apportes quoi ?',
          choixMultiple: true,
          jAiVote: true,
          votants: 1,
          options: const [
            OptionSondage(id: 'o1', libelle: 'Entrée', voix: 1, laMienne: true),
            OptionSondage(
              id: 'o2',
              libelle: 'Dessert',
              voix: 0,
              laMienne: false,
            ),
          ],
        ),
      ]);

      await tester.tap(find.text('Dessert'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('voter|s1|o1,o2'));
    });

    testWidgets('en choix multiple, décocher retire sans tout perdre', (
      tester,
    ) async {
      final api = await _monter(tester, [
        _sondage(
          id: 's1',
          choixMultiple: true,
          jAiVote: true,
          votants: 1,
          options: const [
            OptionSondage(id: 'o1', libelle: 'Entrée', voix: 1, laMienne: true),
            OptionSondage(
              id: 'o2',
              libelle: 'Dessert',
              voix: 1,
              laMienne: true,
            ),
          ],
        ),
      ]);

      await tester.tap(find.text('Entrée'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('voter|s1|o2'));
    });

    testWidgets('le décompte des votants est annoncé', (tester) async {
      await _monter(tester, [
        _sondage(
          id: 's1',
          votants: 4,
          options: const [
            OptionSondage(id: 'o1', libelle: 'Pizza', voix: 3, laMienne: false),
            OptionSondage(id: 'o2', libelle: 'Sushi', voix: 1, laMienne: false),
          ],
        ),
      ]);

      expect(find.textContaining('4'), findsWidgets);
      // Le décompte par réponse est visible : c'est le résultat qu'on vient chercher.
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('un sondage clos n’accepte plus de vote', (tester) async {
      final api = await _monter(tester, [_sondage(id: 's1', clos: true)]);

      await tester.tap(find.text('Pizza'));
      await tester.pumpAndSettle();

      expect(api.appels.where((a) => a.startsWith('voter')), isEmpty);
      expect(find.textContaining('Clos'), findsOneWidget);
    });

    testWidgets('offre une reprise après une erreur de chargement', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          sondagesProvider(
            _evenement,
          ).overrideWith((ref) => Future.error(Exception('réseau'))),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const SondagesPage(evenementId: _evenement),
        conteneur: conteneur,
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
