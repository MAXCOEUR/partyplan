import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/profil.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/admin/admin_comptes_page.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

FicheCompte _fiche({
  required String id,
  String nom = 'Quelqu’un',
  String role = 'User',
  DateTime? premiumJusquau,
}) => FicheCompte(
  id: id,
  email: '$id@partyplan.test',
  nomAffiche: nom,
  urlPhoto: null,
  rolePlateforme: role,
  emailVerifie: true,
  aUnMotDePasse: true,
  suspendu: false,
  motifSuspension: null,
  derniereConnexion: null,
  sessionsActives: 1,
  creeLe: DateTime(2026, 8, 1),
  supprimeLe: null,
  premiumJusquau: premiumJusquau,
);

Future<void> _monter(
  WidgetTester tester, {
  required List<FicheCompte> comptes,
  String monId = 'u1',
  String monRole = 'PlatformAdmin',
}) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(jetonAcces: 'jeton'),
      ),
      profilProvider.overrideWith(
        (ref) async => profilDeTest(id: monId, role: monRole),
      ),
      comptesProvider.overrideWith(
        (ref) async =>
            PageComptes(elements: comptes, total: comptes.length, page: 1),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const AdminComptesPage(), conteneur: conteneur);
}

void main() {
  group('Formule depuis le back-office', () {
    testWidgets('un administrateur peut changer la formule d’un autre compte', (
      tester,
    ) async {
      await _monter(tester, comptes: [_fiche(id: 'autre')]);

      expect(find.text('Passer Premium'), findsOneWidget);
    });

    testWidgets('un administrateur peut changer sa propre formule', (
      tester,
    ) async {
      // RG-ADM-03 protège d'un auto-sabotage : se suspendre, se révoquer, se
      // supprimer sont des gestes dont on ne revient pas seul. S'accorder une formule
      // n'appartient pas à cette famille, et l'API l'autorise déjà — masquer le bouton
      // rendait l'interface plus restrictive que le serveur, sans raison.
      await _monter(tester, comptes: [_fiche(id: 'u1', nom: 'Moi')], monId: 'u1');

      expect(find.text('Passer Premium'), findsOneWidget);
    });

    testWidgets('le libellé bascule pour un compte déjà abonné', (tester) async {
      await _monter(
        tester,
        comptes: [_fiche(id: 'autre', premiumJusquau: DateTime(2099, 1, 1))],
      );

      expect(find.text('Retirer Premium'), findsOneWidget);
    });

    testWidgets('le rôle Support ne voit pas l’action', (tester) async {
      // RG-ADM-05 : le support est borné à la consultation et au dépannage, et offrir
      // un abonnement n'est ni l'un ni l'autre. L'API renvoie 403 ; l'interface ne doit
      // pas proposer un bouton condamné.
      await _monter(
        tester,
        comptes: [_fiche(id: 'autre')],
        monRole: 'Support',
      );

      expect(find.text('Passer Premium'), findsNothing);
    });

    testWidgets('la suppression reste interdite sur son propre compte', (
      tester,
    ) async {
      // Le garde RG-ADM-03 doit rester en place là où il a un sens.
      await _monter(tester, comptes: [_fiche(id: 'u1', nom: 'Moi')], monId: 'u1');

      expect(find.text('Supprimer'), findsNothing);
      expect(find.text('Suspendre'), findsNothing);
    });
  });
}
