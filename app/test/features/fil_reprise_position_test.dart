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

/// Historique paginé, avec un repère de lecture posé au milieu.
class DiscussionApiHistorique implements DiscussionApi {
  DiscussionApiHistorique({required this.total, required this.premierNonLu});

  final int total;

  /// Numéro du premier message non lu, entre 1 et [total].
  final int premierNonLu;

  final pages = <String?>[];
  final marques = <String>[];

  @override
  Future<void> marquerLu(String evenementId, String messageId) async =>
      marques.add(messageId);

  @override
  Future<FilDiscussion> lire(
    String evenementId, {
    String? avant,
    int limite = 50,
  }) async {
    pages.add(avant);

    final tous = [
      for (var i = 1; i <= total; i++)
        Message(
          id: 'm$i',
          auteurMembreId: 'lucas',
          auteur: 'Lucas',
          corps: 'texte $i',
          urlPieceJointe: null,
          sondageId: null,
          citation: null,
          reactions: const [],
          mentions: const [],
          leMien: false,
          modifie: false,
          supprime: false,
          epingle: false,
          envoyeLe: DateTime(2026, 8, 1).add(Duration(minutes: i)),
        ),
    ];

    final finExclue = avant == null
        ? tous.length
        : tous.indexWhere((m) => m.id == avant);
    final debut = (finExclue - limite).clamp(0, finExclue);

    return FilDiscussion(
      messages: tous.sublist(debut, finExclue),
      encorePlusHaut: debut > 0,
      nonLus: total - premierNonLu + 1,
      premierNonLuId: 'm$premierNonLu',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} hors du périmètre');
}

Future<DiscussionApiHistorique> _monter(
  WidgetTester tester, {
  required int total,
  required int premierNonLu,
}) async {
  final api = DiscussionApiHistorique(total: total, premierNonLu: premierNonLu);

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
  group('Reprise à l’endroit où la lecture s’est arrêtée', () {
    testWidgets('à jour, le fil s’ouvre sur le dernier message', (
      tester,
    ) async {
      await _monter(tester, total: 60, premierNonLu: 61);

      expect(find.text('texte 60'), findsOneWidget);
      // Le début du fil est loin au-dessus : il n'est pas rendu.
      expect(find.text('texte 1'), findsNothing);
    });

    testWidgets('avec des non-lus, le fil s’ouvre sur le premier non lu', (
      tester,
    ) async {
      // Arriver en bas d'une conversation de soixante messages dont quarante sont
      // nouveaux oblige à remonter à l'aveugle pour retrouver le fil de ce qui s'est
      // dit.
      await _monter(tester, total: 60, premierNonLu: 21);

      expect(find.text('texte 21'), findsOneWidget);
      expect(find.text('Nouveaux messages'), findsOneWidget);
      // Le dernier message est plus bas, hors de la fenêtre.
      expect(find.text('texte 60'), findsNothing);
    });

    testWidgets('les pages manquantes sont chargées pour atteindre le repère', (
      tester,
    ) async {
      // Le premier non lu se trouve au-delà de la première page : sans rattrapage, il
      // n'y a rien à montrer et le fil s'ouvre en bas comme si tout était lu.
      final api = await _monter(tester, total: 120, premierNonLu: 40);

      expect(find.text('texte 40'), findsOneWidget);
      // Deux pages suffisent ici : la dernière, puis celle qui la précède.
      expect(api.pages.length, 2);
    });

    testWidgets('la vue ne saute pas quand la ligne s’effface', (tester) async {
      // La ligne s'efface au bout de dix secondes, l'ancrage non : sinon la
      // conversation saute jusqu'en bas sous les yeux de qui était en train de lire.
      await _monter(tester, total: 60, premierNonLu: 21);

      expect(find.text('texte 21'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('Nouveaux messages'), findsNothing);
      expect(find.text('texte 21'), findsOneWidget);
      expect(find.text('texte 60'), findsNothing);
    });

    testWidgets('un retard démesuré ne charge pas tout l’historique', (
      tester,
    ) async {
      // Après trois semaines d'absence, « tout jusqu'au premier non lu » ferait
      // télécharger la conversation entière : le rattrapage est borné.
      final api = await _monter(tester, total: 1000, premierNonLu: 1);

      expect(api.pages.length, lessThanOrEqualTo(4));
      expect(find.text('Nouveaux messages'), findsNothing);
    });
  });
}
