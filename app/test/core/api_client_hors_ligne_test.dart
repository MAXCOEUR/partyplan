import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/offline/cache_lecture.dart';
import 'package:partyplan/core/offline/ecriture_differee.dart';
import 'package:partyplan/core/offline/etat_reseau.dart';
import 'package:partyplan/core/offline/file_ecritures.dart';

import '../doubles/magasin_local_double.dart';
import '../doubles/session_store_double.dart';

/// Intercepteur qui simule l'absence de réseau, ou une réponse donnée.
class _Reseau extends Interceptor {
  bool coupe = false;
  Object? reponse;
  int statut = 200;
  final List<RequestOptions> requetes = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requetes.add(options);

    if (coupe) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'réseau coupé',
        ),
      );
      return;
    }

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
  late _Reseau reseau;
  late MagasinLocalDouble magasin;
  late ApiClient client;
  late EtatReseau etat;

  setUp(() {
    reseau = _Reseau();
    magasin = MagasinLocalDouble();
    etat = EtatReseau();

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://exemple.test/v1',
        validateStatus: (_) => true,
      ),
    )..interceptors.add(reseau);

    client = ApiClient(
      SessionStoreDouble(jetonAcces: 'jeton'),
      dio: dio,
      cache: CacheLecture(magasin),
      file: FileEcritures(magasin),
      etat: etat,
    );
  });

  group('Lecture hors ligne', () {
    test('sert la dernière réponse connue quand le réseau est coupé', () async {
      reseau.reponse = [
        {'id': 'a'},
      ];
      await client.get<List<dynamic>>(
        '/events',
        analyser: (c) => c! as List<dynamic>,
      );

      reseau.coupe = true;
      final servi = await client.get<List<dynamic>>(
        '/events',
        analyser: (c) => c! as List<dynamic>,
      );

      expect(servi, [
        {'id': 'a'},
      ]);
      expect(etat.mode, ModeReseau.horsLigne);
      expect(etat.fraicheur, isNotNull);
    });

    test('échoue quand le réseau est coupé et que rien n’est en cache', () async {
      reseau.coupe = true;

      await expectLater(
        client.get<List<dynamic>>(
          '/events',
          analyser: (c) => c! as List<dynamic>,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('Écriture hors ligne', () {
    test('met en file une écriture différable et lève EcritureDifferee', () async {
      reseau.coupe = true;

      await expectLater(
        client.patch<void>(
          '/events/1/members/me',
          corps: {'status': 'Going'},
          differable: true,
          analyser: (_) {},
        ),
        throwsA(isA<EcritureDifferee>()),
      );

      expect(
        (await FileEcritures(magasin).enAttente()).single.chemin,
        '/events/1/members/me',
      );
      expect(etat.enAttente, 1);
    });

    test('ne met pas en file une écriture non différable', () async {
      reseau.coupe = true;

      await expectLater(
        client.post<void>('/events/1/invitation/rotate', analyser: (_) {}),
        throwsA(isA<DioException>()),
      );

      // rotate est délibérément non idempotent : rejoué, il invaliderait le lien que
      // l'utilisateur vient de partager.
      expect(await FileEcritures(magasin).enAttente(), isEmpty);
    });

    test('rejoue la file avec la clé d’idempotence d’origine', () async {
      reseau.coupe = true;
      await client
          .patch<void>(
            '/events/1/members/me',
            corps: {'status': 'Going'},
            differable: true,
            analyser: (_) {},
          )
          .onError((_, _) {});

      final cleAttendue =
          (await FileEcritures(magasin).enAttente()).single.cleIdempotence;

      reseau
        ..coupe = false
        ..reponse = null
        ..statut = 204
        ..requetes.clear();
      await client.rejouerLaFile();

      expect(await FileEcritures(magasin).enAttente(), isEmpty);
      expect(
        reseau.requetes.single.headers['Idempotency-Key'],
        cleAttendue,
      );
    });

    test('une 4xx métier retire l’écriture de la file', () async {
      reseau.coupe = true;
      await client
          .patch<void>('/a', corps: {}, differable: true, analyser: (_) {})
          .onError((_, _) {});

      reseau
        ..coupe = false
        ..statut = 422
        ..reponse = {'title': 'Statut inconnu.', 'code': 'attendance.bad'};
      await client.rejouerLaFile();

      expect(await FileEcritures(magasin).enAttente(), isEmpty);
    });

    test('une 5xx conserve l’écriture en file', () async {
      reseau.coupe = true;
      await client
          .patch<void>('/a', corps: {}, differable: true, analyser: (_) {})
          .onError((_, _) {});

      reseau
        ..coupe = false
        ..statut = 503
        ..reponse = {'title': 'Service indisponible.'};
      await client.rejouerLaFile();

      expect((await FileEcritures(magasin).enAttente()).single.tentatives, 1);
    });
  });
}
