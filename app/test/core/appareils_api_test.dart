import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/appareils_api.dart';

import '../doubles/session_store_double.dart';

/// Le jeton part vers le serveur sans transformation : c'est le système qui l'a produit,
/// et le moindre découpage le rendrait inutilisable.
void main() {
  group('AppareilsApi', () {
    test('enregistre le jeton et la plateforme', () async {
      final appels = <(String, Object?)>[];
      final api = AppareilsApi(_client(appels));

      await api.enregistrer('fZ1p:APA91b_jeton', plateforme: 'android');

      expect(appels.single.$1, '/me/devices');
      expect(appels.single.$2, {
        'token': 'fZ1p:APA91b_jeton',
        'platform': 'android',
      });
    });

    test('retire le jeton en l’échappant dans le chemin', () async {
      final appels = <(String, Object?)>[];
      final api = AppareilsApi(_client(appels));

      // Un jeton FCM contient « : » : non échappé, il découperait le chemin.
      await api.retirer('fZ1p:APA91b_jeton');

      expect(appels.single.$1, '/me/devices/fZ1p%3AAPA91b_jeton');
    });
  });
}

ApiClient _client(List<(String, Object?)> appels) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        appels.add((options.path, options.data));
        handler.resolve(
          Response<Object?>(requestOptions: options, statusCode: 204),
        );
      },
    ),
  );

  return ApiClient(SessionStoreDouble(jetonAcces: 'jeton'), dio: dio);
}
