import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/article_course.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/api_exception.dart';
import 'package:partyplan/core/network/courses_api.dart';

import '../doubles/session_store_double.dart';

/// Enregistre chaque requête et rend une réponse fixée.
class _Serveur extends Interceptor {
  final List<RequestOptions> requetes = [];

  Object? reponse = _articleJson;
  int statut = 200;

  RequestOptions get derniere => requetes.last;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requetes.add(options);
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: statut,
        data: reponse,
      ),
    );
  }
}

void main() {
  const evenement = '01a023e7-9bcb-7cd3-99f2-f61d12bed682';
  const article = '01a023e7-9cb7-714d-8383-b4959de88ea8';

  late _Serveur serveur;
  late CoursesApi api;

  setUp(() {
    serveur = _Serveur();
    final dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..interceptors.add(serveur);
    api = CoursesApi(
      ApiClient(SessionStoreDouble(jetonAcces: 'jeton'), dio: dio),
    );
  });

  group('Client d’API des courses', () {
    test('lit la liste et son avancement', () async {
      serveur.reponse = {
        'progress': {'total': 1, 'claimed': 0, 'purchased': 0},
        'items': [_articleJson],
      };

      final liste = await api.lister(evenement);

      expect(serveur.derniere.method, 'GET');
      expect(serveur.derniere.path, '/events/$evenement/shopping');
      expect(liste.avancement.total, 1);
      expect(liste.articles.single.nom, 'Bières');
    });

    test('ajoute un article avec une clé d’idempotence', () async {
      // Sans cet en-tête, le serveur refuse la création : un double appui sur
      // « Ajouter » ne doit jamais produire deux articles.
      await api.ajouter(
        evenement,
        nom: 'Chips',
        quantite: 4,
        unite: 'paquets',
        categorie: CategorieCourse.nourriture,
        prixEstime: 8.5,
        note: 'nature',
      );

      expect(serveur.derniere.method, 'POST');
      expect(serveur.derniere.path, '/events/$evenement/shopping');
      expect(serveur.derniere.headers['Idempotency-Key'], isNotEmpty);

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps['name'], 'Chips');
      expect(corps['quantity'], 4);
      expect(corps['unit'], 'paquets');
      expect(corps['category'], 'Food');
      expect(corps['estimatedPrice'], 8.5);
      expect(corps['note'], 'nature');
    });

    test('deux ajouts portent deux clés différentes', () async {
      // Une clé constante ferait passer le second ajout pour un rejeu du premier, et
      // le serveur rendrait la réponse précédente sans rien créer.
      await api.ajouter(evenement, nom: 'A', categorie: CategorieCourse.autres);
      await api.ajouter(evenement, nom: 'B', categorie: CategorieCourse.autres);

      expect(
        serveur.requetes[0].headers['Idempotency-Key'],
        isNot(serveur.requetes[1].headers['Idempotency-Key']),
      );
    });

    test('omet les champs facultatifs laissés vides', () async {
      // Envoyer `null` sur un champ absent le distinguerait mal d'un effacement
      // volontaire côté serveur.
      await api.ajouter(
        evenement,
        nom: 'Glace',
        categorie: CategorieCourse.nourriture,
      );

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps.containsKey('quantity'), isFalse);
      expect(corps.containsKey('unit'), isFalse);
      expect(corps.containsKey('estimatedPrice'), isFalse);
      expect(corps.containsKey('note'), isFalse);
    });

    test('modifie un article sans clé d’idempotence', () async {
      // Une modification est naturellement idempotente : la clé n'apporterait rien.
      await api.modifier(
        evenement,
        article,
        nom: 'Bières blondes',
        categorie: CategorieCourse.boissons,
      );

      expect(serveur.derniere.method, 'PATCH');
      expect(serveur.derniere.path, '/events/$evenement/shopping/$article');
      expect(serveur.derniere.headers.containsKey('Idempotency-Key'), isFalse);
    });

    test('supprime un article', () async {
      serveur.reponse = null;
      serveur.statut = 204;

      await api.supprimer(evenement, article);

      expect(serveur.derniere.method, 'DELETE');
      expect(serveur.derniere.path, '/events/$evenement/shopping/$article');
    });

    test('s’attribue un article', () async {
      await api.attribuer(evenement, article);

      expect(serveur.derniere.method, 'POST');
      expect(
        serveur.derniere.path,
        '/events/$evenement/shopping/$article/claim',
      );
    });

    test('retire son attribution et reçoit l’article à jour', () async {
      serveur.reponse = {..._articleJson, 'assignedToMe': false};

      final rendu = await api.liberer(evenement, article);

      expect(serveur.derniere.method, 'DELETE');
      expect(
        serveur.derniere.path,
        '/events/$evenement/shopping/$article/claim',
      );
      expect(rendu.prisParMoi, isFalse);
    });

    test('déclare un achat avec quantité obtenue et prix payé', () async {
      await api.acheter(
        evenement,
        article,
        quantiteObtenue: 18,
        prixPaye: 22.40,
      );

      expect(serveur.derniere.method, 'POST');
      expect(
        serveur.derniere.path,
        '/events/$evenement/shopping/$article/purchase',
      );
      expect(serveur.derniere.headers['Idempotency-Key'], isNotEmpty);

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps['purchasedQuantity'], 18);
      expect(corps['actualPrice'], 22.40);
    });

    test('déclare un achat sans prix, sans engendrer de dépense', () async {
      // Marquer acheté et payer sont deux gestes distincts : envoyer un prix nul
      // créerait une dépense à zéro euro dans les comptes de l'événement.
      await api.acheter(evenement, article, quantiteObtenue: 24);

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps.containsKey('actualPrice'), isFalse);
    });

    test('remonte le refus d’un article déjà pris', () async {
      serveur.statut = 409;
      serveur.reponse = {
        'title': 'Cet article est déjà pris.',
        'status': 409,
        'code': 'shopping.already_claimed',
      };

      await expectLater(
        api.attribuer(evenement, article),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'shopping.already_claimed',
          ),
        ),
      );
    });
  });
}

const _articleJson = <String, dynamic>{
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
