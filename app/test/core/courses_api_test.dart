import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/article_course.dart';

void main() {
  group('Modèles de la liste de courses', () {
    test('analyse une réponse complète', () {
      final liste = ListeCourses.depuisJson(_reponse);

      expect(liste.avancement.total, 3);
      expect(liste.avancement.pris, 2);
      expect(liste.avancement.achetes, 1);
      expect(liste.articles.length, 3);
    });

    test('rend la catégorie en énumération', () {
      final liste = ListeCourses.depuisJson(_reponse);

      expect(liste.articles[0].categorie, CategorieCourse.boissons);
      expect(liste.articles[1].categorie, CategorieCourse.nourriture);
    });

    test('une catégorie inconnue tombe sur « autres » sans lever', () {
      // Un serveur plus récent ne doit pas faire planter un client plus ancien : une
      // cinquième catégorie ajoutée côté API laisserait sinon l'écran en erreur.
      final article = ArticleCourse.depuisJson({
        ..._article,
        'category': 'Fireworks',
      });

      expect(article.categorie, CategorieCourse.autres);
    });

    test('les libellés de catégorie sont en français', () {
      expect(CategorieCourse.boissons.libelle, 'Boissons');
      expect(CategorieCourse.nourriture.libelle, 'Nourriture');
      expect(CategorieCourse.materiel.libelle, 'Matériel');
      expect(CategorieCourse.autres.libelle, 'Autres');
    });

    test('les catégories se renvoient à l’API sous leur nom anglais', () {
      // Les identifiants du serveur sont en anglais : les traduire ici ferait échouer
      // la création avec « catégorie inconnue ».
      expect(CategorieCourse.boissons.versApi, 'Drinks');
      expect(CategorieCourse.nourriture.versApi, 'Food');
      expect(CategorieCourse.materiel.versApi, 'Supplies');
      expect(CategorieCourse.autres.versApi, 'Other');
    });

    test('un achat partiel conserve le reliquat', () {
      final article = ArticleCourse.depuisJson({
        ..._article,
        'quantity': 24.0,
        'isPurchased': true,
        'purchasedQuantity': 18.0,
        'remainingQuantity': 6.0,
        'actualPrice': 22.4,
      });

      expect(article.estAchete, isTrue);
      expect(article.quantiteObtenue, 18.0);
      expect(article.quantiteRestante, 6.0);
      expect(article.achatPartiel, isTrue);
      expect(article.prixPaye, 22.4);
    });

    test('un achat complet n’est pas un achat partiel', () {
      final article = ArticleCourse.depuisJson({
        ..._article,
        'isPurchased': true,
        'purchasedQuantity': 24.0,
        'remainingQuantity': 0.0,
      });

      expect(article.achatPartiel, isFalse);
    });

    test('les quantités absentes valent zéro plutôt que nul', () {
      // L'écran affiche une quantité sans avoir à tester la nullité à chaque usage.
      final article = ArticleCourse.depuisJson({
        'id': 'a',
        'name': 'Glace',
        'quantity': 1.0,
        'category': 'Food',
        'assignedToMe': false,
        'isPurchased': false,
        'remainingQuantity': 1.0,
      });

      expect(article.unite, isNull);
      expect(article.prixEstime, isNull);
      expect(article.note, isNull);
      expect(article.nomAttributaire, isNull);
    });

    test('distingue « pris par moi » de « pris par un autre »', () {
      final mien = ArticleCourse.depuisJson({
        ..._article,
        'assignedMemberId': 'm1',
        'assignedDisplayName': 'Moi',
        'assignedToMe': true,
      });
      final autre = ArticleCourse.depuisJson({
        ..._article,
        'assignedMemberId': 'm2',
        'assignedDisplayName': 'Lucas',
        'assignedToMe': false,
      });

      expect(mien.estPris, isTrue);
      expect(mien.prisParMoi, isTrue);
      expect(autre.estPris, isTrue);
      expect(autre.prisParMoi, isFalse);
      expect(autre.nomAttributaire, 'Lucas');
    });
  });
}

const _article = <String, dynamic>{
  'id': '01a023e7-9cb7-714d-8383-b4959de88ea8',
  'name': 'Bières',
  'quantity': 24.0,
  'unit': 'bouteilles',
  'category': 'Drinks',
  'assignedMemberId': null,
  'assignedDisplayName': null,
  'assignedToMe': false,
  'isPurchased': false,
  'purchasedQuantity': null,
  'remainingQuantity': 24.0,
  'estimatedPrice': 30.5,
  'actualPrice': null,
  'note': 'blondes',
};

const _reponse = <String, dynamic>{
  'progress': {'total': 3, 'claimed': 2, 'purchased': 1},
  'items': [
    _article,
    {
      'id': 'b',
      'name': 'Chips',
      'quantity': 4.0,
      'unit': 'paquets',
      'category': 'Food',
      'assignedMemberId': 'm2',
      'assignedDisplayName': 'Lucas',
      'assignedToMe': false,
      'isPurchased': false,
      'purchasedQuantity': null,
      'remainingQuantity': 4.0,
      'estimatedPrice': null,
      'actualPrice': null,
      'note': null,
    },
    {
      'id': 'c',
      'name': 'Gobelets',
      'quantity': 50.0,
      'unit': null,
      'category': 'Supplies',
      'assignedMemberId': 'm1',
      'assignedDisplayName': 'Moi',
      'assignedToMe': true,
      'isPurchased': true,
      'purchasedQuantity': 50.0,
      'remainingQuantity': 0.0,
      'estimatedPrice': null,
      'actualPrice': 12.9,
      'note': null,
    },
  ],
};
