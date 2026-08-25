import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/article_course.dart';
import 'package:partyplan/core/models/depense.dart';
import 'package:partyplan/core/models/reglement.dart';
import 'package:partyplan/core/network/courses_api.dart';
import 'package:partyplan/core/network/depenses_api.dart';
import 'package:partyplan/core/network/reglements_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/courses/achat_feuille.dart';

import '../aide/monter_ecran.dart';

const _evenement = 'ev-1';

/// Déclarer un prix payé engendre une dépense côté serveur (`EF-CRS-07`) : le contrat
/// `IExpenseFromPurchase` la crée, et un test d'intégration le vérifie.
///
/// Encore faut-il que l'application le sache. La coquille d'événement empile ses onglets
/// dans un `IndexedStack` — c'est voulu, changer d'onglet ne doit pas perdre la position
/// de défilement — si bien que l'onglet Dépenses n'est jamais reconstruit. Sans
/// invalidation explicite, il continue de servir la page qu'il avait chargée avant
/// l'achat, et la dépense semble ne pas avoir été créée. Elle l'est, on ne la voit pas.
void main() {
  group('Un achat rafraîchit les comptes de l’événement', () {
    testWidgets('déclarer un prix payé recharge dépenses et règlements', (
      tester,
    ) async {
      final comptes = await _monter(tester, prix: '22,40');

      // Deux lectures : celle du montage, puis celle qui suit l'achat.
      expect(comptes.lecturesDepenses, 2, reason: 'dépenses non rechargées');
      expect(comptes.lecturesReglements, 2, reason: 'soldes non rechargés');
    });

    testWidgets('marquer acheté sans prix recharge aussi les comptes', (
      tester,
    ) async {
      // Sans prix, le serveur supprime la dépense qui avait pu être créée par une
      // saisie précédente : l'écran des comptes doit donc bouger dans les deux sens.
      final comptes = await _monter(tester, prix: null);

      expect(comptes.lecturesDepenses, 2);
      expect(comptes.lecturesReglements, 2);
    });
  });
}

// ------------------------------------------------------------------- montage ----

Future<_Comptes> _monter(WidgetTester tester, {required String? prix}) async {
  final comptes = _Comptes();
  final conteneur = ProviderContainer(
    overrides: [
      coursesApiProvider.overrideWithValue(_CoursesApiDouble()),
      depensesApiProvider.overrideWithValue(comptes),
      reglementsApiProvider.overrideWithValue(comptes),
    ],
  );
  addTearDown(conteneur.dispose);

  // Les deux providers sont maintenus vivants, comme l'onglet Dépenses monté dans la
  // coquille : sans abonnement, Riverpod les jetterait et la relecture n'aurait plus
  // rien à prouver.
  conteneur.listen(depensesProvider(_evenement), (_, _) {});
  conteneur.listen(reglementsProvider(_evenement), (_, _) {});
  await conteneur.read(depensesProvider(_evenement).future);
  await conteneur.read(reglementsProvider(_evenement).future);

  await monterEcran(
    tester,
    Scaffold(
      body: AchatFeuille(evenementId: _evenement, article: _article),
    ),
    conteneur: conteneur,
  );

  if (prix != null) {
    await tester.enterText(find.byKey(const Key('achat-prix')), prix);
  }

  await tester.tap(find.text('C’est acheté'));
  await tester.pumpAndSettle();

  return comptes;
}

// ----------------------------------------------------------------- doublures ----

/// Compte les lectures des deux écrans d'argent. Une invalidation se constate ainsi :
/// le provider redemande sa page.
class _Comptes implements DepensesApi, ReglementsApi {
  int lecturesDepenses = 0;
  int lecturesReglements = 0;

  @override
  Future<PageDepenses> lister(String evenementId) async {
    lecturesDepenses++;
    return const PageDepenses(total: 0, maPart: 0, depenses: []);
  }

  @override
  Future<PageReglements> lire(String evenementId) async {
    lecturesReglements++;
    return const PageReglements(
      soldes: [],
      proposes: [],
      effectues: [],
      monSolde: 0,
      invariantRespecte: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} hors sujet ici');
}

class _CoursesApiDouble implements CoursesApi {
  @override
  Future<ArticleCourse> acheter(
    String evenementId,
    String articleId, {
    double? quantiteObtenue,
    double? prixPaye,
  }) async => _article;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} hors sujet ici');
}

final _article = ArticleCourse(
  id: 'a',
  nom: 'Bières',
  quantite: 24,
  unite: 'bouteilles',
  categorie: CategorieCourse.boissons,
  membreAttributaire: 'm1',
  nomAttributaire: 'Moi',
  photoAttributaire: null,
  prisParMoi: true,
  estAchete: false,
  quantiteObtenue: null,
  quantiteRestante: 24,
  prixEstime: 30.5,
  prixPaye: null,
  note: 'blondes',
);
