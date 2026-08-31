import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/avis.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/parametres_notifications_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/avis_api_double.dart';

/// Catégories simples de l'écran, hors discussion (rendue par un `SegmentedButton`).
const _categoriesSimples = [
  'invitation.answer',
  'event.changed',
  'invitation.pending',
  'shopping.unclaimed',
  'event.starting_soon',
  'balance.due',
  'activity',
  'poll.new',
  'expense.new',
];

List<PreferenceDeSoiree> _toutesActives() => [
  for (final categorie in _categoriesSimples)
    PreferenceDeSoiree(categorie: categorie, actif: true, estUnEcart: false),
  const PreferenceDeSoiree(
    categorie: 'discussion.message',
    actif: true,
    estUnEcart: false,
  ),
  const PreferenceDeSoiree(
    categorie: 'discussion.mention',
    actif: true,
    estUnEcart: false,
  ),
];

late AvisApiDouble _api;

Future<void> _monter(
  WidgetTester tester, {
  List<PreferenceDeSoiree>? preferences,
  bool sourdine = false,
}) async {
  _api = AvisApiDouble();

  final conteneur = ProviderContainer(
    overrides: [
      avisApiProvider.overrideWithValue(_api),
      preferencesDeSoireeProvider.overrideWith(
        (ref, id) async => preferences ?? _toutesActives(),
      ),
      sourdineProvider.overrideWith((ref, id) async => sourdine),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const ParametresNotificationsPage(evenementId: 'e1'),
    conteneur: conteneur,
  );
}

void main() {
  group('Réglage des notifications par soirée', () {
    testWidgets('propose un interrupteur par catégorie simple', (tester) async {
      await _monter(tester);

      expect(
        find.byType(SwitchListTile),
        findsNWidgets(_categoriesSimples.length),
      );
    });

    testWidgets('propose trois choix pour la discussion', (tester) async {
      await _monter(tester);

      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('Seulement les mentions'), findsOneWidget);
      expect(find.text('Rien'), findsOneWidget);
    });

    testWidgets('la discussion propose trois choix et écrit deux préférences', (
      tester,
    ) async {
      await _monter(tester);

      await tester.tap(find.text('Seulement les mentions'));
      await tester.pumpAndSettle();

      expect(_api.ecrits, contains(('discussion.message', false)));
      expect(_api.ecrits, contains(('discussion.mention', true)));
    });

    testWidgets('choisir « Tout » réactive les deux préférences', (
      tester,
    ) async {
      await _monter(
        tester,
        preferences: [
          for (final categorie in _categoriesSimples)
            PreferenceDeSoiree(
              categorie: categorie,
              actif: true,
              estUnEcart: false,
            ),
          const PreferenceDeSoiree(
            categorie: 'discussion.message',
            actif: false,
            estUnEcart: true,
          ),
          const PreferenceDeSoiree(
            categorie: 'discussion.mention',
            actif: true,
            estUnEcart: true,
          ),
        ],
      );

      await tester.tap(find.text('Tout'));
      await tester.pumpAndSettle();

      expect(_api.ecrits, contains(('discussion.message', true)));
      expect(_api.ecrits, contains(('discussion.mention', true)));
    });

    testWidgets('choisir « Rien » coupe les deux préférences', (tester) async {
      await _monter(tester);

      await tester.tap(find.text('Rien'));
      await tester.pumpAndSettle();

      expect(_api.ecrits, contains(('discussion.message', false)));
      expect(_api.ecrits, contains(('discussion.mention', false)));
    });

    testWidgets('couper une catégorie simple écrit sa valeur à faux', (
      tester,
    ) async {
      await _monter(tester);

      await tester.tap(find.text('Réponses aux invitations'));
      await tester.pumpAndSettle();

      expect(_api.ecrits, contains(('invitation.answer', false)));
    });

    testWidgets('nomme les catégories en clair, jamais par leur identifiant', (
      tester,
    ) async {
      await _monter(tester);

      expect(find.text('Réponses aux invitations'), findsOneWidget);
      expect(find.text('Nouveaux sondages'), findsOneWidget);
      expect(find.text('Nouvelles dépenses'), findsOneWidget);
      expect(find.text('invitation.answer'), findsNothing);
    });

    testWidgets('affiche que la soirée est en sourdine, à côté des catégories', (
      tester,
    ) async {
      await _monter(tester, sourdine: true);

      expect(find.textContaining('Rien n’arrive'), findsOneWidget);
      // Les catégories restent visibles et lisibles à côté de cet avertissement :
      // l'écran ne les cache pas pour autant.
      expect(find.byType(SwitchListTile), findsWidgets);
    });

    testWidgets("n'annonce pas de sourdine quand la soirée ne l'est pas", (
      tester,
    ) async {
      await _monter(tester);

      expect(find.textContaining('Rien n’arrive'), findsNothing);
    });

    testWidgets(
      '« Comme mes réglages habituels » retire tous les écarts, sans exception',
      (tester) async {
        await _monter(tester);

        await tester.tap(find.text('Comme mes réglages habituels'));
        await tester.pumpAndSettle();

        expect(_api.ecrits.length, _categoriesSimples.length + 2);
        expect(_api.ecrits.every((ecrit) => ecrit.$2 == null), isTrue);
      },
    );

    testWidgets(
      'une catégorie simple affiche une erreur quand l’écriture échoue',
      (tester) async {
        await _monter(tester);
        _api.categoriesEnEchec.add('invitation.answer');

        await tester.tap(find.text('Réponses aux invitations'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets('un échec partiel de la discussion restaure la valeur déjà écrite', (
      tester,
    ) async {
      // Départ « Tout » (message et mention actifs). La mention échoue : le message,
      // déjà écrit, ne doit pas rester seul à avoir changé.
      await _monter(tester);
      _api.categoriesEnEchec.add('discussion.mention');

      await tester.tap(find.text('Rien'));
      await tester.pumpAndSettle();

      expect(_api.ecrits, contains(('discussion.message', false)));
      // La dernière écriture réussie restaure le message à sa valeur d'avant le
      // choix : l'écran n'affiche jamais une combinaison qu'aucun des trois choix
      // ne représente.
      expect(_api.ecrits.last, ('discussion.message', true));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('une erreur réseau propose de réessayer', (tester) async {
      final conteneur = ProviderContainer(
        overrides: [
          avisApiProvider.overrideWithValue(AvisApiDouble()),
          preferencesDeSoireeProvider.overrideWith(
            (ref, id) async => throw Exception('réseau indisponible'),
          ),
          sourdineProvider.overrideWith((ref, id) async => false),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const ParametresNotificationsPage(evenementId: 'e1'),
        conteneur: conteneur,
      );

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });
}
