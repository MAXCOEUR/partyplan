import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/auth/service_google.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/profil/connexions_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

/// Rattachement d'un service tiers depuis l'écran des moyens de connexion — `EF-AUTH-08`.
void main() {
  group('Rattachement Google', () {
    testWidgets('un bouton rattache quand le client est embarqué', (
      tester,
    ) async {
      final serveur = _Serveur();
      await _monter(tester, serveur: serveur);

      await tester.tap(find.byKey(const Key('rattacher-google')));
      await tester.pumpAndSettle();

      expect(serveur.rattachements, ['jeton-de-google']);
    });

    testWidgets('aucun bouton si l’application n’embarque pas de client', (
      tester,
    ) async {
      await _monter(tester, service: _ServiceDouble(disponible: false));

      // Le serveur accepte Google, mais l'application ne sait pas obtenir de jeton :
      // proposer le geste reviendrait à promettre un échec.
      expect(find.byKey(const Key('rattacher-google')), findsNothing);
    });

    testWidgets('une annulation ne rattache rien', (tester) async {
      final serveur = _Serveur();
      await _monter(tester, serveur: serveur, service: _ServiceDouble());

      await tester.tap(find.byKey(const Key('rattacher-google')));
      await tester.pumpAndSettle();

      expect(serveur.rattachements, isEmpty);
    });
  });
}

Future<void> _monter(
  WidgetTester tester, {
  _Serveur? serveur,
  _ServiceDouble? service,
}) async {
  final stockage = SessionStoreDouble(jetonAcces: 'jeton');
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..interceptors.add(serveur ?? _Serveur());
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(stockage),
      apiClientProvider.overrideWithValue(ApiClient(stockage, dio: dio)),
      serviceGoogleProvider.overrideWithValue(
        service ?? _ServiceDouble(jeton: 'jeton-de-google'),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const ConnexionsPage(), conteneur: conteneur);
  await tester.pumpAndSettle();
}

class _ServiceDouble implements ServiceGoogle {
  _ServiceDouble({this.jeton, this.disponible = true});

  final String? jeton;

  @override
  final bool disponible;

  @override
  bool get parcoursProgrammatique => true;

  final _jetons = StreamController<String>.broadcast();

  @override
  Stream<String> get jetons => _jetons.stream;

  /// Simule l'arrivée d'un jeton par le bouton rendu par Google.
  void emettre(String valeur) => _jetons.add(valeur);

  @override
  Future<void> preparer() async {}

  @override
  Future<String?> obtenirJetonIdentite() async => jeton;

  @override
  Future<void> oublier() async {}
}

/// Google configuré côté instance et non rattaché : l'état où le rattachement a un sens.
class _Serveur extends Interceptor {
  final List<String> rattachements = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path == '/auth/providers') {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'hasPassword': true,
            'providers': [
              {'provider': 'google', 'configured': true, 'linked': false},
            ],
          },
        ),
      );
      return;
    }

    if (options.path == '/auth/providers/google/link') {
      rattachements.add(
        (options.data! as Map<String, dynamic>)['idToken'] as String,
      );
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 204),
      );
      return;
    }

    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
  }
}
