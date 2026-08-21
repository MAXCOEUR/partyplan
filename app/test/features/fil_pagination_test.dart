import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/network/discussion_api.dart';
import 'package:partyplan/core/providers.dart';

import '../doubles/session_store_double.dart';

/// Fil de discussion servi par pages, comme l'API le fait.
class DiscussionApiPaginee implements DiscussionApi {
  DiscussionApiPaginee(this.total);

  /// Nombre de messages dans l'historique complet, du plus ancien au plus récent.
  final int total;

  final demandes = <String?>[];

  @override
  Future<FilDiscussion> lire(
    String evenementId, {
    String? avant,
    int limite = 50,
  }) async {
    demandes.add(avant);

    final tous = [
      for (var i = 1; i <= total; i++)
        Message(
          id: 'm$i',
          auteurMembreId: 'autre',
          auteur: 'Lucas',
          corps: 'message $i',
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
      nonLus: 0,
      premierNonLuId: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} hors du périmètre du test',
  );
}

ProviderContainer _conteneur(DiscussionApi api) {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      discussionApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(conteneur.dispose);

  return conteneur;
}

void main() {
  group('Pagination du fil', () {
    test(
      'le premier chargement ne demande que les derniers messages',
      () async {
        final api = DiscussionApiPaginee(120);
        final conteneur = _conteneur(api);

        final fil = await conteneur.read(filDiscussionProvider('ev-1').future);

        fil.messages.length.shouldBeLessThanOrEqualTo50();
        fil.messages.last.corps.shouldBe('message 120');
        fil.encorePlusHaut.shouldBeTrue();
        api.demandes.shouldEqual([null]);
      },
    );

    test(
      'remonter le fil ajoute les plus anciens en tête, sans doublon',
      () async {
        final api = DiscussionApiPaginee(120);
        final conteneur = _conteneur(api);

        await conteneur.read(filDiscussionProvider('ev-1').future);
        await conteneur
            .read(filDiscussionProvider('ev-1').notifier)
            .chargerPlusAncien();

        final fil = conteneur.read(filDiscussionProvider('ev-1')).requireValue;

        fil.messages.length.shouldBe(100);
        fil.messages.first.corps.shouldBe('message 21');
        fil.messages.last.corps.shouldBe('message 120');
        // Le second appel part du plus ancien déjà connu.
        api.demandes.shouldEqual([null, 'm71']);
      },
    );

    test('arrivé au début du fil, plus rien n’est demandé', () async {
      final api = DiscussionApiPaginee(60);
      final conteneur = _conteneur(api);

      await conteneur.read(filDiscussionProvider('ev-1').future);
      final notifieur = conteneur.read(filDiscussionProvider('ev-1').notifier);

      await notifieur.chargerPlusAncien();
      await notifieur.chargerPlusAncien();

      // Deux pages suffisent à tout couvrir : la troisième demande n'a pas lieu.
      api.demandes.length.shouldBe(2);
      conteneur
          .read(filDiscussionProvider('ev-1'))
          .requireValue
          .encorePlusHaut
          .shouldBeFalse();
    });
  });
}

extension on int {
  void shouldBe(int attendu) => expect(this, attendu);

  void shouldBeLessThanOrEqualTo50() => expect(this, lessThanOrEqualTo(50));
}

extension on String? {
  void shouldBe(String? attendu) => expect(this, attendu);
}

extension on bool {
  void shouldBeTrue() => expect(this, isTrue);

  void shouldBeFalse() => expect(this, isFalse);
}

extension on List<String?> {
  void shouldEqual(List<String?> attendu) => expect(this, attendu);
}
