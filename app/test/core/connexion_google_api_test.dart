import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/comptes_api.dart';

import '../doubles/session_store_double.dart';

/// Connexion par jeton d'identité Google (EF-AUTH-06).
///
/// Le serveur sait déjà vérifier le jeton et ouvrir la session ; ce qui se teste ici,
/// c'est que l'application présente le jeton au bon endpoint et retienne la session
/// qu'on lui renvoie.
void main() {
  group('ComptesApi.connecterAvecGoogle', () {
    test('présente le jeton d’identité à /auth/google', () async {
      final appels = <(String, Object?)>[];
      final magasin = SessionStoreDouble();
      final api = ComptesApi(_client(appels, magasin), magasin);

      await api.connecterAvecGoogle('jeton-identite-google');

      expect(appels.single.$1, '/auth/google');
      expect(appels.single.$2, {'idToken': 'jeton-identite-google'});
    });

    test('retient la session renvoyée', () async {
      final magasin = SessionStoreDouble();
      final api = ComptesApi(_client(<(String, Object?)>[], magasin), magasin);

      await api.connecterAvecGoogle('jeton-identite-google');

      // Sans cela la personne serait authentifiée côté serveur et anonyme côté
      // application : elle retomberait sur l'écran de connexion aussitôt après.
      expect(magasin.jetonAcces, 'acces-rendu');
    });
  });
}

ApiClient _client(List<(String, Object?)> appels, SessionStoreDouble magasin) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        appels.add((options.path, options.data));
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: const {
              'accessToken': 'acces-rendu',
              'refreshToken': 'rafraichissement-rendu',
              'expiresIn': 900,
            },
          ),
        );
      },
    ),
  );

  return ApiClient(magasin, dio: dio);
}
