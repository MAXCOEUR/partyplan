import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/article_course.dart';
import 'package:partyplan/core/network/api_exception.dart';
import 'package:partyplan/core/network/courses_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/courses/achat_feuille.dart';
import 'package:partyplan/features/courses/article_feuille.dart';
import 'package:partyplan/features/courses/courses_page.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

/// Client de courses en mémoire, qui enregistre ce qu'on lui demande.
class _CoursesApiDouble implements CoursesApi {
  _CoursesApiDouble(this._liste);

  ListeCourses _liste;

  final List<String> appels = [];

  /// Refus à rendre au prochain appel d'attribution.
  ApiException? refusAttribution;

  @override
  Future<ListeCourses> lister(String evenementId) async {
    appels.add('lister');
    return _liste;
  }

  @override
  Future<ArticleCourse> attribuer(String evenementId, String articleId) async {
    appels.add('attribuer:$articleId');

    final refus = refusAttribution;
    if (refus != null) {
      throw refus;
    }

    return _muter(articleId, prisPar: 'Moi', parMoi: true);
  }

  @override
  Future<ArticleCourse> liberer(String evenementId, String articleId) async {
    appels.add('liberer:$articleId');
    return _muter(articleId, prisPar: null, parMoi: false);
  }

  @override
  Future<ArticleCourse> acheter(
    String evenementId,
    String articleId, {
    double? quantiteObtenue,
    double? prixPaye,
  }) async {
    appels.add('acheter:$articleId:$quantiteObtenue:$prixPaye');
    return _liste.articles.firstWhere((a) => a.id == articleId);
  }

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
    appels.add('ajouter:$nom:${categorie.versApi}:$quantite:$unite:$prixEstime');
    return _liste.articles.first;
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
    appels.add('modifier:$articleId:$nom:${categorie.versApi}');
    return _liste.articles.firstWhere((a) => a.id == articleId);
  }

  @override
  Future<void> supprimer(String evenementId, String articleId) async {
    appels.add('supprimer:$articleId');
  }

  ArticleCourse _muter(
    String articleId, {
    required String? prisPar,
    required bool parMoi,
  }) {
    final articles = [
      for (final article in _liste.articles)
        if (article.id == articleId)
          _copie(article, prisPar: prisPar, parMoi: parMoi)
        else
          article,
    ];

    _liste = ListeCourses(avancement: _liste.avancement, articles: articles);

    return articles.firstWhere((a) => a.id == articleId);
  }
}

ArticleCourse _copie(
  ArticleCourse source, {
  required String? prisPar,
  required bool parMoi,
}) => ArticleCourse(
  id: source.id,
  nom: source.nom,
  quantite: source.quantite,
  unite: source.unite,
  categorie: source.categorie,
  membreAttributaire: prisPar == null ? null : 'membre',
  nomAttributaire: prisPar,
  prisParMoi: parMoi,
  estAchete: source.estAchete,
  quantiteObtenue: source.quantiteObtenue,
  quantiteRestante: source.quantiteRestante,
  prixEstime: source.prixEstime,
  prixPaye: source.prixPaye,
  note: source.note,
);

ArticleCourse _article({
  required String id,
  String nom = 'Bières',
  double quantite = 24,
  String? unite = 'bouteilles',
  CategorieCourse categorie = CategorieCourse.boissons,
  String? nomAttributaire,
  bool prisParMoi = false,
  bool estAchete = false,
  double? quantiteObtenue,
  double? quantiteRestante,
  double? prixEstime,
  double? prixPaye,
  String? note,
}) => ArticleCourse(
  id: id,
  nom: nom,
  quantite: quantite,
  unite: unite,
  categorie: categorie,
  membreAttributaire: nomAttributaire == null && !prisParMoi ? null : 'm-$id',
  nomAttributaire: nomAttributaire,
  prisParMoi: prisParMoi,
  estAchete: estAchete,
  quantiteObtenue: quantiteObtenue,
  quantiteRestante: quantiteRestante ?? quantite,
  prixEstime: prixEstime,
  prixPaye: prixPaye,
  note: note,
);

Future<_CoursesApiDouble> _monter(
  WidgetTester tester, {
  required AvancementCourses avancement,
  required List<ArticleCourse> articles,
}) async {
  final api = _CoursesApiDouble(
    ListeCourses(avancement: avancement, articles: articles),
  );

  final conteneur = ProviderContainer(
    overrides: [coursesApiProvider.overrideWithValue(api)],
  );
  addTearDown(conteneur.dispose);

  // Enveloppée dans un Scaffold : c'est la coquille d'événement qui le fournit en
  // usage réel, et un message d'erreur n'a nulle part où s'afficher sans lui.
  await monterEcran(
    tester,
    const Scaffold(body: CoursesPage(evenementId: _evenement)),
    conteneur: conteneur,
  );

  return api;
}

void main() {
  group('Écran des courses', () {
    testWidgets('affiche l’avancement pris et acheté', (tester) async {
      // EF-CRS-09 : deux décomptes distincts. « Pris » n'implique pas « acheté », et
      // les confondre ferait croire la liste réglée alors que rien n'est en magasin.
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 3, pris: 2, achetes: 1),
        articles: [
          _article(id: 'a'),
          _article(id: 'b', nom: 'Chips', nomAttributaire: 'Lucas'),
          _article(id: 'c', nom: 'Gobelets', prisParMoi: true, estAchete: true),
        ],
      );

      expect(find.textContaining('2 / 3'), findsOneWidget);
      expect(find.textContaining('1 / 3'), findsOneWidget);
    });

    testWidgets('groupe les articles par catégorie, en français', (tester) async {
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 3, pris: 0, achetes: 0),
        articles: [
          _article(id: 'a', categorie: CategorieCourse.boissons),
          _article(
            id: 'b',
            nom: 'Chips',
            categorie: CategorieCourse.nourriture,
          ),
          _article(
            id: 'c',
            nom: 'Gobelets',
            categorie: CategorieCourse.materiel,
          ),
        ],
      );

      expect(find.text('Boissons'), findsOneWidget);
      expect(find.text('Nourriture'), findsOneWidget);
      expect(find.text('Matériel'), findsOneWidget);
      // Aucune catégorie vide n'est affichée : un en-tête sans article est du bruit.
      expect(find.text('Autres'), findsNothing);
    });

    testWidgets('un article libre propose de s’en occuper', (tester) async {
      final api = await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 0, achetes: 0),
        articles: [_article(id: 'a')],
      );

      await tester.tap(find.text('À prendre'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('attribuer:a'));
    });

    testWidgets('un article pris par un autre n’est pas actionnable', (
      tester,
    ) async {
      // RG-CRS-01 : l'attribution est unique. Proposer le geste puis le refuser
      // vaudrait moins que ne pas le proposer.
      final api = await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 1, achetes: 0),
        articles: [_article(id: 'a', nomAttributaire: 'Lucas')],
      );

      expect(find.text('Lucas'), findsOneWidget);

      await tester.tap(find.text('Lucas'));
      await tester.pumpAndSettle();

      expect(api.appels, isNot(contains('attribuer:a')));
    });

    testWidgets('un article pris par soi peut être libéré', (tester) async {
      final api = await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 1, achetes: 0),
        articles: [_article(id: 'a', prisParMoi: true, nomAttributaire: 'Moi')],
      );

      await tester.tap(find.text('Moi'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('liberer:a'));
    });

    testWidgets('un achat partiel affiche le reliquat', (tester) async {
      // RG-CRS-02 : sans le reliquat, un article à moitié acheté passe pour réglé.
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 1, achetes: 1),
        articles: [
          _article(
            id: 'a',
            quantite: 24,
            estAchete: true,
            quantiteObtenue: 18,
            quantiteRestante: 6,
            prisParMoi: true,
            nomAttributaire: 'Moi',
          ),
        ],
      );

      expect(find.textContaining('6'), findsWidgets);
      expect(find.textContaining('reste'), findsOneWidget);
    });

    testWidgets('le prix estimé est présenté comme une estimation', (
      tester,
    ) async {
      // RG-CRS-03 : le prix estimé n'entre dans aucun calcul. L'écran ne doit pas le
      // présenter comme une somme due.
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 0, achetes: 0),
        articles: [_article(id: 'a', prixEstime: 30.5)],
      );

      expect(find.textContaining('estimé'), findsOneWidget);
    });

    testWidgets('une liste vide invite à ajouter un premier article', (
      tester,
    ) async {
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 0, pris: 0, achetes: 0),
        articles: const [],
      );

      expect(find.textContaining('Rien à acheter'), findsOneWidget);
    });

    testWidgets('un article déjà pris par un autre est signalé sans échec muet', (
      tester,
    ) async {
      // Deux personnes qui prennent le même article au même instant, c'est le cas
      // normal d'une liste partagée. L'écran le dit et recharge, il ne réessaie pas.
      final api = await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 0, achetes: 0),
        articles: [_article(id: 'a')],
      );

      api.refusAttribution = const ApiException(
        statusCode: 409,
        title: 'Cet article est déjà pris.',
        code: 'shopping.already_claimed',
      );

      await tester.tap(find.text('À prendre'));
      await tester.pumpAndSettle();

      expect(find.textContaining('vient de le prendre'), findsOneWidget);
      // La liste est rechargée : l'écran affiche qui l'a pris, pas un état deviné.
      expect(api.appels.where((a) => a == 'lister').length, greaterThan(1));
    });

    testWidgets('celui qui s’en occupe peut déclarer l’achat', (tester) async {
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 1, achetes: 0),
        articles: [_article(id: 'a', prisParMoi: true, nomAttributaire: 'Moi')],
      );

      await tester.tap(find.text('Acheté'));
      await tester.pumpAndSettle();

      expect(find.byType(AchatFeuille), findsOneWidget);
    });

    testWidgets('l’achat n’est pas proposé sur l’article d’un autre', (
      tester,
    ) async {
      // Déclarer l'achat de quelqu'un d'autre créerait une dépense à son nom.
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 1, achetes: 0),
        articles: [_article(id: 'a', nomAttributaire: 'Lucas')],
      );

      expect(find.text('Acheté'), findsNothing);
    });

    testWidgets('un article se modifie depuis son menu', (tester) async {
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 0, achetes: 0),
        articles: [_article(id: 'a')],
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(find.byType(ArticleFeuille), findsOneWidget);
    });

    testWidgets('la suppression demande confirmation avant d’agir', (
      tester,
    ) async {
      // Un article supprimé par erreur au milieu d'une liste partagée est une perte
      // silencieuse : personne ne sait ce qui manquait.
      final api = await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 0, achetes: 0),
        articles: [_article(id: 'a')],
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(api.appels, isNot(contains('supprimer:a')));

      await tester.tap(find.text('Supprimer l’article'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('supprimer:a'));
    });

    testWidgets('un prix payé se corrige après coup', (tester) async {
      // Le ticket ne correspond jamais tout à fait à ce qu'on avait annoncé, et la
      // dépense engendrée porte ce montant : sans correction, les comptes restent faux.
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 1, achetes: 1),
        articles: [
          _article(
            id: 'a',
            prisParMoi: true,
            nomAttributaire: 'Moi',
            estAchete: true,
            quantiteObtenue: 24,
            quantiteRestante: 0,
            prixPaye: 28.40,
          ),
        ],
      );

      expect(find.text('Corriger le prix'), findsOneWidget);

      await tester.tap(find.text('Corriger le prix'));
      await tester.pumpAndSettle();

      expect(find.byType(AchatFeuille), findsOneWidget);
    });

    testWidgets('la correction du prix part du montant déjà payé', (
      tester,
    ) async {
      await _monter(
        tester,
        avancement: const AvancementCourses(total: 1, pris: 1, achetes: 1),
        articles: [
          _article(
            id: 'a',
            prisParMoi: true,
            nomAttributaire: 'Moi',
            estAchete: true,
            quantiteObtenue: 24,
            quantiteRestante: 0,
            prixPaye: 28.40,
          ),
        ],
      );

      await tester.tap(find.text('Corriger le prix'));
      await tester.pumpAndSettle();

      // Le champ est prérempli : on corrige quelques centimes, on ne ressaisit pas.
      expect(find.text('28,40'), findsOneWidget);
    });

    testWidgets('offre une reprise après une erreur de chargement', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          listeCoursesProvider(
            _evenement,
          ).overrideWith((ref) => Future.error(Exception('réseau'))),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const Scaffold(body: CoursesPage(evenementId: _evenement)),
        conteneur: conteneur,
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
