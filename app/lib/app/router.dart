import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/admin/admin_audit_page.dart';
import '../features/admin/admin_comptes_page.dart';
import '../features/auth/connexion_page.dart';
import '../features/auth/inscription_page.dart';
import '../features/auth/mot_de_passe_oublie_page.dart';
import '../features/evenement/coquille_evenement.dart';
import '../features/profil/confidentialite_page.dart';
import '../features/profil/profil_edition_page.dart';
import '../features/profil/profil_page.dart';
import '../features/profil/securite_page.dart';
import '../features/rejoindre/rejoindre_page.dart';
import '../l10n/pp_strings.dart';

/// Routes de l'application.
abstract final class PpRoutes {
  static const accueil = '/';

  // Authentification
  static const connexion = '/connexion';
  static const inscription = '/inscription';
  static const motDePasseOublie = '/mot-de-passe-oublie';

  // Compte
  static const profilEdition = '/profil';
  static const securite = '/securite';
  static const confidentialite = '/mes-donnees';

  // Administration. Absente des versions mobiles en production (RG-ADM-08) :
  // la restriction est appliquée à la construction, voir plateforme.dart.
  static const adminComptes = '/admin/comptes';
  static const adminAudit = '/admin/audit';

  // Événementiel
  static const rejoindre = '/join/:token';
  static const rejoindreParCode = '/rejoindre';
  static const evenement = '/events/:eventId';

  static String versEvenement(String eventId) => '/events/$eventId';

  static String versRejoindre(String token) => '/join/$token';

  /// Routes accessibles sans session.
  static const publiques = <String>{
    connexion,
    inscription,
    motDePasseOublie,
    rejoindreParCode,
  };
}

/// Routeur de l'application, exposé en provider.
///
/// Il a besoin d'un `Ref` pour observer l'état de session ; le `WidgetRef` d'un état de
/// widget ne convient pas. Le provider donne le bon type et un cycle de vie unique.
final routeurProvider = Provider<GoRouter>((ref) => creerRouteur(ref));

/// Construit le routeur.
///
/// La redirection dépend de l'état de session : sans elle, un utilisateur non connecté
/// atteindrait l'écran de profil et n'y verrait qu'une erreur réseau.
GoRouter creerRouteur(Ref ref) => GoRouter(
  initialLocation: PpRoutes.accueil,
  refreshListenable: _EcouteSession(ref),
  redirect: (context, state) {
    final session = ref.read(sessionProvider);
    final chemin = state.matchedLocation;

    // Tant que l'état n'est pas déterminé, aucune redirection : rediriger ici ferait
    // clignoter l'écran de connexion à chaque démarrage.
    if (session.isLoading || !session.hasValue) {
      return null;
    }

    final connecte = session.requireValue == EtatSession.connecte;
    final invite = session.requireValue == EtatSession.invite;

    // Le lien d'invitation reste accessible en toutes circonstances : c'est le point
    // d'entrée de tout invité (EF-INV-04), et exiger une session ici ruinerait
    // l'adoption.
    if (chemin.startsWith('/join/')) {
      return null;
    }

    if (!connecte && !invite && !PpRoutes.publiques.contains(chemin)) {
      return PpRoutes.connexion;
    }

    if (connecte && PpRoutes.publiques.contains(chemin)) {
      return PpRoutes.accueil;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: PpRoutes.accueil,
      builder: (context, state) => const ProfilPage(),
    ),
    GoRoute(
      path: PpRoutes.connexion,
      builder: (context, state) => const ConnexionPage(),
    ),
    GoRoute(
      path: PpRoutes.inscription,
      builder: (context, state) => const InscriptionPage(),
    ),
    GoRoute(
      path: PpRoutes.motDePasseOublie,
      builder: (context, state) => const MotDePasseOubliePage(),
    ),
    GoRoute(
      path: PpRoutes.profilEdition,
      builder: (context, state) => const ProfilEditionPage(),
    ),
    GoRoute(
      path: PpRoutes.securite,
      builder: (context, state) => const SecuritePage(),
    ),
    GoRoute(
      path: PpRoutes.confidentialite,
      builder: (context, state) => const ConfidentialitePage(),
    ),
    GoRoute(
      path: PpRoutes.adminComptes,
      builder: (context, state) => const AdminComptesPage(),
    ),
    GoRoute(
      path: PpRoutes.adminAudit,
      builder: (context, state) => const AdminAuditPage(),
    ),
    GoRoute(
      path: PpRoutes.rejoindre,
      builder: (context, state) =>
          RejoindrePage(token: state.pathParameters['token']),
    ),
    GoRoute(
      path: PpRoutes.rejoindreParCode,
      builder: (context, state) => const RejoindrePage(),
    ),
    GoRoute(
      path: PpRoutes.evenement,
      builder: (context, state) =>
          CoquilleEvenement(eventId: state.pathParameters['eventId']!),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          PpStrings.erreurIntrouvable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  ),
);

/// Relaie les changements d'état de session au routeur.
class _EcouteSession extends ChangeNotifier {
  _EcouteSession(Ref ref) {
    _abonnement = ref.listen(
      sessionProvider,
      (_, _) => notifyListeners(),
      fireImmediately: true,
    );
  }

  late final ProviderSubscription<Object?> _abonnement;

  @override
  void dispose() {
    _abonnement.close();
    super.dispose();
  }
}
