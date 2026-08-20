import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/core/storage/session_store.dart';
import 'package:partyplan/features/auth/connexion_page.dart';
import 'package:partyplan/core/models/invitation.dart';
import 'package:partyplan/features/rejoindre/apercu_invitation_page.dart';

void main() {
  group('Routage', () {
    test('la route d’invitation se construit depuis un jeton', () {
      expect(PpRoutes.versRejoindre('ABC123'), '/join/ABC123');
    });

    test('la route d’événement se construit depuis un identifiant', () {
      expect(PpRoutes.versEvenement('0198-abcd'), '/events/0198-abcd');
    });

    test('les routes publiques n’exigent aucune session', () {
      expect(PpRoutes.publiques, contains(PpRoutes.connexion));
      expect(PpRoutes.publiques, contains(PpRoutes.inscription));
      // Le profil et l'administration ne doivent jamais y figurer.
      expect(PpRoutes.publiques, isNot(contains(PpRoutes.adminComptes)));
      expect(PpRoutes.publiques, isNot(contains(PpRoutes.securite)));
    });

    testWidgets('l’accès direct à un lien d’invitation ouvre le parcours', (
      tester,
    ) async {
      final conteneur = _conteneurAnonyme();
      final routeur = conteneur.read(routeurProvider);

      // Un invité arrive toujours par un lien : la route doit fonctionner en accès
      // direct, sans session, et sans redirection vers l'écran de connexion —
      // exiger un compte ici ruinerait l'adoption (EF-INV-04).
      routeur.go('/join/PLAN-8J4K');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      // L'aperçu restreint, et non le formulaire : avant de donner son prénom, un
      // visiteur doit savoir à quoi il est invité (RG-INV-04).
      expect(find.byType(ApercuInvitationPage), findsOneWidget);
    });

    testWidgets('un appelant anonyme est redirigé vers la connexion', (
      tester,
    ) async {
      final conteneur = _conteneurAnonyme();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Sans redirection, l'écran de profil s'afficherait pour n'y montrer qu'une
      // erreur réseau.
      expect(find.byType(ConnexionPage), findsOneWidget);
    });
  });
}

/// Date fixe : un test ne doit pas dépendre de l'heure à laquelle il tourne.
final _debutFictif = DateTime.utc(2026, 9, 12, 20);

ProviderContainer _conteneurAnonyme() {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(_StockageVide()),
      // Sans cette substitution, l'écran d'accueil construit pendant la frame qui
      // précède la redirection lance un vrai appel réseau, dont le délai d'attente
      // survit à la fin du test : le test échouerait sur un minuteur en suspens,
      // pour une raison étrangère à ce qu'il vérifie.
      mesEvenementsProvider.overrideWith((ref) async => []),
      apercuInvitationProvider.overrideWith(
        (ref, cle) async => ApercuInvitation(
          nom: 'Crémaillère',
          debut: _debutFictif,
          fin: null,
          adresse: null,
          description: null,
          nombreParticipants: 3,
          adhesionsOuvertes: true,
          dejaMembre: false,
        ),
      ),
    ],
  );
  addTearDown(conteneur.dispose);
  return conteneur;
}

/// Stockage de session vide.
///
/// Le stockage sécurisé de la plateforme n'existe pas dans un test de widget : le
/// substituer évite un échec sans rapport avec ce que l'on vérifie.
class _StockageVide implements SessionStore {
  @override
  Future<String?> lireJetonAcces() async => null;

  @override
  Future<String?> lireJetonRafraichissement() async => null;

  @override
  Future<String?> lireJetonInvite() async => null;

  @override
  Future<void> enregistrerSession({
    required String jetonAcces,
    required String jetonRafraichissement,
  }) async {}

  @override
  Future<void> enregistrerJetonInvite(String jeton) async {}

  @override
  Future<void> effacerSession() async {}

  @override
  Future<void> toutEffacer() async {}
}
