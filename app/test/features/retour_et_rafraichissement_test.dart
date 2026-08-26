import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/models/activite.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';
import 'package:partyplan/features/evenement/coquille_evenement.dart';

import '../doubles/session_store_double.dart';

const _evenementId = '01a023e7-9cb7-714d-8383-b4959de88ea8';

/// Deux défauts constatés en production le 25/08/2026.
void main() {
  group('Retour depuis une soirée', () {
    testWidgets('on revient à l’accueil même sans pile de navigation', (
      tester,
    ) async {
      // Cas réel : après avoir rejoint par un lien, `context.go` a vidé la pile.
      // Un BackButton n'a alors rien à dépiler et laisse la personne enfermée.
      final serveur = _Serveur();
      await _monter(
        tester,
        serveur,
        entree: PpRoutes.versEvenement(_evenementId),
      );

      expect(find.byType(CoquilleEvenement), findsOneWidget);

      await tester.tap(find.byKey(const Key('retour-evenement')));
      await tester.pumpAndSettle();

      expect(find.byType(AccueilPage), findsOneWidget);
    });
  });

  group('Rafraîchissement', () {
    testWidgets('rouvrir une soirée relit le serveur', (tester) async {
      // Riverpod ne rejette pas un FutureProvider.family quand plus personne ne
      // l'écoute : sans invalidation explicite, la seconde ouverture affiche les
      // données de la première, indéfiniment.
      final serveur = _Serveur();
      await _monter(
        tester,
        serveur,
        entree: PpRoutes.versEvenement(_evenementId),
      );

      final premier = serveur.lecturesEvenement;
      expect(premier, greaterThan(0));

      await tester.tap(find.byKey(const Key('retour-evenement')));
      await tester.pumpAndSettle();

      _routeur.go(PpRoutes.versEvenement(_evenementId));
      await tester.pumpAndSettle();

      expect(
        serveur.lecturesEvenement,
        greaterThan(premier),
        reason: 'la réouverture doit repartir au serveur',
      );
    });

    testWidgets('un bouton d’actualisation existe et relit le serveur', (
      tester,
    ) async {
      // Le RefreshIndicator seul exige un geste de survol : à la souris, sur le
      // navigateur, il est inatteignable. Il faut une commande visible.
      final serveur = _Serveur();
      await _monter(
        tester,
        serveur,
        entree: PpRoutes.versEvenement(_evenementId),
      );

      final avant = serveur.lecturesEvenement;

      await tester.tap(find.byKey(const Key('actualiser-evenement')));
      await tester.pumpAndSettle();

      expect(serveur.lecturesEvenement, greaterThan(avant));
    });
  });
}

/// Le routeur du montage courant, pour naviguer depuis le corps d'un test.
dynamic _routeur;

Future<void> _monter(
  WidgetTester tester,
  _Serveur serveur, {
  required String entree,
}) async {
  final stockage = SessionStoreDouble(jetonAcces: 'jeton');
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..interceptors.add(serveur);
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(stockage),
      // Le tableau de bord porte désormais un aperçu du fil d'activité : sans
      // cette substitution, il partirait chercher le réseau.
      filActiviteProvider.overrideWith((ref, id) async => PageActivite.vide),
      apiClientProvider.overrideWithValue(ApiClient(stockage, dio: dio)),
    ],
  );
  addTearDown(conteneur.dispose);

  final routeur = conteneur.read(routeurProvider);
  _routeur = routeur;
  routeur.go(entree);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: const PartyPlanApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Compte les lectures du résumé d'événement et répond des charges minimales.
class _Serveur extends Interceptor {
  int lecturesEvenement = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final chemin = options.path;

    if (chemin == '/events/$_evenementId') {
      lecturesEvenement++;
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: _resume,
        ),
      );
      return;
    }

    // Tout le reste : une réponse vide suffit, les sections se replient seules.
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
