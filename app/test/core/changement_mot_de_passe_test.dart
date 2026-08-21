import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/comptes_api.dart';

import '../doubles/session_store_double.dart';

/// Enregistre les chemins appelés et répond à chacun.
class _Serveur extends Interceptor {
  final List<String> chemins = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    chemins.add(options.path);

    final corps = options.path == '/auth/refresh'
        ? {'accessToken': 'jeton-renouvele', 'refreshToken': 'rafraichi'}
        : <String, Object?>{};

    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: corps,
      ),
    );
  }
}

void main() {
  test('changer son mot de passe renouvelle le jeton d’accès', () async {
    // Le jeton porte la revendication « doit changer son mot de passe » : le serveur
    // continuerait de refuser chaque requête en 403 pendant toute la durée de vie du
    // jeton, et l'application boucle alors sur son formulaire.
    final serveur = _Serveur();
    final dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..interceptors.add(serveur);
    final stockage = SessionStoreDouble(
      jetonAcces: 'jeton-perime',
      jetonRafraichissement: 'rafraichissement',
    );

    final api = ComptesApi(ApiClient(stockage, dio: dio), stockage);

    await api.changerMotDePasse(actuel: 'ancien', nouveau: 'nouveau-mot-passe');

    expect(serveur.chemins, ['/auth/password/change', '/auth/refresh']);
    expect(stockage.jetonAcces, 'jeton-renouvele');
    expect(stockage.jetonRafraichissement, 'rafraichi');
  });
}
