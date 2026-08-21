import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/depense.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/depenses_api.dart';

import '../doubles/session_store_double.dart';

class _Serveur extends Interceptor {
  final List<RequestOptions> requetes = [];
  Object? reponse;
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
  group('Modèles de dépenses', () {
    test('analyse la page et ses totaux', () {
      final page = PageDepenses.depuisJson(_page);

      expect(page.total, 38.4);
      expect(page.maPart, 19.2);
      expect(page.depenses.length, 2);
    });

    test('distingue une dépense née des courses d’une saisie manuelle', () {
      // Les deux apparaissent dans la même liste : sans ce repère, personne ne
      // comprend d'où sort une dépense qu'il n'a pas saisie.
      final page = PageDepenses.depuisJson(_page);

      expect(page.depenses[0].issueDesCourses, isTrue);
      expect(page.depenses[1].issueDesCourses, isFalse);
    });

    test('analyse le détail et les parts', () {
      final detail = DetailDepense.depuisJson(_detail);

      expect(detail.libelle, 'Location de la salle');
      expect(detail.montant, 180);
      expect(detail.payeurNom, 'Organisateur');
      expect(detail.parts.length, 2);
      expect(detail.parts.first.nom, 'Organisateur');
      expect(detail.parts.first.montant, 90);
      expect(detail.nombreRevisions, 1);
    });

    test('un montant à parts inégales garde le poids de chacun', () {
      final detail = DetailDepense.depuisJson(_detail);

      expect(detail.parts[0].part, 1);
      expect(detail.parts[1].part, 1);
      expect(detail.partsInegales, isFalse);
    });

    test('les modes d’assiette portent les noms attendus par l’API', () {
      expect(ModeAssiette.tousLesPresents.versApi, 'AllPresent');
      expect(ModeAssiette.selection.versApi, 'Selection');
      expect(ModeAssiette.partsPersonnalisees.versApi, 'Custom');
    });
  });

  group('Client d’API des dépenses', () {
    const evenement = 'ev-1';
    const depense = 'dep-1';

    late _Serveur serveur;
    late DepensesApi api;

    setUp(() {
      serveur = _Serveur()..reponse = _detail;
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..interceptors.add(serveur);
      api = DepensesApi(
        ApiClient(SessionStoreDouble(jetonAcces: 'jeton'), dio: dio),
      );
    });

    test('lit la liste', () async {
      serveur.reponse = _page;

      final page = await api.lister(evenement);

      expect(serveur.derniere.method, 'GET');
      expect(serveur.derniere.path, '/events/$evenement/expenses');
      expect(page.total, 38.4);
    });

    test('crée une dépense partagée entre tous les présents', () async {
      // Mode par défaut : c'est le cas courant, et le demander à chaque saisie
      // ralentirait le geste le plus fréquent.
      await api.creer(
        evenement,
        libelle: 'Location de la salle',
        montant: 180,
        mode: ModeAssiette.tousLesPresents,
      );

      expect(serveur.derniere.method, 'POST');
      expect(serveur.derniere.headers['Idempotency-Key'], isNotEmpty);

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps['label'], 'Location de la salle');
      expect(corps['amount'], 180);
      expect(corps['mode'], 'AllPresent');
      expect(corps.containsKey('shares'), isFalse);
    });

    test('transmet la sélection de participants', () async {
      await api.creer(
        evenement,
        libelle: 'Taxi',
        montant: 24,
        mode: ModeAssiette.selection,
        parts: const [PartDemandee('m1', 1), PartDemandee('m2', 1)],
      );

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps['mode'], 'Selection');
      expect(corps['shares'], [
        {'memberId': 'm1', 'share': 1},
        {'memberId': 'm2', 'share': 1},
      ]);
    });

    test('transmet des parts inégales', () async {
      // Deux parts pour celui qui dort sur place, une pour les autres.
      await api.creer(
        evenement,
        libelle: 'Gîte',
        montant: 300,
        mode: ModeAssiette.partsPersonnalisees,
        parts: const [PartDemandee('m1', 2), PartDemandee('m2', 1)],
      );

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps['mode'], 'Custom');
      expect(corps['shares'], [
        {'memberId': 'm1', 'share': 2},
        {'memberId': 'm2', 'share': 1},
      ]);
    });

    test('désigne un payeur autre que soi', () async {
      // On saisit souvent la dépense de quelqu'un d'autre : « c'est Lucas qui a payé
      // le taxi ». Sans ce champ, le solde serait faux pour deux personnes.
      await api.creer(
        evenement,
        libelle: 'Taxi',
        montant: 24,
        mode: ModeAssiette.tousLesPresents,
        payeurMembreId: 'm2',
      );

      final corps = serveur.derniere.data! as Map<String, dynamic>;
      expect(corps['paidByMemberId'], 'm2');
    });

    test('lit le détail d’une dépense', () async {
      final detail = await api.detail(evenement, depense);

      expect(serveur.derniere.method, 'GET');
      expect(serveur.derniere.path, '/events/$evenement/expenses/$depense');
      expect(detail.parts.length, 2);
    });

    test('modifie sans clé d’idempotence', () async {
      await api.modifier(
        evenement,
        depense,
        libelle: 'Salle des fêtes',
        montant: 200,
        mode: ModeAssiette.tousLesPresents,
      );

      expect(serveur.derniere.method, 'PATCH');
      expect(serveur.derniere.headers.containsKey('Idempotency-Key'), isFalse);
    });

    test('supprime une dépense', () async {
      serveur
        ..reponse = null
        ..statut = 204;

      await api.supprimer(evenement, depense);

      expect(serveur.derniere.method, 'DELETE');
      expect(serveur.derniere.path, '/events/$evenement/expenses/$depense');
    });
  });
}

const _page = <String, dynamic>{
  'total': 38.4,
  'myShare': 19.2,
  'items': [
    {
      'id': 'a',
      'label': 'Bières',
      'amount': 28.4,
      'paidByMemberId': 'm1',
      'paidByDisplayName': 'Organisateur',
      'spentAt': '2026-08-21T10:58:26.450442+00:00',
      'participantCount': 2,
      'fromShoppingItem': true,
    },
    {
      'id': 'b',
      'label': 'Location de la salle',
      'amount': 10.0,
      'paidByMemberId': 'm2',
      'paidByDisplayName': 'Lucas',
      'spentAt': '2026-08-20T18:00:00.000000+00:00',
      'participantCount': 2,
      'fromShoppingItem': false,
    },
  ],
};

const _detail = <String, dynamic>{
  'id': 'b',
  'label': 'Location de la salle',
  'amount': 180.0,
  'paidByMemberId': 'm1',
  'paidByDisplayName': 'Organisateur',
  'spentAt': '2026-08-20T18:00:00.000000+00:00',
  'fromShoppingItem': false,
  'revisionCount': 1,
  'shares': [
    {'memberId': 'm1', 'displayName': 'Organisateur', 'share': 1, 'amount': 90},
    {'memberId': 'm2', 'displayName': 'Lucas', 'share': 1, 'amount': 90},
  ],
};
