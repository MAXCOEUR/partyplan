import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/network/discussion_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/discussion/epingles_page.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

/// Client de discussion réduit à ce dont l'écran des épingles se sert.
class _DiscussionApiDouble implements DiscussionApi {
  _DiscussionApiDouble(this.page);

  PageEpingles page;
  final List<String> appels = [];

  @override
  Future<void> marquerLu(String evenementId, String messageId) async =>
      appels.add('marquerLu');

  @override
  Future<PageEpingles> lireEpingles(
    String evenementId, {
    String? dossierId,
  }) async {
    appels.add('lire|$dossierId');
    return page;
  }

  @override
  Future<void> desepingler(String evenementId, String messageId) async {
    appels.add('desepingler|$messageId');
  }

  @override
  Future<void> supprimerDossier(String evenementId, String dossierId) async {
    appels.add('supprimerDossier|$dossierId');
  }

  @override
  Future<Epingle> epingler(
    String evenementId,
    String messageId, {
    String? dossierId,
  }) async {
    appels.add('epingler|$messageId|$dossierId');
    return page.epingles.first;
  }

  @override
  Future<DossierEpingles> creerDossier(String evenementId, String nom) async {
    appels.add('dossier|$nom');
    return DossierEpingles(id: 'neuf', nom: nom, nombre: 0);
  }

  @override
  Future<FilDiscussion> lire(
    String evenementId, {
    String? avant,
    int limite = 50,
  }) async => const FilDiscussion(messages: []);

  @override
  Future<Message> envoyer(
    String evenementId, {
    String? corps,
    String? urlPieceJointe,
    String? repondreA,
    String? sondageId,
    List<String> mentions = const [],
  }) async => throw UnimplementedError();

  @override
  Future<Message> basculerReaction(
    String evenementId,
    String messageId,
    String emoji,
  ) async => throw UnimplementedError();

  @override
  Future<Message> modifier(
    String evenementId,
    String messageId, {
    required String corps,
  }) async => throw UnimplementedError();

  @override
  Future<void> supprimer(String evenementId, String messageId) async =>
      throw UnimplementedError();

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

Epingle _epingle({
  required String id,
  required String corps,
  String? dossierId,
  String? dossierNom,
  String auteur = 'Lucas',
}) => Epingle(
  id: id,
  dossierId: dossierId,
  dossierNom: dossierNom,
  message: Message(
    id: 'm-$id',
    auteurMembreId: 'x',
    auteur: auteur,
    corps: corps,
    urlPieceJointe: null,
    sondageId: null,
    citation: null,
    reactions: const [],
    mentions: const [],
    leMien: false,
    modifie: false,
    supprime: false,
    epingle: true,
    envoyeLe: DateTime(2026, 8, 20, 21),
  ),
  epingleLe: DateTime(2026, 8, 20, 21),
);

Future<_DiscussionApiDouble> _monter(
  WidgetTester tester, {
  List<DossierEpingles> dossiers = const [],
  List<Epingle> epingles = const [],
}) async {
  final api = _DiscussionApiDouble(
    PageEpingles(dossiers: dossiers, epingles: epingles),
  );

  final conteneur = ProviderContainer(
    overrides: [discussionApiProvider.overrideWithValue(api)],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const EpinglesPage(evenementId: _evenement),
    conteneur: conteneur,
  );

  return api;
}

void main() {
  group('Écran des épingles', () {
    testWidgets('rien d’épinglé se dit et explique le geste', (tester) async {
      await _monter(tester);

      expect(find.textContaining('Rien d’épinglé'), findsOneWidget);
    });

    testWidgets('affiche le contenu épinglé', (tester) async {
      await _monter(
        tester,
        epingles: [_epingle(id: 'e1', corps: 'code portail 4589B')],
      );

      expect(find.textContaining('code portail 4589B'), findsOneWidget);
      expect(find.textContaining('Lucas'), findsWidgets);
    });

    testWidgets('les dossiers servent de filtre', (tester) async {
      await _monter(
        tester,
        dossiers: const [
          DossierEpingles(id: 'd1', nom: 'Adresses', nombre: 2),
          DossierEpingles(id: 'd2', nom: 'Musique', nombre: 1),
        ],
        epingles: [
          _epingle(
            id: 'e1',
            corps: '12 rue des Lilas',
            dossierId: 'd1',
            dossierNom: 'Adresses',
          ),
          _epingle(
            id: 'e2',
            corps: 'ma playlist',
            dossierId: 'd2',
            dossierNom: 'Musique',
          ),
        ],
      );

      expect(find.text('Adresses'), findsWidgets);

      await tester.tap(find.byKey(const Key('filtre-dossier-d1')));
      await tester.pumpAndSettle();

      // Le filtre est appliqué localement : le serveur a déjà renvoyé tout le contenu,
      // et un aller-retour par dossier ferait clignoter la liste sans rien apporter.
      expect(find.textContaining('12 rue des Lilas'), findsOneWidget);
      expect(find.textContaining('ma playlist'), findsNothing);
    });

    testWidgets('le compte de chaque dossier est annoncé', (tester) async {
      await _monter(
        tester,
        dossiers: const [DossierEpingles(id: 'd1', nom: 'Adresses', nombre: 3)],
        epingles: [_epingle(id: 'e1', corps: 'x', dossierId: 'd1')],
      );

      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('une épingle se retire depuis son menu', (tester) async {
      final api = await _monter(
        tester,
        epingles: [_epingle(id: 'e1', corps: 'à ne plus garder')],
      );

      await tester.tap(find.byKey(const Key('menu-epingle-e1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer l’épingle'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('desepingler|m-e1'));
    });

    testWidgets('une épingle sans dossier est reconnaissable', (tester) async {
      // Classer est facultatif : ce qui n'est pas rangé doit rester visible, pas
      // disparaître dans un dossier fourre-tout invisible.
      await _monter(
        tester,
        dossiers: const [DossierEpingles(id: 'd1', nom: 'Adresses', nombre: 0)],
        epingles: [_epingle(id: 'e1', corps: 'non rangé')],
      );

      expect(find.text('Sans dossier'), findsWidgets);
    });

    testWidgets('offre une reprise après une erreur de chargement', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          epinglesProvider(
            _evenement,
          ).overrideWith((ref) => Future.error(Exception('réseau'))),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const EpinglesPage(evenementId: _evenement),
        conteneur: conteneur,
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
