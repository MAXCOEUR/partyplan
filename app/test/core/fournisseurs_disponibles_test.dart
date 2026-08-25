import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/comptes_api.dart';

import '../doubles/session_store_double.dart';

/// Ce que l'instance sait faire, lu avant toute session par l'écran de connexion.
void main() {
  group('ComptesApi.fournisseursDisponibles', () {
    test('ne retient que les fournisseurs réellement configurés', () async {
      final api = ComptesApi(
        _client(const {
          'providers': [
            {'provider': 'google', 'configured': true},
            {'provider': 'apple', 'configured': false},
          ],
        }),
        SessionStoreDouble(),
      );

      // Un fournisseur sans clé n'a pas à remonter : l'appelant s'en servirait pour
      // afficher un bouton condamné.
      expect(await api.fournisseursDisponibles(), {'google'});
    });

    test('une instance sans aucune clé ne renvoie rien', () async {
      final api = ComptesApi(
        _client(const {
          'providers': [
            {'provider': 'google', 'configured': false},
          ],
        }),
        SessionStoreDouble(),
      );

      expect(await api.fournisseursDisponibles(), isEmpty);
    });
  });
}

ApiClient _client(Object? reponse) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: reponse,
        ),
      ),
    ),
  );

  return ApiClient(SessionStoreDouble(), dio: dio);
}
