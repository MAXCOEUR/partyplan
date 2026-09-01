import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';
import 'package:partyplan/features/evenement/coquille_evenement.dart';

import '../doubles/activite_api_double.dart';
import '../doubles/session_store_double.dart';

const _evenementId = '01a023e7-9cb7-714d-8383-b4959de88ea8';

/// Rangs des onglets, dans l'ordre de la barre du bas.
const _accueil = 0;
const _courses = 1;
const _depenses = 2;

void main() {
  group('Ouverture depuis un lien de notification', () {
    testWidgets('un lien vers les courses ouvre l’onglet Courses', (
      tester,
    ) async {
      // Le module Courses envoie ses notifications vers cette adresse. Sans route
      // correspondante, go_router affiche sa page d'erreur — « cet événement n'existe
      // pas », alors qu'il existe et qu'on en est membre.
      await _monter(tester, entree: PpRoutes.versCourses(_evenementId));

      expect(find.byType(CoquilleEvenement), findsOneWidget);
      expect(_ongletCourant(tester), _courses);
    });

    testWidgets('un lien vers les dépenses ouvre l’onglet Dépenses', (
      tester,
    ) async {
      await _monter(tester, entree: PpRoutes.versDepenses(_evenementId));

      expect(_ongletCourant(tester), _depenses);
    });

    testWidgets('l’adresse de la soirée seule ouvre l’onglet Accueil', (
      tester,
    ) async {
      await _monter(tester, entree: PpRoutes.versEvenement(_evenementId));

      expect(_ongletCourant(tester), _accueil);
    });
  });

  group('Retour dans une soirée', () {
    testWidgets('le retour revient à l’onglet précédent', (tester) async {
      await _monter(tester, entree: PpRoutes.versEvenement(_evenementId));

      await _allerA(tester, _courses);
      await _allerA(tester, _depenses);

      await _retourSysteme(tester);

      expect(_ongletCourant(tester), _courses);
      expect(find.byType(CoquilleEvenement), findsOneWidget);
    });

    testWidgets('revenir sur un onglet déjà visité replie l’historique', (
      tester,
    ) async {
      // Sans ce repli, dix allers-retours entre deux onglets imposeraient dix appuis
      // sur retour pour sortir de la soirée.
      await _monter(tester, entree: PpRoutes.versEvenement(_evenementId));

      await _allerA(tester, _courses);
      await _allerA(tester, _depenses);
      await _allerA(tester, _courses);

      await _retourSysteme(tester);

      expect(_ongletCourant(tester), _accueil);
    });

    testWidgets('le retour depuis le premier onglet quitte la soirée', (
      tester,
    ) async {
      await _monter(tester, entree: PpRoutes.versEvenement(_evenementId));

      await _retourSysteme(tester);

      expect(find.byType(AccueilPage), findsOneWidget);
    });

    testWidgets('la flèche du haut recule aussi dans les onglets', (
      tester,
    ) async {
      await _monter(tester, entree: PpRoutes.versEvenement(_evenementId));

      await _allerA(tester, _courses);

      await tester.tap(find.byKey(const Key('retour-evenement')));
      await tester.pumpAndSettle();

      expect(_ongletCourant(tester), _accueil);
      expect(find.byType(CoquilleEvenement), findsOneWidget);
    });
  });

  group('Sortie de la soirée', () {
    testWidgets('la croix quitte la soirée quel que soit l’onglet', (
      tester,
    ) async {
      await _monter(tester, entree: PpRoutes.versEvenement(_evenementId));

      await _allerA(tester, _courses);
      await _allerA(tester, _depenses);

      await tester.tap(find.byKey(const Key('quitter-evenement')));
      await tester.pumpAndSettle();

      expect(find.byType(AccueilPage), findsOneWidget);
    });
  });
}

/// Rang de l'onglet ouvert, lu sur la barre de navigation elle-même.
int _ongletCourant(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _allerA(WidgetTester tester, int onglet) async {
  final barre = tester.widget<NavigationBar>(find.byType(NavigationBar));
  barre.onDestinationSelected!(onglet);
  await tester.pumpAndSettle();
}

/// Le bouton retour du système, celui d'Android.
Future<void> _retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _monter(WidgetTester tester, {required String entree}) async {
  final stockage = SessionStoreDouble(jetonAcces: 'jeton');
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..interceptors.add(_Serveur());

  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(stockage),
      activiteApiProvider.overrideWithValue(ActiviteApiDouble()),
      apiClientProvider.overrideWithValue(ApiClient(stockage, dio: dio)),
    ],
  );
  addTearDown(conteneur.dispose);

  conteneur.read(routeurProvider).go(entree);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: const PartyPlanApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Répond des charges minimales : l'écran doit se monter, pas afficher des données.
class _Serveur extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final chemin = options.path;

    if (chemin == '/events/$_evenementId') {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: _resume,
        ),
      );
      return;
    }

    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: chemin.contains('members') || chemin.contains('items')
            ? const <Object?>[]
            : const <String, Object?>{},
      ),
    );
  }
}

const _resume = <String, Object?>{
  'id': _evenementId,
  'name': 'Raclette chez Léa',
  'startsAt': '2026-09-12T20:00:00Z',
  'endsAt': null,
  'address': null,
  'description': null,
  'coverImageUrl': null,
  'shortCode': 'RACL42',
  'inviteToken': 'jeton',
  'memberCount': 4,
  'goingCount': 3,
  'myRole': 'Owner',
  'myStatus': 'Going',
  'joinOpen': true,
  'archivedAt': null,
};
