import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/network/discussion_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/discussion/discussion_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

Message _message(String id, {bool leMien = false}) => Message(
  id: id,
  auteurMembreId: leMien ? 'moi' : 'lucas',
  auteur: leMien ? 'Moi' : 'Lucas',
  auteurPhoto: null,
  corps: 'texte $id',
  urlPieceJointe: null,
  sondageId: null,
  citation: null,
  reactions: const [],
  mentions: const [],
  leMien: leMien,
  modifie: false,
  supprime: false,
  epingle: false,
  envoyeLe: DateTime(2026, 8, 20, 20, int.parse(id.substring(1))),
);

/// API de discussion qui rend un fil arrêté, et retient ce qu'on lui marque comme lu.
class DiscussionApiDouble implements DiscussionApi {
  DiscussionApiDouble({required this.fil});

  final FilDiscussion fil;
  final marques = <String>[];

  @override
  Future<FilDiscussion> lire(
    String evenementId, {
    String? avant,
    int limite = 50,
  }) async => fil;

  @override
  Future<void> marquerLu(String evenementId, String messageId) async =>
      marques.add(messageId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} hors du périmètre');
}

Future<DiscussionApiDouble> _monter(
  WidgetTester tester, {
  required int nonLus,
  String? premierNonLuId,
}) async {
  final api = DiscussionApiDouble(
    fil: FilDiscussion(
      messages: [_message('m1'), _message('m2'), _message('m3')],
      encorePlusHaut: false,
      nonLus: nonLus,
      premierNonLuId: premierNonLuId,
    ),
  );

  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      discussionApiProvider.overrideWithValue(api),
      membresProvider('ev-1').overrideWith((ref) async => <Membre>[]),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: DiscussionPage(evenementId: 'ev-1')),
    conteneur: conteneur,
  );

  return api;
}

void main() {
  group('Reprise de lecture', () {
    testWidgets('une ligne marque le début des messages non lus', (
      tester,
    ) async {
      // Revenir sur une conversation après une absence, c'est chercher où on s'est
      // arrêté. Sans repère visible, il faut relire pour le retrouver.
      await _monter(tester, nonLus: 2, premierNonLuId: 'm2');

      expect(find.text('Nouveaux messages'), findsOneWidget);
    });

    testWidgets('à jour, aucune ligne n’encombre le fil', (tester) async {
      await _monter(tester, nonLus: 0);

      expect(find.text('Nouveaux messages'), findsNothing);
    });

    testWidgets('la ligne s’effface après dix secondes', (tester) async {
      // Elle sert à se repérer en arrivant, pas à rester : passé le premier regard,
      // c'est une barre qui traverse la conversation sans plus rien dire.
      await _monter(tester, nonLus: 2, premierNonLuId: 'm2');

      expect(find.text('Nouveaux messages'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('Nouveaux messages'), findsNothing);
    });

    testWidgets('la lecture est signalée au serveur', (tester) async {
      final api = await _monter(tester, nonLus: 2, premierNonLuId: 'm2');

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Le dernier message du fil, non le premier non lu : tout ce qui est affiché
      // a été vu.
      expect(api.marques, ['m3']);
    });

    testWidgets('un fil déjà à jour n’envoie pas de marquage inutile', (
      tester,
    ) async {
      final api = await _monter(tester, nonLus: 0);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(api.marques, isEmpty);
    });
  });
}
