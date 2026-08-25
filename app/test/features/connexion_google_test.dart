import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/auth/service_google.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/auth/connexion_page.dart';

import '../doubles/session_store_double.dart';

/// Connexion Google depuis l'écran de connexion — `EF-AUTH-06`.
///
/// Le bouton n'apparaît qu'à deux conditions réunies : l'instance possède la clé, et
/// l'application embarque un client capable d'obtenir un jeton. Manquer l'une des deux
/// donnerait un bouton condamné à échouer, ce que l'écran des moyens de connexion
/// s'interdit déjà.
void main() {
  group('Connexion Google', () {
    testWidgets('aucun bouton si l’instance n’a pas la clé', (tester) async {
      await _monter(tester, cleInstance: false);

      expect(find.byKey(const Key('connexion-google')), findsNothing);
    });

    testWidgets('aucun bouton si l’application n’embarque pas de client', (
      tester,
    ) async {
      await _monter(tester, service: _ServiceDouble(disponible: false));

      expect(find.byKey(const Key('connexion-google')), findsNothing);
    });

    testWidgets('le bouton apparaît quand les deux conditions sont réunies', (
      tester,
    ) async {
      await _monter(tester);

      expect(find.byKey(const Key('connexion-google')), findsOneWidget);
    });

    testWidgets('appuyer présente le jeton obtenu à /auth/google', (
      tester,
    ) async {
      final serveur = _ServeurAuth();
      await _monter(
        tester,
        serveur: serveur,
        service: _ServiceDouble(jeton: 'jeton-de-google'),
      );

      await tester.tap(find.byKey(const Key('connexion-google')));
      await tester.pumpAndSettle();

      expect(serveur.jetonsRecus, ['jeton-de-google']);
    });

    testWidgets('une annulation ne présente rien et n’affiche pas d’erreur', (
      tester,
    ) async {
      // Annuler le sélecteur de compte est un geste ordinaire, pas un échec : afficher
      // une erreur pour cela serait une punition.
      final serveur = _ServeurAuth();
      await _monter(tester, serveur: serveur, service: _ServiceDouble());

      await tester.tap(find.byKey(const Key('connexion-google')));
      await tester.pumpAndSettle();

      expect(serveur.jetonsRecus, isEmpty);
      expect(find.byType(ConnexionPage), findsOneWidget);
      expect(find.textContaining('rreur'), findsNothing);
    });
  });
}

Future<void> _monter(
  WidgetTester tester, {
  bool cleInstance = true,
  _ServiceDouble? service,
  _ServeurAuth? serveur,
}) async {
  final stockage = SessionStoreDouble();
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..interceptors.add(serveur ?? _ServeurAuth());
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(stockage),
      apiClientProvider.overrideWithValue(ApiClient(stockage, dio: dio)),
      serviceGoogleProvider.overrideWithValue(
        service ?? _ServiceDouble(jeton: 'jeton'),
      ),
      fournisseursDisponiblesProvider.overrideWith(
        (ref) async => cleInstance ? const {'google'} : const <String>{},
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  conteneur.read(routeurProvider).go(PpRoutes.connexion);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: const PartyPlanApp(),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(ConnexionPage), findsOneWidget);
}

class _ServiceDouble implements ServiceGoogle {
  _ServiceDouble({this.jeton, this.disponible = true});

  final String? jeton;

  @override
  final bool disponible;

  @override
  Future<String?> obtenirJetonIdentite() async => jeton;

  @override
  Future<void> oublier() async {}
}

/// Ne simule que `/auth/google` : le routeur et la session restent les vrais objets.
class _ServeurAuth extends Interceptor {
  final List<String> jetonsRecus = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path != '/auth/google') {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }

    jetonsRecus.add(
      (options.data! as Map<String, dynamic>)['idToken'] as String,
    );

    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'accessToken': 'jeton-test',
          'refreshToken': 'rafraichissement-test',
          'expiresIn': 900,
        },
      ),
    );
  }
}
