import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/network/discussion_api.dart';
import 'package:partyplan/core/providers.dart';

import '../doubles/session_store_double.dart';

/// Arrivée d'un message par le temps réel.
///
/// Le fil est un notifier paginé : l'invalider ferait perdre les pages remontées et la
/// position de lecture à chaque message reçu, ce qui est brutal dans une conversation.
/// Il lui faut donc un rafraîchissement qui fusionne au lieu de repartir de zéro.
void main() {
  group('Rafraîchissement du fil', () {
    test(
      'un nouveau message apparaît sans effacer les pages remontées',
      () async {
        final api = _ApiCroissante(total: 120);
        final conteneur = _conteneur(api);

        final notifier = conteneur.read(filDiscussionProvider('ev-1').notifier);
        await conteneur.read(filDiscussionProvider('ev-1').future);

        // Une remontée : le fil contient désormais deux pages.
        await notifier.chargerPlusAncien();
        final avant = conteneur.read(filDiscussionProvider('ev-1')).value!;
        expect(avant.messages.length, 100);
        expect(avant.messages.first.corps, 'message 21');

        // Quelqu'un envoie un message ailleurs, et le serveur le diffuse.
        api.total = 121;
        await notifier.rafraichir();

        final apres = conteneur.read(filDiscussionProvider('ev-1')).value!;

        expect(
          apres.messages.last.corps,
          'message 121',
          reason: 'le nouveau message doit apparaître',
        );
        expect(
          apres.messages.first.corps,
          'message 21',
          reason: 'les pages remontées doivent survivre',
        );
        expect(apres.messages.length, 101);
      },
    );

    test('un rafraîchissement raté ne casse rien et ne lève pas', () async {
      // Le rafraîchissement est déclenché par le temps réel, sans que personne l'ait
      // demandé. Lever produirait une exception asynchrone non capturée, et remplacer
      // l'état par une erreur effacerait une conversation lisible pour un incident
      // réseau passager.
      final api = _ApiCroissante(total: 3);
      final conteneur = _conteneur(api);

      final notifier = conteneur.read(filDiscussionProvider('ev-1').notifier);
      await conteneur.read(filDiscussionProvider('ev-1').future);

      api.enPanne = true;
      await notifier.rafraichir();

      final apres = conteneur.read(filDiscussionProvider('ev-1'));

      expect(
        apres.hasError,
        isFalse,
        reason: 'l’écran ne doit pas passer en erreur',
      );
      expect(apres.value!.messages.length, 3, reason: 'le fil est conservé');
    });

    test('un message modifié est mis à jour, pas dupliqué', () async {
      // Un message modifié garde son identifiant : le fusionner sur la clé évite qu'il
      // apparaisse deux fois, une fois dans son ancienne version.
      final api = _ApiCroissante(total: 3);
      final conteneur = _conteneur(api);

      final notifier = conteneur.read(filDiscussionProvider('ev-1').notifier);
      await conteneur.read(filDiscussionProvider('ev-1').future);

      api.suffixe = ' (modifié)';
      await notifier.rafraichir();

      final apres = conteneur.read(filDiscussionProvider('ev-1')).value!;

      expect(apres.messages.length, 3);
      expect(apres.messages.last.corps, 'message 3 (modifié)');
    });
  });
}

/// API dont l'historique peut grandir entre deux lectures.
class _ApiCroissante implements DiscussionApi {
  _ApiCroissante({required this.total});

  int total;
  String suffixe = '';
  bool enPanne = false;

  @override
  Future<FilDiscussion> lire(
    String evenementId, {
    String? avant,
    int limite = 50,
  }) async {
    if (enPanne) {
      throw Exception('réseau indisponible');
    }

    final tous = [
      for (var i = 1; i <= total; i++)
        Message(
          id: 'm$i',
          auteurMembreId: 'autre',
          auteur: 'Lucas',
          auteurPhoto: null,
          corps: 'message $i$suffixe',
          urlPieceJointe: null,
          sondageId: null,
          citation: null,
          reactions: const [],
          mentions: const [],
          leMien: false,
          modifie: suffixe.isNotEmpty,
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
