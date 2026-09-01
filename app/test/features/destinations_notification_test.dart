import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/providers.dart';

import '../doubles/activite_api_double.dart';
import '../doubles/session_store_double.dart';

const _evenementId = '01a023e7-9cb7-714d-8383-b4959de88ea8';

/// Message de la page d'erreur du routeur, tel que l'utilisateur le lit.
const _pageIntrouvable =
    'Cet événement n’existe pas, ou tu n’en fais plus partie.';

/// Contrat partagé avec l'API, qui vérifie la même liste de son côté.
const _contrat = '../docs/api/destinations-notification.json';

/// Toute destination que l'API peut envoyer doit s'ouvrir dans l'application.
///
/// C'est le test qui manquait. Le module Courses envoyait `/events/{id}/courses` sans
/// qu'aucune route ne l'accueille : le lien tombait sur la page d'erreur, et rien, ni
/// côté serveur ni côté application, ne pouvait le signaler — les deux moitiés du
/// contrat vivent dans deux langages.
void main() {
  final motifs =
      (jsonDecode(File(_contrat).readAsStringSync()) as List<dynamic>)
          .cast<String>();

  test('le contrat des destinations n’est pas vide', () {
    // Un fichier vide ou mal lu ferait passer toute la suite sans rien vérifier.
    expect(motifs, isNotEmpty);
  });

  for (final motif in motifs) {
    testWidgets('la destination $motif s’ouvre', (tester) async {
      final chemin = motif.replaceAll('{eventId}', _evenementId);

      await _monter(tester, entree: chemin);

      expect(
        find.text(_pageIntrouvable),
        findsNothing,
        reason: '$motif ne correspond à aucune route de l’application',
      );
    });
  }
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

/// Répond des charges minimales : on vérifie qu'une route existe, pas ce qu'elle affiche.
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
