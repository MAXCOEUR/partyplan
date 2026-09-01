import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/api_exception.dart';

import '../doubles/session_store_double.dart';

/// Serveur simulé qui applique la rotation du jeton de rafraîchissement, comme l'API.
///
/// C'est cette rotation qui rend la course visible : un jeton présenté deux fois est
/// refusé (`AuthenticationService.RefreshAsync`). Un double qui accepterait toujours le
/// même jeton laisserait passer exactement le défaut qu'on cherche à corriger.
class _ServeurAvecRotation extends Interceptor {
  _ServeurAvecRotation({this.statutAuRafraichissement});

  /// Statut imposé au renouvellement : sert à distinguer une panne passagère du
  /// serveur d'un refus de la session.
  final int? statutAuRafraichissement;

  String jetonAccesValide = 'acces-2';
  String jetonRafraichissementValide = 'rafraichissement-1';

  int rafraichissements = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path == '/auth/refresh') {
      rafraichissements++;

      final impose = statutAuRafraichissement;
      if (impose != null) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: impose,
            data: const {'title': 'Service indisponible.'},
          ),
        );
        return;
      }

      final presente = (options.data as Map<String, dynamic>)['refreshToken'];

      if (presente != jetonRafraichissementValide) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 400,
            data: const {
              'title': 'Session expirée.',
              'code': 'auth.invalid_refresh_token',
            },
          ),
        );
        return;
      }

      jetonRafraichissementValide = 'rafraichissement-2';
      jetonAccesValide = 'acces-2';

      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'accessToken': jetonAccesValide,
            'refreshToken': jetonRafraichissementValide,
          },
        ),
      );
      return;
    }

    final autorise =
        options.headers['Authorization'] == 'Bearer $jetonAccesValide';

    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: autorise ? 200 : 401,
        data: autorise ? {'ok': true} : const {'title': 'Non authentifié.'},
      ),
    );
  }
}

ApiClient _client(
  SessionStoreDouble sessions,
  _ServeurAvecRotation serveur, {
  void Function()? auSessionPerdue,
}) {
  final dio = Dio(
    BaseOptions(baseUrl: 'http://test', validateStatus: (_) => true),
  );

  // Le serveur simulé est branché **après** la construction : l'intercepteur qui pose
  // l'en-tête d'autorisation est ajouté par le constructeur, et un intercepteur qui
  // répond avant lui ne verrait jamais de jeton.
  final client = ApiClient(
    sessions,
    dio: dio,
    auSessionPerdue: auSessionPerdue,
  );
  dio.interceptors.add(serveur);

  return client;
}

void main() {
  test(
    'deux requêtes simultanément refusées ne déclenchent qu\'un seul renouvellement',
    () async {
      final sessions = SessionStoreDouble(
        jetonAcces: 'acces-1-expire',
        jetonRafraichissement: 'rafraichissement-1',
      );
      final serveur = _ServeurAvecRotation();
      final client = _client(sessions, serveur);

      await Future.wait([
        client.get<Object?>('/events', analyser: (corps) => corps),
        client.get<Object?>('/notifications', analyser: (corps) => corps),
      ]);

      expect(serveur.rafraichissements, 1);
      expect(sessions.jetonRafraichissement, 'rafraichissement-2');
    },
  );

  test(
    'une panne du serveur pendant le renouvellement conserve la session',
    () async {
      final sessions = SessionStoreDouble(
        jetonAcces: 'acces-1-expire',
        jetonRafraichissement: 'rafraichissement-1',
      );
      var perdue = false;

      final client = _client(
        sessions,
        _ServeurAvecRotation(statutAuRafraichissement: 503),
        auSessionPerdue: () => perdue = true,
      );

      await expectLater(
        client.get<Object?>('/events', analyser: (corps) => corps),
        throwsA(isA<ApiException>()),
      );

      // Un redémarrage de l'API, ou un 502 du reverse proxy, ne dit rien de la session :
      // l'effacer déconnecterait tout le monde à chaque mise à jour du serveur.
      expect(sessions.jetonRafraichissement, 'rafraichissement-1');
      expect(perdue, isFalse);
    },
  );

  test('un refus définitif du serveur signale la perte de session', () async {
    final sessions = SessionStoreDouble(
      jetonAcces: 'acces-1-expire',
      jetonRafraichissement: 'jeton-revoque',
    );
    var perdue = false;

    final client = _client(
      sessions,
      _ServeurAvecRotation(),
      auSessionPerdue: () => perdue = true,
    );

    await expectLater(
      client.get<Object?>('/events', analyser: (corps) => corps),
      throwsA(isA<Object>()),
    );

    expect(perdue, isTrue);
    expect(sessions.jetonRafraichissement, isNull);
  });
}
