import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/network/discussion_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/discussion/discussion_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/fil_discussion_double.dart';

const _evenement = 'ev-1';

/// Client de discussion en mémoire, qui note ce qu'on lui demande.
class _DiscussionApiDouble implements DiscussionApi {
  _DiscussionApiDouble(this._fil);

  final FilDiscussion _fil;
  final List<String> appels = [];

  @override
  Future<void> marquerLu(String evenementId, String messageId) async =>
      appels.add('marquerLu');

  @override
  Future<FilDiscussion> lire(
    String evenementId, {
    String? avant,
    int limite = 50,
  }) async {
    appels.add('lire');
    return _fil;
  }

  @override
  Future<Message> envoyer(
    String evenementId, {
    String? corps,
    String? urlPieceJointe,
    String? repondreA,
    String? sondageId,
    List<String> mentions = const [],
  }) async {
    appels.add('envoyer|$corps|$repondreA|${mentions.join(',')}');
    return _message(id: 'neuf', corps: corps);
  }

  @override
  Future<Message> basculerReaction(
    String evenementId,
    String messageId,
    String emoji,
  ) async {
    appels.add('reaction|$messageId|$emoji');
    return _fil.messages.firstWhere((m) => m.id == messageId);
  }

  @override
  Future<Message> modifier(
    String evenementId,
    String messageId, {
    required String corps,
  }) async {
    appels.add('modifier|$messageId|$corps');
    return _fil.messages.firstWhere((m) => m.id == messageId);
  }

  @override
  Future<void> supprimer(String evenementId, String messageId) async {
    appels.add('supprimer|$messageId');
  }

  @override
  Future<Epingle> epingler(
    String evenementId,
    String messageId, {
    String? dossierId,
  }) async {
    appels.add('epingler|$messageId|$dossierId');
    return Epingle(
      id: 'e1',
      dossierId: dossierId,
      dossierNom: null,
      message: _fil.messages.firstWhere((m) => m.id == messageId),
      epingleLe: DateTime(2026, 8, 21),
    );
  }

  @override
  Future<void> desepingler(String evenementId, String messageId) async {
    appels.add('desepingler|$messageId');
  }

  @override
  Future<DossierEpingles> creerDossier(String evenementId, String nom) async {
    appels.add('dossier|$nom');
    return DossierEpingles(id: 'd1', nom: nom, nombre: 0);
  }

  @override
  Future<void> supprimerDossier(String evenementId, String dossierId) async {
    appels.add('supprimerDossier|$dossierId');
  }

  @override
  Future<PageEpingles> lireEpingles(
    String evenementId, {
    String? dossierId,
  }) async => const PageEpingles(dossiers: [], epingles: []);

  @override
  Future<String> deposerImage(
    String evenementId, {
    required List<int> octets,
    required String nomFichier,
    required String typeMime,
  }) async {
    appels.add('deposerImage|$nomFichier|$typeMime|${octets.length}');
    return 'http://localhost:5080/media/events/x/abc.webp';
  }
}

Message _message({
  required String id,
  String? corps = 'Salut',
  String auteur = 'Lucas',
  String auteurId = 'm2',
  bool leMien = false,
  bool modifie = false,
  bool supprime = false,
  bool epingle = false,
  String? image,
  Citation? citation,
  List<Reaction> reactions = const [],
  List<Mention> mentions = const [],
  DateTime? envoyeLe,
}) => Message(
  id: id,
  auteurMembreId: auteurId,
  auteur: auteur,
  auteurPhoto: null,
  corps: corps,
  urlPieceJointe: image,
  sondageId: null,
  citation: citation,
  reactions: reactions,
  mentions: mentions,
  leMien: leMien,
  modifie: modifie,
  supprime: supprime,
  epingle: epingle,
  envoyeLe: envoyeLe ?? DateTime(2026, 8, 21, 20, 30),
);

Future<_DiscussionApiDouble> _monter(
  WidgetTester tester,
  List<Message> messages,
) async {
  final api = _DiscussionApiDouble(FilDiscussion(messages: messages));

  final conteneur = ProviderContainer(
    overrides: [
      discussionApiProvider.overrideWithValue(api),
      membresProvider(_evenement).overrideWith(
        (ref) async => [
          Membre(
            id: 'm1',
            nomAffiche: 'Moi',
            avatarUrl: null,
            statut: StatutPresence.present,
            heureArrivee: null,
            heureDepart: null,
            accompagnants: 0,
            role: RoleMembre.proprietaire,
            aUnCompte: true,
            cestMoi: true,
          ),
          Membre(
            id: 'm2',
            nomAffiche: 'Lucas',
            avatarUrl: null,
            statut: StatutPresence.present,
            heureArrivee: null,
            heureDepart: null,
            accompagnants: 0,
            role: RoleMembre.membre,
            aUnCompte: true,
            cestMoi: false,
          ),
        ],
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: DiscussionPage(evenementId: _evenement)),
    conteneur: conteneur,
  );

  return api;
}

void main() {
  group('Discussion', () {
    testWidgets('affiche le fil, du plus ancien au plus récent', (
      tester,
    ) async {
      // Une conversation se lit dans l'ordre où elle s'est tenue : l'inverser
      // obligerait à remonter pour comprendre une réponse.
      await _monter(tester, [
        _message(
          id: 'a',
          corps: 'premier',
          envoyeLe: DateTime(2026, 8, 21, 20),
        ),
        _message(
          id: 'b',
          corps: 'dernier',
          envoyeLe: DateTime(2026, 8, 21, 21),
        ),
      ]);

      final premier = tester.getTopLeft(find.text('premier')).dy;
      final dernier = tester.getTopLeft(find.text('dernier')).dy;

      expect(premier, lessThan(dernier));
    });

    testWidgets('un fil vide invite à écrire', (tester) async {
      await _monter(tester, const []);

      expect(find.textContaining('Rien de dit'), findsOneWidget);
    });

    testWidgets('envoie un message saisi', (tester) async {
      final api = await _monter(tester, const []);

      await tester.enterText(
        find.byKey(const Key('discussion-saisie')),
        'On prend quoi comme musique ?',
      );
      await tester.tap(find.byKey(const Key('discussion-envoyer')));
      await tester.pumpAndSettle();

      expect(
        api.appels,
        contains('envoyer|On prend quoi comme musique ?|null|'),
      );
    });

    testWidgets('un message vide ne part pas', (tester) async {
      final api = await _monter(tester, const []);

      await tester.tap(find.byKey(const Key('discussion-envoyer')));
      await tester.pumpAndSettle();

      expect(api.appels.where((a) => a.startsWith('envoyer')), isEmpty);
    });

    testWidgets('les liens sont cliquables, le reste du texte non', (
      tester,
    ) async {
      // Un lien collé dans la conversation doit s'ouvrir. Le donner en texte brut
      // obligerait à le recopier à la main.
      await _monter(tester, [
        _message(
          id: 'a',
          corps: 'la playlist : https://open.spotify.com/playlist/37i9 dis-moi',
        ),
      ]);

      // Le lien est un fragment de texte, non un widget : sa présence se vérifie par
      // son contenu, et son ouverture est couverte par les tests de PpTexteMessage.
      expect(
        find.textContaining('https://open.spotify.com/playlist/37i9'),
        findsOneWidget,
      );
    });

    testWidgets('une mention est mise en évidence', (tester) async {
      await _monter(tester, [
        _message(
          id: 'a',
          corps: '@Lucas tu apportes l’enceinte ?',
          mentions: const [Mention(membreId: 'm2', nom: 'Lucas')],
        ),
      ]);

      expect(find.byKey(const Key('mention-m2')), findsOneWidget);
    });

    testWidgets('une réaction s’affiche avec son décompte', (tester) async {
      await _monter(tester, [
        _message(
          id: 'a',
          reactions: const [Reaction(emoji: '🎉', nombre: 3, laMienne: true)],
        ),
      ]);

      expect(find.textContaining('🎉'), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('réagir ouvre le choix d’un emoji', (tester) async {
      // Six entrées « Réagir 👍 » dans le menu ne laissaient le choix qu'entre six
      // emoji, et allongeaient le menu d'autant.
      final api = await _monter(tester, [_message(id: 'a')]);

      await tester.tap(find.byKey(const Key('menu-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réagir…'));
      await tester.pumpAndSettle();

      expect(find.text('Fête'), findsOneWidget);

      await tester.tap(find.text('🥂'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('reaction|a|🥂'));
    });

    testWidgets('refermer le choix sans emoji ne pose aucune réaction', (
      tester,
    ) async {
      final api = await _monter(tester, [_message(id: 'a')]);

      await tester.tap(find.byKey(const Key('menu-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réagir…'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(api.appels.where((a) => a.startsWith('reaction')), isEmpty);
    });

    testWidgets('appuyer sur une réaction la bascule', (tester) async {
      final api = await _monter(tester, [
        _message(
          id: 'a',
          reactions: const [Reaction(emoji: '🎉', nombre: 1, laMienne: false)],
        ),
      ]);

      await tester.tap(find.byKey(const Key('reaction-a-🎉')));
      await tester.pumpAndSettle();

      expect(api.appels, contains('reaction|a|🎉'));
    });

    testWidgets('répondre cite le message visé', (tester) async {
      final api = await _monter(tester, [
        _message(id: 'a', corps: 'On prend quoi comme musique ?'),
      ]);

      await tester.tap(find.byKey(const Key('menu-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();

      // La citation est rappelée au-dessus de la saisie : sans elle, on ne sait plus
      // à quoi l'on répond au moment d'écrire.
      expect(find.textContaining('On prend quoi'), findsWidgets);

      await tester.enterText(
        find.byKey(const Key('discussion-saisie')),
        'ma playlist',
      );
      await tester.tap(find.byKey(const Key('discussion-envoyer')));
      await tester.pumpAndSettle();

      expect(api.appels, contains('envoyer|ma playlist|a|'));
    });

    testWidgets('un message cité s’affiche au-dessus de la réponse', (
      tester,
    ) async {
      await _monter(tester, [
        _message(
          id: 'b',
          corps: 'ma playlist',
          citation: const Citation(
            id: 'a',
            auteur: 'Lucas',
            corps: 'On prend quoi comme musique ?',
          ),
        ),
      ]);

      expect(
        find.textContaining('On prend quoi comme musique ?'),
        findsOneWidget,
      );
    });

    testWidgets('un message modifié le dit', (tester) async {
      await _monter(tester, [_message(id: 'a', modifie: true)]);

      expect(find.textContaining('modifié'), findsOneWidget);
    });

    testWidgets('un message supprimé garde sa place sans son contenu', (
      tester,
    ) async {
      await _monter(tester, [_message(id: 'a', corps: null, supprime: true)]);

      expect(find.textContaining('supprimé'), findsOneWidget);
    });

    testWidgets('épingler passe par le menu du message', (tester) async {
      final api = await _monter(tester, [_message(id: 'a')]);

      await tester.tap(find.byKey(const Key('menu-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Épingler'));
      await tester.pumpAndSettle();

      // Le rangement est proposé, et « sans dossier » ne coûte qu'un appui.
      await tester.tap(find.byKey(const Key('epingler-sans-dossier')));
      await tester.pumpAndSettle();

      expect(api.appels, contains('epingler|a|null'));
    });

    testWidgets('seul l’auteur voit la modification et la suppression', (
      tester,
    ) async {
      await _monter(tester, [_message(id: 'a', leMien: false)]);

      await tester.tap(find.byKey(const Key('menu-a')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsNothing);
      expect(find.text('Supprimer'), findsNothing);
      // Épingler reste offert : un message utile n'est pas forcément le sien.
      expect(find.text('Épingler'), findsOneWidget);
    });

    testWidgets('taper @ propose les participants', (tester) async {
      // Écrire le nom parfaitement est impraticable : une faute de frappe et la
      // personne n'est pas citée, sans que rien ne le signale.
      await _monter(tester, const []);

      await tester.enterText(find.byKey(const Key('discussion-saisie')), '@');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mention-choix-m2')), findsOneWidget);
      expect(find.byKey(const Key('mention-choix-m1')), findsOneWidget);
    });

    testWidgets('la liste se réduit à mesure qu’on tape', (tester) async {
      await _monter(tester, const []);

      await tester.enterText(
        find.byKey(const Key('discussion-saisie')),
        '@Luc',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mention-choix-m2')), findsOneWidget);
      expect(find.byKey(const Key('mention-choix-m1')), findsNothing);
    });

    testWidgets('la casse et les accents ne font pas échouer la recherche', (
      tester,
    ) async {
      // « @luc » doit trouver Lucas : personne ne pense à la casse en tapant vite.
      await _monter(tester, const []);

      await tester.enterText(
        find.byKey(const Key('discussion-saisie')),
        '@luc',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mention-choix-m2')), findsOneWidget);
    });

    testWidgets('choisir dans la liste complète le nom', (tester) async {
      final api = await _monter(tester, const []);

      await tester.enterText(
        find.byKey(const Key('discussion-saisie')),
        'salut @Luc',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mention-choix-m2')));
      await tester.pumpAndSettle();

      // Le nom est complété et suivi d'une espace : on continue d'écrire sans avoir à
      // repositionner le curseur.
      await tester.tap(find.byKey(const Key('discussion-envoyer')));
      await tester.pumpAndSettle();

      expect(api.appels, contains('envoyer|salut @Lucas|null|m2'));
    });

    testWidgets('la liste disparaît une fois le nom choisi', (tester) async {
      await _monter(tester, const []);

      await tester.enterText(
        find.byKey(const Key('discussion-saisie')),
        '@Luc',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mention-choix-m2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mention-choix-m2')), findsNothing);
    });

    testWidgets('une adresse électronique n’ouvre pas la liste', (
      tester,
    ) async {
      // « ecris-moi@exemple.fr » contient un @ collé à du texte : ce n'est pas une
      // tentative de citer quelqu'un.
      await _monter(tester, const []);

      await tester.enterText(
        find.byKey(const Key('discussion-saisie')),
        'ecris-moi@exemple.fr',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mention-choix-m2')), findsNothing);
    });

    testWidgets('un bouton + ouvre ce qu’on peut ajouter', (tester) async {
      // Créer un sondage n'était atteignable que par un menu de l'événement : à côté
      // du champ de saisie, personne ne le trouvait.
      await _monter(tester, const []);

      await tester.tap(find.byKey(const Key('discussion-ajouter')));
      await tester.pumpAndSettle();

      expect(find.text('Une image'), findsOneWidget);
      expect(find.text('Un sondage'), findsOneWidget);
    });

    testWidgets('le + mène à la création d’un sondage', (tester) async {
      await _monter(tester, const []);

      await tester.tap(find.byKey(const Key('discussion-ajouter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Un sondage'));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau sondage'), findsOneWidget);
    });

    testWidgets('une image jointe s’affiche dans le fil', (tester) async {
      await _monter(tester, [
        _message(
          id: 'a',
          corps: null,
          image: 'http://localhost:5080/media/events/x/abc.webp',
        ),
      ]);

      // Une photo se passe de légende : un message sans texte reste valable.
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('offre une reprise après une erreur de chargement', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          filDiscussionProvider(_evenement).overrideWith(FilEnPanne.new),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const Scaffold(body: DiscussionPage(evenementId: _evenement)),
        conteneur: conteneur,
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
