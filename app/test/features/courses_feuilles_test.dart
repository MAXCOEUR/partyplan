import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/article_course.dart';
import 'package:partyplan/core/network/courses_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/courses/achat_feuille.dart';
import 'package:partyplan/features/courses/article_feuille.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

/// Client de courses qui n'enregistre que ce qu'on lui demande.
class _CoursesApiDouble implements CoursesApi {
  final List<String> appels = [];

  @override
  Future<ArticleCourse> ajouter(
    String evenementId, {
    required String nom,
    required CategorieCourse categorie,
    double? quantite,
    String? unite,
    double? prixEstime,
    String? note,
  }) async {
    appels.add(
      'ajouter|$nom|${categorie.versApi}|$quantite|$unite|$prixEstime|$note',
    );
    return _articleExemple;
  }

  @override
  Future<ArticleCourse> modifier(
    String evenementId,
    String articleId, {
    required String nom,
    required CategorieCourse categorie,
    double? quantite,
    String? unite,
    double? prixEstime,
    String? note,
  }) async {
    appels.add('modifier|$articleId|$nom|${categorie.versApi}|$quantite');
    return _articleExemple;
  }

  @override
  Future<ArticleCourse> acheter(
    String evenementId,
    String articleId, {
    double? quantiteObtenue,
    double? prixPaye,
  }) async {
    appels.add('acheter|$articleId|$quantiteObtenue|$prixPaye');
    return _articleExemple;
  }

  @override
  Future<void> supprimer(String evenementId, String articleId) async {
    appels.add('supprimer|$articleId');
  }

  @override
  Future<ArticleCourse> attribuer(String evenementId, String articleId) async =>
      throw UnimplementedError();

  @override
  Future<ArticleCourse> liberer(String evenementId, String articleId) async =>
      throw UnimplementedError();

  @override
  Future<ListeCourses> lister(String evenementId) async => const ListeCourses(
    avancement: AvancementCourses(total: 0, pris: 0, achetes: 0),
    articles: [],
  );
}

final _articleExemple = ArticleCourse(
  id: 'a',
  nom: 'Bières',
  quantite: 24,
  unite: 'bouteilles',
  categorie: CategorieCourse.boissons,
  membreAttributaire: 'm1',
  nomAttributaire: 'Moi',
  prisParMoi: true,
  estAchete: false,
  quantiteObtenue: null,
  quantiteRestante: 24,
  prixEstime: 30.5,
  prixPaye: null,
  note: 'blondes',
);

Future<_CoursesApiDouble> _monter(WidgetTester tester, Widget feuille) async {
  final api = _CoursesApiDouble();
  final conteneur = ProviderContainer(
    overrides: [coursesApiProvider.overrideWithValue(api)],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, Scaffold(body: feuille), conteneur: conteneur);

  return api;
}

void main() {
  group('Ajout et modification d’un article', () {
    testWidgets('refuse un libellé vide', (tester) async {
      final api = await _monter(
        tester,
        const ArticleFeuille(evenementId: _evenement),
      );

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(api.appels, isEmpty);
      expect(find.textContaining('Indique'), findsOneWidget);
    });

    testWidgets('ajoute avec le libellé et la catégorie choisis', (
      tester,
    ) async {
      final api = await _monter(
        tester,
        const ArticleFeuille(evenementId: _evenement),
      );

      await tester.enterText(find.byKey(const Key('article-nom')), 'Chips');
      await tester.tap(find.text('Nourriture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(api.appels.single, startsWith('ajouter|Chips|Food|'));
    });

    testWidgets('la catégorie par défaut est « autres »', (tester) async {
      // Ranger est un travail : par défaut on ne demande rien, l'article part dans
      // « autres » et la liste reste utilisable.
      final api = await _monter(
        tester,
        const ArticleFeuille(evenementId: _evenement),
      );

      await tester.enterText(
        find.byKey(const Key('article-nom')),
        'Allumettes',
      );
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(api.appels.single, contains('|Other|'));
    });

    testWidgets('transmet quantité, unité, prix estimé et note', (
      tester,
    ) async {
      final api = await _monter(
        tester,
        const ArticleFeuille(evenementId: _evenement),
      );

      await tester.enterText(find.byKey(const Key('article-nom')), 'Bières');
      await tester.enterText(find.byKey(const Key('article-quantite')), '24');
      await tester.enterText(
        find.byKey(const Key('article-unite')),
        'bouteilles',
      );
      await tester.enterText(find.byKey(const Key('article-prix')), '30,50');
      await tester.enterText(find.byKey(const Key('article-note')), 'blondes');
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(
        api.appels.single,
        'ajouter|Bières|Other|24.0|bouteilles|30.5|blondes',
      );
    });

    testWidgets('en modification, les champs sont préremplis', (tester) async {
      final api = await _monter(
        tester,
        ArticleFeuille(evenementId: _evenement, article: _articleExemple),
      );

      expect(find.text('Bières'), findsOneWidget);
      expect(find.text('bouteilles'), findsOneWidget);
      expect(find.text('blondes'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(api.appels.single, startsWith('modifier|a|Bières|Drinks|'));
    });

    testWidgets('un prix négatif est refusé', (tester) async {
      final api = await _monter(
        tester,
        const ArticleFeuille(evenementId: _evenement),
      );

      await tester.enterText(find.byKey(const Key('article-nom')), 'Bières');
      await tester.enterText(find.byKey(const Key('article-prix')), '-3');
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(api.appels, isEmpty);
    });
  });

  group('Déclaration d’achat', () {
    testWidgets('la quantité obtenue est préremplie avec la quantité demandée', (
      tester,
    ) async {
      // Le cas courant est d'avoir tout trouvé : la saisie ne doit servir qu'à
      // corriger, pas à ressaisir.
      await _monter(
        tester,
        AchatFeuille(evenementId: _evenement, article: _articleExemple),
      );

      expect(find.text('24'), findsOneWidget);
    });

    testWidgets('saisir un prix annonce la dépense qui sera créée', (
      tester,
    ) async {
      // EF-CRS-07 : la dépense apparaît dans les comptes de l'événement. La découvrir
      // après coup serait une mauvaise surprise sur un sujet d'argent.
      await _monter(
        tester,
        AchatFeuille(evenementId: _evenement, article: _articleExemple),
      );

      await tester.enterText(find.byKey(const Key('achat-prix')), '22,40');
      await tester.pumpAndSettle();

      expect(find.textContaining('dépense'), findsOneWidget);
    });

    testWidgets('valider sans prix marque acheté sans créer de dépense', (
      tester,
    ) async {
      final api = await _monter(
        tester,
        AchatFeuille(evenementId: _evenement, article: _articleExemple),
      );

      await tester.tap(find.text('C’est acheté'));
      await tester.pumpAndSettle();

      expect(api.appels.single, 'acheter|a|24.0|null');
    });

    testWidgets('transmet la quantité obtenue et le prix payé', (tester) async {
      final api = await _monter(
        tester,
        AchatFeuille(evenementId: _evenement, article: _articleExemple),
      );

      await tester.enterText(find.byKey(const Key('achat-quantite')), '18');
      await tester.enterText(find.byKey(const Key('achat-prix')), '22,40');
      await tester.tap(find.text('C’est acheté'));
      await tester.pumpAndSettle();

      expect(api.appels.single, 'acheter|a|18.0|22.4');
    });

    testWidgets('un prix négatif est refusé', (tester) async {
      final api = await _monter(
        tester,
        AchatFeuille(evenementId: _evenement, article: _articleExemple),
      );

      await tester.enterText(find.byKey(const Key('achat-prix')), '-5');
      await tester.tap(find.text('C’est acheté'));
      await tester.pumpAndSettle();

      expect(api.appels, isEmpty);
    });
  });
}
