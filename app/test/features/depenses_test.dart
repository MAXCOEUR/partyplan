import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/depense.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/depenses/depenses_page.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

Depense _depense({
  required String id,
  String libelle = 'Location de la salle',
  double montant = 180,
  String payeur = 'Lucas',
  int participants = 4,
  bool issueDesCourses = false,
  bool leMien = false,
  DateTime? date,
}) => Depense(
  id: id,
  libelle: libelle,
  montant: montant,
  payeurMembreId: leMien ? 'moi' : 'm-$id',
  payeurNom: payeur,
  date: date ?? DateTime(2026, 8, 20, 18),
  nombreParticipants: participants,
  issueDesCourses: issueDesCourses,
);

Future<void> _monter(
  WidgetTester tester, {
  required double total,
  required double maPart,
  required List<Depense> depenses,
  bool jeGere = true,
}) async {
  final conteneur = ProviderContainer(
    overrides: [
      depensesProvider(_evenement).overrideWith(
        (ref) async =>
            PageDepenses(total: total, maPart: maPart, depenses: depenses),
      ),
      monMembreProvider(_evenement).overrideWith(
        (ref) async => Membre(
          id: 'moi',
          nomAffiche: 'Moi',
          avatarUrl: null,
          statut: StatutPresence.present,
          heureArrivee: null,
          heureDepart: null,
          accompagnants: 0,
          role: jeGere ? RoleMembre.proprietaire : RoleMembre.membre,
          aUnCompte: true,
          cestMoi: true,
        ),
      ),
      membresProvider(_evenement).overrideWith((ref) async => []),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: DepensesPage(evenementId: _evenement)),
    conteneur: conteneur,
  );
}

void main() {
  group('Écran des dépenses', () {
    testWidgets('annonce le total et la part de l’appelant', (tester) async {
      await _monter(
        tester,
        total: 208.4,
        maPart: 52.1,
        depenses: [_depense(id: 'a')],
      );

      expect(find.textContaining('208'), findsWidgets);
      expect(find.textContaining('52'), findsWidgets);
    });

    testWidgets('les achats de courses apparaissent avec les saisies manuelles', (
      tester,
    ) async {
      // Les deux origines cohabitent : c'est l'intérêt de l'écran. Une dépense née
      // d'un achat porte un repère, sans quoi personne ne comprend d'où elle sort.
      await _monter(
        tester,
        total: 208.4,
        maPart: 52.1,
        depenses: [
          _depense(id: 'a', libelle: 'Bières', issueDesCourses: true),
          _depense(id: 'b', libelle: 'Location de la salle'),
        ],
      );

      expect(find.text('Bières'), findsOneWidget);
      expect(find.text('Location de la salle'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
    });

    testWidgets('nomme le payeur et le nombre de participants', (tester) async {
      // « Qui a payé » est la première question devant une liste de dépenses.
      await _monter(
        tester,
        total: 180,
        maPart: 45,
        depenses: [_depense(id: 'a', payeur: 'Lucas', participants: 4)],
      );

      expect(find.textContaining('Lucas'), findsOneWidget);
      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets('accorde le mot participant au singulier', (tester) async {
      // « 1 participants » sur l'écran d'une application française signale un texte
      // assemblé sans y penser.
      await _monter(
        tester,
        total: 10,
        maPart: 10,
        depenses: [_depense(id: 'a', participants: 1)],
      );

      expect(find.textContaining('1 participant ·'), findsOneWidget);
      expect(find.textContaining('1 participants'), findsNothing);
    });

    testWidgets('une liste vide invite à saisir la première dépense', (
      tester,
    ) async {
      await _monter(tester, total: 0, maPart: 0, depenses: const []);

      expect(find.textContaining('Aucune dépense'), findsOneWidget);
      // L'état vide nomme les cas qui ne viennent pas des courses : c'est ce que la
      // personne ne devinerait pas.
      expect(find.textContaining('location'), findsOneWidget);
    });

    testWidgets('mène aux remboursements depuis les totaux', (tester) async {
      // « Combien ça coûte » et « qui rend quoi à qui » sont deux questions qui se
      // suivent. Enterrer la seconde sous un menu obligerait à la chercher.
      await _monter(
        tester,
        total: 208.4,
        maPart: 52.1,
        depenses: [_depense(id: 'a')],
      );

      expect(find.text('Qui rend quoi'), findsOneWidget);
    });

    testWidgets('la dépense que j’ai payée s’ouvre pour correction', (
      tester,
    ) async {
      // Une somme se saisit vite et se trompe souvent : ne pas pouvoir la corriger
      // oblige à supprimer puis ressaisir, en perdant l'assiette.
      await _monter(
        tester,
        total: 24,
        maPart: 12,
        depenses: [_depense(id: 'a', leMien: true)],
      );

      await tester.tap(find.byKey(const Key('menu-depense-a')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets('la dépense d’un autre n’offre rien à un simple membre', (
      tester,
    ) async {
      // Corriger la dépense d'autrui change ce qu'il a avancé, donc ce que chacun lui
      // doit. Proposer le geste pour le voir refuser vaudrait moins que ne rien
      // proposer.
      await _monter(
        tester,
        total: 24,
        maPart: 12,
        depenses: [_depense(id: 'a', leMien: false)],
        jeGere: false,
      );

      expect(find.byKey(const Key('menu-depense-a')), findsNothing);
    });

    testWidgets('l’organisateur corrige la dépense de n’importe qui', (
      tester,
    ) async {
      await _monter(
        tester,
        total: 24,
        maPart: 12,
        depenses: [_depense(id: 'a', leMien: false)],
        jeGere: true,
      );

      await tester.tap(find.byKey(const Key('menu-depense-a')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
    });

    testWidgets('une dépense née des courses renvoie vers l’article', (
      tester,
    ) async {
      // Le serveur refuse de la modifier directement : son montant vient du prix payé
      // sur la liste de courses, et le corriger ailleurs créerait deux vérités.
      await _monter(
        tester,
        total: 28.4,
        maPart: 28.4,
        depenses: [_depense(id: 'a', leMien: true, issueDesCourses: true)],
      );

      await tester.tap(find.byKey(const Key('menu-depense-a')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsNothing);
      expect(find.textContaining('liste de courses'), findsOneWidget);
    });

    testWidgets('offre une reprise après une erreur de chargement', (
      tester,
    ) async {
      final conteneur = ProviderContainer(
        overrides: [
          depensesProvider(
            _evenement,
          ).overrideWith((ref) => Future.error(Exception('réseau'))),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const Scaffold(body: DepensesPage(evenementId: _evenement)),
        conteneur: conteneur,
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('la dépense la plus récente vient en premier', (tester) async {
      // Une liste de dépenses se consulte pour vérifier ce qui vient d'être ajouté.
      await _monter(
        tester,
        total: 200,
        maPart: 50,
        depenses: [
          _depense(id: 'a', libelle: 'Ancienne', date: DateTime(2026, 8, 1)),
          _depense(id: 'b', libelle: 'Récente', date: DateTime(2026, 8, 20)),
        ],
      );

      final positionRecente = tester.getTopLeft(find.text('Récente')).dy;
      final positionAncienne = tester.getTopLeft(find.text('Ancienne')).dy;

      expect(positionRecente, lessThan(positionAncienne));
    });
  });
}
