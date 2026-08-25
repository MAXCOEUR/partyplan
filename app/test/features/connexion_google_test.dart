import 'dart:async';

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

    testWidgets('aucun bouton si la plateforme refuse le parcours programmatique', (
      tester,
    ) async {
      // Sur le Web, google_sign_in 7.x lève UnsupportedError sur authenticate() et
      // impose son propre bouton rendu. Un OutlinedButton y serait cliquable et sans
      // effet : le pire des trois états.
      await _monter(
        tester,
        service: _ServiceDouble(jeton: 'jeton', parcoursProgrammatique: false),
      );

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

      // La surface de test est plus courte qu'un téléphone : sans ce défilement, le
      // bouton se trouve hors du viewport et l'appui n'a aucun effet, ce qui produit un
      // échec trompeur. Le logo a grandi, la mise en page a suivi.
      final bouton = find.byKey(const Key('connexion-google'));
      await tester.ensureVisible(bouton);
      await tester.pumpAndSettle();
      await tester.tap(bouton);
      await tester.pumpAndSettle();

      expect(serveur.jetonsRecus, ['jeton-de-google']);
    });

    testWidgets('un jeton arrivé par le flux ouvre une session', (
      tester,
    ) async {
      // Chemin du Web : la personne clique dans le bouton rendu par le SDK Google,
      // que l'application ne contrôle pas. Le jeton ne revient donc pas d'un appel
      // mais du flux d'événements d'authentification.
      final serveur = _ServeurAuth();
      final service = _ServiceDouble(parcoursProgrammatique: false);
      await _monter(tester, serveur: serveur, service: service);

      service.emettre('jeton-du-bouton-rendu');
      await tester.pumpAndSettle();

      expect(serveur.jetonsRecus, ['jeton-du-bouton-rendu']);
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
  _ServiceDouble({
    this.jeton,
    this.disponible = true,
    this.parcoursProgrammatique = true,
  });

  final String? jeton;

  @override
  final bool disponible;

  @override
  final bool parcoursProgrammatique;

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
