import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/core/temps_reel/message_temps_reel.dart';
import 'package:partyplan/core/temps_reel/service_temps_reel.dart';

import '../doubles/activite_api_double.dart';
import '../doubles/session_store_double.dart';

const _evenementId = '01a023e7-9cb7-714d-8383-b4959de88ea8';

/// Téléphone verrouillé avec une soirée ouverte, puis rallumé.
///
/// Android suspend l'application et le système coupe la connexion temps réel. La reprise
/// automatique de SignalR renonce au bout de quarante-deux secondes — 0, 2 s, 10 s, 30 s
/// puis abandon —, et rien n'observait le retour au premier plan. Le temps réel restait
/// donc mort pour toute la durée de la visite, sans le moindre signe.
void main() {
  testWidgets('la mise en arrière-plan ferme la connexion temps réel', (
    tester,
  ) async {
    final service = _ServiceDouble();
    await _monter(tester, service: service);

    await _endormir(tester);

    // Fermée volontairement plutôt que laissée mourir : Android va la couper de toute
    // façon, et tenir un socket pendant que l'écran est éteint n'use que la batterie.
    expect(service.deconnexions, 1);
  });

  testWidgets('le retour au premier plan rouvre la connexion temps réel', (
    tester,
  ) async {
    final service = _ServiceDouble();
    await _monter(tester, service: service);

    final avant = service.connexions;

    await _endormir(tester);
    await _reveiller(tester);

    expect(service.connexions, greaterThan(avant));
  });

  testWidgets('le retour au premier plan renouvelle la session', (
    tester,
  ) async {
    // Le jeton d'accès ne vit que quinze minutes. Après un écran verrouillé, le hub le
    // présenterait périmé et se ferait refuser en silence : il n'y a pas, pour une
    // connexion SignalR, le rejeu sur 401 qui rattrape les appels REST.
    final serveur = _Serveur();
    await _monter(tester, service: _ServiceDouble(), serveur: serveur);

    final avant = serveur.renouvellements;

    await _endormir(tester);
    await _reveiller(tester);

    expect(serveur.renouvellements, greaterThan(avant));
  });

  testWidgets('le retour au premier plan relit ce que l’écran affiche', (
    tester,
  ) async {
    final serveur = _Serveur();
    await _monter(tester, service: _ServiceDouble(), serveur: serveur);

    final avant = serveur.lecturesEvenement;

    await _endormir(tester);
    await _reveiller(tester);

    // Ce qui a été manqué pendant la coupure est par définition inconnu : la reprise
    // impose une relecture complète, comme après une reconnexion (RG-RT-03).
    expect(
      serveur.lecturesEvenement,
      greaterThan(avant),
      reason: 'le retour de veille doit repartir au serveur',
    );
  });
}

Future<void> _endormir(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pumpAndSettle();
}

Future<void> _reveiller(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

Future<void> _monter(
  WidgetTester tester, {
  required ServiceTempsReel service,
  _Serveur? serveur,
}) async {
  final stockage = SessionStoreDouble(
    jetonAcces: 'jeton',
    jetonRafraichissement: 'rafraichissement',
  );
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..interceptors.add(serveur ?? _Serveur());

  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(stockage),
      activiteApiProvider.overrideWithValue(ActiviteApiDouble()),
      apiClientProvider.overrideWithValue(ApiClient(stockage, dio: dio)),
      serviceTempsReelProvider.overrideWithValue(service),
    ],
  );
  addTearDown(conteneur.dispose);

  conteneur.read(routeurProvider).go(PpRoutes.versEvenement(_evenementId));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: const PartyPlanApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _ServiceDouble implements ServiceTempsReel {
  final _messages = StreamController<MessageTempsReel>.broadcast();
  final _reconnexions = StreamController<void>.broadcast();

  int connexions = 0;
  int deconnexions = 0;

  @override
  Stream<MessageTempsReel> get messages => _messages.stream;

  @override
  Stream<void> get reconnexions => _reconnexions.stream;

  @override
  Future<void> connecter(String evenementId) async => connexions++;

  @override
  Future<void> deconnecter() async => deconnexions++;
}

class _Serveur extends Interceptor {
  int lecturesEvenement = 0;
  int renouvellements = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final chemin = options.path;

    if (chemin == '/auth/refresh') {
      renouvellements++;
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'accessToken': 'jeton-neuf',
            'refreshToken': 'rafraichissement-neuf',
          },
        ),
      );
      return;
    }

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
