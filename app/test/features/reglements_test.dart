import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/reglement.dart';
import 'package:partyplan/core/network/reglements_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/reglements/reglements_page.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

/// Client de règlements qui note ce qu'on lui demande.
class _ReglementsApiDouble implements ReglementsApi {
  _ReglementsApiDouble(this.page);

  PageReglements page;
  final List<String> appels = [];

  @override
  Future<PageReglements> lire(String evenementId) async {
    appels.add('lire');
    return page;
  }

  @override
  Future<void> marquerEffectue(
    String evenementId, {
    required String deMembreId,
    required String versMembreId,
    required double montant,
  }) async {
    appels.add('marquer|$deMembreId|$versMembreId|$montant');
  }

  @override
  Future<void> annuler(String evenementId, String reglementId) async {
    appels.add('annuler|$reglementId');
  }
}

Reglement _reglement({
  String? id,
  String de = 'm1',
  String deNom = 'Moi',
  String vers = 'm2',
  String versNom = 'Lucas',
  double montant = 18.30,
  bool effectue = false,
  bool meConcerne = true,
}) => Reglement(
  id: id,
  deMembreId: de,
  deNom: deNom,
  dePhoto: null,
  versMembreId: vers,
  versNom: versNom,
  versPhoto: null,
  montant: montant,
  effectue: effectue,
  meConcerne: meConcerne,
);

Future<_ReglementsApiDouble> _monter(
  WidgetTester tester, {
  double monSolde = 0,
  List<Solde> soldes = const [],
  List<Reglement> proposes = const [],
  List<Reglement> effectues = const [],
  bool invariantRespecte = true,
}) async {
  final api = _ReglementsApiDouble(
    PageReglements(
      soldes: soldes,
      proposes: proposes,
      effectues: effectues,
      monSolde: monSolde,
      invariantRespecte: invariantRespecte,
    ),
  );

  final conteneur = ProviderContainer(
    overrides: [reglementsApiProvider.overrideWithValue(api)],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: ReglementsPage(evenementId: _evenement)),
    conteneur: conteneur,
  );

  return api;
}

void main() {
  group('Écran des règlements', () {
    testWidgets('dit d’abord ce que l’appelant doit', (tester) async {
      // EF-RMB-05 : sa propre dette passe avant les soldes des autres. C'est la seule
      // ligne sur laquelle la personne a quelque chose à faire.
      await _monter(tester, monSolde: -18.30, proposes: [_reglement()]);

      // L'étiquette est en capitales : c'est le texte réellement affiché.
      expect(find.textContaining('TU DOIS'), findsOneWidget);
      expect(find.textContaining('18'), findsWidgets);
    });

    testWidgets('annonce aussi bien une créance qu’une dette', (tester) async {
      await _monter(
        tester,
        monSolde: 42.50,
        proposes: [
          _reglement(de: 'm2', deNom: 'Lucas', vers: 'm1', versNom: 'Moi'),
        ],
      );

      expect(find.textContaining('ON TE DOIT'), findsOneWidget);
    });

    testWidgets('un solde nul se dit sans chiffre inutile', (tester) async {
      await _monter(tester, monSolde: 0, soldes: const []);

      expect(find.textContaining('TU ES À JOUR'), findsOneWidget);
    });

    testWidgets('liste les règlements proposés, dans l’ordre reçu', (
      tester,
    ) async {
      // RG-CALC-01 : l'ordre d'affichage est celui de l'émission. Retrier côté
      // application ferait voir deux ordres différents à deux personnes.
      await _monter(
        tester,
        monSolde: -30,
        proposes: [
          _reglement(deNom: 'Moi', versNom: 'Lucas', montant: 18.30),
          _reglement(
            de: 'm3',
            deNom: 'Emma',
            versNom: 'Lucas',
            montant: 11.70,
            meConcerne: false,
          ),
        ],
      );

      final premier = tester.getTopLeft(find.textContaining('Lucas').first).dy;
      final second = tester.getTopLeft(find.textContaining('Emma').first).dy;

      expect(premier, lessThan(second));
    });

    testWidgets('marquer un règlement effectué envoie les trois données', (
      tester,
    ) async {
      final api = await _monter(
        tester,
        monSolde: -18.30,
        proposes: [_reglement(de: 'm1', vers: 'm2', montant: 18.30)],
      );

      await tester.tap(find.text('C’est réglé'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('marquer|m1|m2|18.3'));
    });

    testWidgets('le marquage n’est proposé que sur ce qui me concerne', (
      tester,
    ) async {
      // Déclarer le remboursement de deux autres personnes n'a pas de sens : ni l'un
      // ni l'autre ne l'a constaté.
      await _monter(
        tester,
        proposes: [
          _reglement(
            de: 'm2',
            deNom: 'Lucas',
            vers: 'm3',
            versNom: 'Emma',
            meConcerne: false,
          ),
        ],
      );

      expect(find.text('C’est réglé'), findsNothing);
    });

    testWidgets('un règlement effectué peut être annulé', (tester) async {
      final api = await _monter(
        tester,
        effectues: [_reglement(id: 'r1', effectue: true)],
      );

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.appels, contains('annuler|r1'));
    });

    testWidgets('rien à régler se dit clairement', (tester) async {
      await _monter(tester);

      expect(find.textContaining('Rien à rembourser'), findsOneWidget);
    });

    testWidgets('un invariant rompu est signalé, sans masquer les chiffres', (
      tester,
    ) async {
      // RG-RMB-04 : la somme des soldes doit être nulle. Si elle ne l'est pas,
      // l'interface le dit au lieu d'afficher des chiffres qu'on sait faux.
      await _monter(
        tester,
        monSolde: -10,
        soldes: const [
          Solde(membreId: 'm1', nom: 'Moi', photo: null, montant: -10),
        ],
        proposes: [_reglement()],
        invariantRespecte: false,
      );

      expect(find.textContaining('ne tombent pas juste'), findsOneWidget);
      // Les règlements restent affichés : les cacher priverait d'une information
      // utile pour comprendre l'écart.
      expect(find.text('C’est réglé'), findsWidgets);
    });

    testWidgets('les soldes de chacun sont consultables', (tester) async {
      await _monter(
        tester,
        monSolde: -18.30,
        soldes: const [
          Solde(membreId: 'm1', nom: 'Moi', photo: null, montant: -18.30),
          Solde(membreId: 'm2', nom: 'Lucas', photo: null, montant: 30),
          Solde(membreId: 'm3', nom: 'Emma', photo: null, montant: -11.70),
        ],
      );

      expect(find.text('Lucas'), findsWidgets);
      expect(find.text('Emma'), findsWidgets);
    });

    testWidgets('offre une reprise après une erreur de chargement', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          reglementsProvider(
            _evenement,
          ).overrideWith((ref) => Future.error(Exception('réseau'))),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const Scaffold(body: ReglementsPage(evenementId: _evenement)),
        conteneur: conteneur,
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
