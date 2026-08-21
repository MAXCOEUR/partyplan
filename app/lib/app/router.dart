import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/accueil/accueil_page.dart';
import '../features/admin/admin_audit_page.dart';
import '../features/admin/admin_comptes_page.dart';
import '../features/auth/connexion_page.dart';
import '../features/auth/inscription_page.dart';
import '../features/auth/mot_de_passe_a_changer_page.dart';
import '../features/auth/mot_de_passe_oublie_page.dart';
import '../features/auth/second_facteur_page.dart';
import '../features/discussion/epingles_page.dart';
import '../features/evenement/coquille_evenement.dart';
import '../features/evenement/creation_evenement_page.dart';
import '../features/evenement/invitation_page.dart';
import '../features/evenement/invites_page.dart';
import '../features/evenement/parametres_evenement_page.dart';
import '../features/profil/confidentialite_page.dart';
import '../features/profil/connexions_page.dart';
import '../features/profil/profil_edition_page.dart';
import '../features/profil/profil_page.dart';
import '../features/profil/second_facteur_reglage_page.dart';
import '../features/profil/securite_page.dart';
import '../features/reglements/reglements_page.dart';
import '../features/sondages/sondages_page.dart';
import '../features/rejoindre/adhesion_page.dart';
import '../features/rejoindre/apercu_invitation_page.dart';
import '../features/rejoindre/rejoindre_page.dart';
import '../l10n/generated/pp_localisations.dart';

/// Routes de l'application.
abstract final class PpRoutes {
  static const accueil = '/';

  // Authentification
  static const connexion = '/connexion';
  static const inscription = '/inscription';
  static const motDePasseOublie = '/mot-de-passe-oublie';
  static const secondFacteur = '/second-facteur';

  /// Changement de mot de passe imposé avant toute autre action (RG-ADM-10). Exige une
  /// session : elle n'a donc pas sa place dans [publiques].
  static const motDePasseAChanger = '/mot-de-passe-a-changer';

  // Compte
  ///
  /// `/profil` présente la vue d'ensemble du compte ; la modification est un écran à
  /// part. Faire pointer `/profil` directement sur le formulaire rendait la
  /// déconnexion et la suppression du compte inatteignables.
  static const profil = '/profil';
  static const profilEdition = '/profil/modifier';
  static const securite = '/securite';
  static const confidentialite = '/mes-donnees';
  static const secondFacteurReglage = '/securite/double-authentification';
  static const connexionsTierces = '/securite/connexions';

  // Administration. Absente des versions mobiles en production (RG-ADM-08) :
  // la restriction est appliquée à la construction, voir plateforme.dart.
  static const adminComptes = '/admin/comptes';
  static const adminAudit = '/admin/audit';

  // Événementiel
  static const rejoindre = '/join/:token';
  static const rejoindreParCode = '/rejoindre';

  /// Déclarée **avant** `evenement` dans la table des routes : `go_router` compare dans
  /// l'ordre, et `/events/:eventId` capterait sinon « nouveau » comme identifiant.
  static const creationEvenement = '/events/nouveau';

  /// Aperçu et adhésion par code court. Distincts de `/join/:token` : le code ne
  /// donne pas accès au jeton, qui reste secret (RG-INV-04).
  static const apercuParCode = '/rejoindre/:code';
  static const adhesionParCode = '/rejoindre/:code/participer';
  static const adhesionParJeton = '/join/:token/participer';

  static const evenement = '/events/:eventId';
  static const evenementInvites = '/events/:eventId/invites';
  static const evenementInvitation = '/events/:eventId/inviter';
  static const evenementParametres = '/events/:eventId/parametres';
  static const evenementReglements = '/events/:eventId/reglements';
  static const evenementEpingles = '/events/:eventId/epingle';
  static const evenementSondages = '/events/:eventId/sondages';

  static String versEvenement(String eventId) => '/events/$eventId';

  static String versApercuParCode(String code) => '/rejoindre/$code';

  static String versAdhesion(String jeton) => '/join/$jeton/participer';

  static String versAdhesionParCode(String code) =>
      '/rejoindre/$code/participer';

  static String versInvites(String eventId) => '/events/$eventId/invites';

  static String versInvitation(String eventId) => '/events/$eventId/inviter';

  static String versParametres(String eventId) => '/events/$eventId/parametres';

  static String versReglements(String eventId) => '/events/$eventId/reglements';

  static String versEpingles(String eventId) => '/events/$eventId/epingle';

  static String versSondages(String eventId) => '/events/$eventId/sondages';

  static String versRejoindre(String token) => '/join/$token';

  /// Routes accessibles sans session.
  static const publiques = <String>{
    connexion,
    inscription,
    motDePasseOublie,
    // La seconde étape de connexion est publique : à ce stade, aucune session n'existe
    // encore, seul un jeton de défi de courte durée a été remis.
    secondFacteur,
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

    // Le lien d'invitation et la saisie de code restent accessibles en toutes
    // circonstances : c'est le point d'entrée de tout invité (EF-INV-04), et exiger
    // une session ici ruinerait l'adoption.
    //
    // La redirection vers l'accueil d'un compte connecté est écartée elle aussi : une
    // personne déjà connectée qui reçoit un lien doit pouvoir rejoindre l'événement,
    // pas se retrouver sur sa propre liste sans explication.
    if (chemin.startsWith('/join/') || chemin.startsWith('/rejoindre')) {
      return null;
    }

    if (!connecte && !invite && !PpRoutes.publiques.contains(chemin)) {
      return PpRoutes.connexion;
    }

    if (connecte && PpRoutes.publiques.contains(chemin)) {
      return PpRoutes.accueil;
    }

    // Tant que le mot de passe n'a pas changé, le serveur refuse toute autre requête
    // en 403 (RG-ADM-10). Sans cette redirection, l'accueil s'affiche vide et rien
    // n'indique quoi faire.
    //
    // L'information vient du refus lui-même, pas d'une lecture du profil : interroger
    // le profil au démarrage ajouterait un appel réseau à chaque lancement, pour un
    // cas qui ne concerne que le compte amorcé.
    if (connecte
        && chemin != PpRoutes.motDePasseAChanger
        && ref.read(motDePasseAChangerProvider)) {
      return PpRoutes.motDePasseAChanger;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: PpRoutes.accueil,
      builder: (context, state) => const AccueilPage(),
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
      path: PpRoutes.motDePasseAChanger,
      builder: (context, state) => const MotDePasseAChangerPage(),
    ),
    GoRoute(
      path: PpRoutes.motDePasseOublie,
      builder: (context, state) => const MotDePasseOubliePage(),
    ),
    GoRoute(
      path: PpRoutes.profil,
      builder: (context, state) => const ProfilPage(),
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
      path: PpRoutes.secondFacteurReglage,
      builder: (context, state) => const SecondFacteurReglagePage(),
    ),
    GoRoute(
      path: PpRoutes.secondFacteur,
      // Le jeton de défi passe par `extra` et non par l'URL : il ne doit apparaître ni
      // dans la barre d'adresse, ni dans un historique de navigation.
      builder: (context, state) =>
          SecondFacteurPage(jetonDefi: state.extra! as String),
    ),
    GoRoute(
      path: PpRoutes.connexionsTierces,
      builder: (context, state) => const ConnexionsPage(),
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
          ApercuInvitationPage(jeton: state.pathParameters['token']),
    ),
    GoRoute(
      path: PpRoutes.adhesionParJeton,
      builder: (context, state) =>
          AdhesionPage(jeton: state.pathParameters['token']),
    ),
    GoRoute(
      path: PpRoutes.rejoindreParCode,
      builder: (context, state) => const RejoindrePage(),
    ),
    GoRoute(
      path: PpRoutes.apercuParCode,
      builder: (context, state) =>
          ApercuInvitationPage(code: state.pathParameters['code']),
    ),
    GoRoute(
      path: PpRoutes.adhesionParCode,
      builder: (context, state) =>
          AdhesionPage(code: state.pathParameters['code']),
    ),
    // Avant `/events/:eventId` : sinon « nouveau » serait pris pour un identifiant.
    GoRoute(
      path: PpRoutes.creationEvenement,
      builder: (context, state) => const CreationEvenementPage(),
    ),
    GoRoute(
      path: PpRoutes.evenement,
      builder: (context, state) =>
          CoquilleEvenement(eventId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: PpRoutes.evenementInvites,
      builder: (context, state) =>
          InvitesPage(evenementId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: PpRoutes.evenementInvitation,
      builder: (context, state) =>
          InvitationPage(evenementId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: PpRoutes.evenementSondages,
      builder: (context, state) =>
          SondagesPage(evenementId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: PpRoutes.evenementEpingles,
      builder: (context, state) =>
          EpinglesPage(evenementId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: PpRoutes.evenementReglements,
      builder: (context, state) => ReglementsEcran(
        evenementId: state.pathParameters['eventId']!,
      ),
    ),
    GoRoute(
      path: PpRoutes.evenementParametres,
      builder: (context, state) => ParametresEvenementPage(
        evenementId: state.pathParameters['eventId']!,
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          PpL10n.of(context).erreurIntrouvable,
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
    _abonnements = [
      ref.listen(sessionProvider, (_, _) => notifyListeners(), fireImmediately: true),
      // Le refus « change ton mot de passe » arrive après la première lecture, donc
      // après la redirection initiale. Sans cette écoute, l'écran affiché resterait
      // celui de l'accueil, vide.
      ref.listen(motDePasseAChangerProvider, (_, _) => notifyListeners()),
    ];
  }

  late final List<ProviderSubscription<Object?>> _abonnements;

  @override
  void dispose() {
    for (final abonnement in _abonnements) {
      abonnement.close();
    }
    super.dispose();
  }
}
