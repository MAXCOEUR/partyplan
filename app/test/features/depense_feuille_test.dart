import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/depense.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/network/depenses_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/depenses/depense_feuille.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

/// Client de dépenses qui note ce qu'on lui demande.
class _DepensesApiDouble implements DepensesApi {
  final List<String> appels = [];

  @override
  Future<DetailDepense> creer(
    String evenementId, {
    required String libelle,
    required double montant,
    required ModeAssiette mode,
    String? payeurMembreId,
    DateTime? date,
    List<PartDemandee>? parts,
  }) async {
    final detailParts = parts == null
        ? ''
        : parts.map((p) => '${p.membreId}=${p.part}').join(',');
    appels.add(
      'creer|$libelle|$montant|${mode.versApi}|$payeurMembreId|$detailParts',
    );
    return _detailExemple;
  }

  @override
  Future<DetailDepense> modifier(
    String evenementId,
    String depenseId, {
    required String libelle,
    required double montant,
    required ModeAssiette mode,
    String? payeurMembreId,
    DateTime? date,
    List<PartDemandee>? parts,
  }) async {
    appels.add(
      'modifier|$depenseId|$libelle|$montant|${mode.versApi}|$payeurMembreId',
    );
    return _detailExemple;
  }

  @override
  Future<DetailDepense> detail(String evenementId, String depenseId) async =>
      _detailExemple;

  @override
  Future<PageDepenses> lister(String evenementId) async =>
      const PageDepenses(total: 0, maPart: 0, depenses: []);

  @override
  Future<void> supprimer(String evenementId, String depenseId) async {
    appels.add('supprimer|$depenseId');
  }
}

final _detailExemple = DetailDepense(
  id: 'd1',
  libelle: 'Location de la salle',
  montant: 180,
  payeurMembreId: 'm1',
  payeurNom: 'Moi',
  date: DateTime(2026, 8, 20, 18),
  issueDesCourses: false,
  nombreRevisions: 0,
  parts: const [],
);

Membre _membre({
  required String id,
  required String nom,
  bool cestMoi = false,
  StatutPresence statut = StatutPresence.present,
}) => Membre(
  id: id,
  nomAffiche: nom,
  avatarUrl: null,
  statut: statut,
  heureArrivee: null,
  heureDepart: null,
  accompagnants: 0,
  role: RoleMembre.membre,
  aUnCompte: true,
  cestMoi: cestMoi,
);

Future<_DepensesApiDouble> _monter(WidgetTester tester) async {
  final api = _DepensesApiDouble();

  final conteneur = ProviderContainer(
    overrides: [
      depensesApiProvider.overrideWithValue(api),
      membresProvider(_evenement).overrideWith(
        (ref) async => [
          _membre(id: 'm1', nom: 'Moi', cestMoi: true),
          _membre(id: 'm2', nom: 'Lucas'),
          _membre(id: 'm3', nom: 'Absente', statut: StatutPresence.absent),
        ],
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: DepenseFeuille(evenementId: _evenement)),
    conteneur: conteneur,
  );

  return api;
}

void main() {
  group('Saisie d’une dépense hors courses', () {
    testWidgets('refuse un libellé vide', (tester) async {
      final api = await _monter(tester);

      await tester.tap(find.text('Ajouter la dépense'));
      await tester.pumpAndSettle();

      expect(api.appels, isEmpty);
      // Les deux champs obligatoires se signalent : le libellé et le montant.
      expect(find.text('Indique ce qui a été payé.'), findsOneWidget);
      expect(find.text('Indique un montant.'), findsOneWidget);
    });

    testWidgets('refuse un montant nul ou négatif', (tester) async {
      // RG-DEP-01 : le montant est strictement positif. Une dépense à zéro euro
      // polluerait les soldes sans rien représenter.
      final api = await _monter(tester);

      await tester.enterText(
        find.byKey(const Key('depense-libelle')),
        'Location',
      );
      await tester.enterText(find.byKey(const Key('depense-montant')), '0');
      await tester.tap(find.text('Ajouter la dépense'));
      await tester.pumpAndSettle();

      expect(api.appels, isEmpty);
    });

    testWidgets('crée une dépense partagée entre tous les présents', (
      tester,
    ) async {
      final api = await _monter(tester);

      await tester.enterText(
        find.byKey(const Key('depense-libelle')),
        'Location de la salle',
      );
      await tester.enterText(
        find.byKey(const Key('depense-montant')),
        '180,00',
      );
      await tester.tap(find.text('Ajouter la dépense'));
      await tester.pumpAndSettle();

      // L'appelant est transmis explicitement : laisser le serveur le déduire d'un
      // champ absent rendrait la requête ambiguë à la relecture.
      expect(
        api.appels.single,
        'creer|Location de la salle|180.0|AllPresent|m1|',
      );
    });

    testWidgets('permet de désigner un autre payeur', (tester) async {
      // « C'est Lucas qui a payé le taxi » : sans ce choix, le solde serait faux pour
      // deux personnes.
      final api = await _monter(tester);

      await tester.enterText(find.byKey(const Key('depense-libelle')), 'Taxi');
      await tester.enterText(find.byKey(const Key('depense-montant')), '24');

      await tester.tap(find.byKey(const Key('depense-payeur')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lucas').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter la dépense'));
      await tester.pumpAndSettle();

      expect(api.appels.single, contains('|m2|'));
    });

    testWidgets('en mode sélection, seuls les cochés participent', (
      tester,
    ) async {
      final api = await _monter(tester);

      await tester.enterText(find.byKey(const Key('depense-libelle')), 'Taxi');
      await tester.enterText(find.byKey(const Key('depense-montant')), '24');

      await tester.tap(find.text('Certains seulement'));
      await tester.pumpAndSettle();

      // Tous sont cochés au départ : on décoche Lucas.
      await tester.tap(find.byKey(const Key('participant-m2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter la dépense'));
      await tester.pumpAndSettle();

      expect(api.appels.single, contains('Selection'));
      expect(api.appels.single, contains('m1=1'));
      expect(api.appels.single, isNot(contains('m2=')));
    });

    testWidgets('en parts inégales, chaque poids est transmis', (tester) async {
      final api = await _monter(tester);

      await tester.enterText(find.byKey(const Key('depense-libelle')), 'Gîte');
      await tester.enterText(find.byKey(const Key('depense-montant')), '300');

      await tester.tap(find.text('Parts inégales'));
      await tester.pumpAndSettle();

      // Une part de plus pour celui qui dort sur place.
      await tester.tap(find.byKey(const Key('part-plus-m1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter la dépense'));
      await tester.pumpAndSettle();

      expect(api.appels.single, contains('Custom'));
      expect(api.appels.single, contains('m1=2'));
    });

    testWidgets('corriger sa propre dépense n’écrase pas le sélecteur', (
      tester,
    ) async {
      // Le payeur était placé dans le sélecteur par son identifiant, mais « Moi » y
      // figurait sous la valeur nulle : corriger sa propre dépense ne trouvait aucune
      // entrée correspondante et l'écran plantait sur une assertion de Flutter.
      final api = _DepensesApiDouble();

      final conteneur = ProviderContainer(
        overrides: [
          depensesApiProvider.overrideWithValue(api),
          membresProvider(_evenement).overrideWith(
            (ref) async => [
              _membre(id: 'm1', nom: 'Moi', cestMoi: true),
              _membre(id: 'm2', nom: 'Lucas'),
            ],
          ),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        Scaffold(
          body: DepenseFeuille(
            evenementId: _evenement,
            depense: Depense(
              id: 'd1',
              libelle: 'Taxi du retour',
              montant: 40,
              // Payée par l'appelant : c'est le cas qui plantait.
              payeurMembreId: 'm1',
              payeurNom: 'Moi',
              date: DateTime(2026, 8, 21),
              nombreParticipants: 2,
              issueDesCourses: false,
            ),
          ),
        ),
        conteneur: conteneur,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Taxi du retour'), findsOneWidget);
      expect(find.text('40,00'), findsOneWidget);
    });

    testWidgets('corriger la dépense d’un autre conserve son payeur', (
      tester,
    ) async {
      final api = _DepensesApiDouble();

      final conteneur = ProviderContainer(
        overrides: [
          depensesApiProvider.overrideWithValue(api),
          membresProvider(_evenement).overrideWith(
            (ref) async => [
              _membre(id: 'm1', nom: 'Moi', cestMoi: true),
              _membre(id: 'm2', nom: 'Lucas'),
            ],
          ),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        Scaffold(
          body: DepenseFeuille(
            evenementId: _evenement,
            depense: Depense(
              id: 'd1',
              libelle: 'Glaçons',
              montant: 8,
              payeurMembreId: 'm2',
              payeurNom: 'Lucas',
              date: DateTime(2026, 8, 21),
              nombreParticipants: 2,
              issueDesCourses: false,
            ),
          ),
        ),
        conteneur: conteneur,
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Le payeur d'origine est conservé : corriger un montant ne doit pas transférer
      // la créance à celui qui corrige.
      expect(api.appels.single, endsWith('|m2'));
    });

    testWidgets('les absents ne sont pas proposés par défaut', (tester) async {
      // Faire payer une soirée à quelqu'un qui n'y était pas est la faute la plus
      // fâcheuse de ce genre d'application.
      await _monter(tester);

      await tester.tap(find.text('Certains seulement'));
      await tester.pumpAndSettle();

      expect(find.text('Absente'), findsNothing);
    });
  });
}
