import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/article_course.dart';
import 'models/depense.dart';
import 'models/activite.dart';
import 'models/avis.dart';
import 'models/message.dart';
import 'models/reglement.dart';
import 'models/sondage.dart';
import 'models/evenement.dart';
import 'models/invitation.dart';
import 'models/membre.dart';
import 'models/moyens_connexion.dart';
import 'models/profil.dart';
import 'session/role_plateforme.dart';
import 'network/api_client.dart';
import 'network/comptes_api.dart';
import 'network/courses_api.dart';
import 'network/depenses_api.dart';
import 'network/activite_api.dart';
import 'network/avis_api.dart';
import 'network/discussion_api.dart';
import 'network/reglements_api.dart';
import 'network/sondages_api.dart';
import 'auth/service_google.dart';
import 'config/app_config.dart';
import 'network/appareils_api.dart';
import 'network/evenements_api.dart';
import 'notifications/service_notifications.dart';
import 'temps_reel/service_temps_reel.dart';
import 'offline/cache_lecture.dart';
import 'offline/etat_reseau.dart';
import 'offline/file_ecritures.dart';
import 'storage/magasin_local.dart';
import 'storage/session_store.dart';

/// Dépendances partagées de l'application.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(secureStorageProvider)),
);

/// Magasin du cache et de la file (NF-OFFLINE-01). Distinct du stockage sécurisé :
/// ce qui transite ici est du contenu applicatif, pas un secret.
final magasinLocalProvider = Provider<MagasinLocal>(
  (ref) => MagasinPreferences(),
);

final cacheLectureProvider = Provider<CacheLecture>(
  (ref) => CacheLecture(ref.watch(magasinLocalProvider)),
);

final fileEcrituresProvider = Provider<FileEcritures>(
  (ref) => FileEcritures(ref.watch(magasinLocalProvider)),
);

/// Vrai lorsque le serveur a exigé un changement de mot de passe avant toute autre
/// action (RG-ADM-10). Observé par le routeur, qui conduit alors vers l'écran dédié.
///
/// L'état vient du refus renvoyé par l'API, non d'une lecture du profil : interroger le
/// profil au démarrage coûterait un appel réseau à chaque lancement, pour un cas qui ne
/// concerne que le compte administrateur amorcé.
class ChangementMotDePasseImpose extends Notifier<bool> {
  @override
  bool build() => false;

  void exiger() => state = true;

  void satisfait() => state = false;
}

final motDePasseAChangerProvider =
    NotifierProvider<ChangementMotDePasseImpose, bool>(
      ChangementMotDePasseImpose.new,
    );

/// Rôle plateforme du compte connecté, lu dans le jeton d'accès.
///
/// Sert au seul affichage de l'entrée du back-office : les droits sont vérifiés par
/// l'API, qui seule détient la clé de signature.
final rolePlateformeProvider = FutureProvider<String>((ref) async {
  // Dépend de l'état de session, et non du seul magasin : au lancement personne n'est
  // connecté, et sans cette dépendance le rôle resterait celui d'avant la connexion —
  // un administrateur ne verrait jamais son entrée du back-office.
  ref.watch(sessionProvider);

  final jeton = await ref.watch(sessionStoreProvider).lireJetonAcces();

  return rolePlateformeDuJeton(jeton);
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(sessionStoreProvider),
    cache: ref.watch(cacheLectureProvider),
    file: ref.watch(fileEcrituresProvider),
    auChangementImpose: () =>
        ref.read(motDePasseAChangerProvider.notifier).exiger(),
  ),
);

/// État réseau observable par les écrans : en ligne, hors ligne, rejeu, fraîcheur.
///
/// Les écrans ne connaissent que cet objet — ni le cache, ni la file. C'est ce qui
/// permettra d'ajouter un module sans qu'aucun de ses écrans n'ait à savoir comment le
/// hors ligne fonctionne.
/// Exposé comme simple `Provider` : `EtatReseau` est un `ChangeNotifier` de Flutter,
/// que les écrans observent par `ListenableBuilder`. Passer par l'ancien
/// `ChangeNotifierProvider` de Riverpod ajouterait une dépendance à son paquet hérité
/// pour un gain nul.
final etatReseauProvider = Provider<EtatReseau>(
  (ref) => ref.watch(apiClientProvider).etat,
);

final comptesApiProvider = Provider<ComptesApi>(
  (ref) =>
      ComptesApi(ref.watch(apiClientProvider), ref.watch(sessionStoreProvider)),
);

/// État d'authentification du compte.
enum EtatSession { inconnu, anonyme, connecte }

/// Session courante.
///
/// `null` tant que l'état n'a pas été déterminé : distinguer « on ne sait pas encore »
/// de « anonyme » évite l'écran de connexion qui clignote au démarrage.
class SessionCourante extends AsyncNotifier<EtatSession> {
  @override
  Future<EtatSession> build() async {
    final store = ref.watch(sessionStoreProvider);

    if (await store.lireJetonAcces() != null) {
      return EtatSession.connecte;
    }
    return EtatSession.anonyme;
  }

  /// Connexion. Une seule étape : la double authentification est retirée du produit
  /// (ADR 0007).
  Future<void> connecter({
    required String email,
    required String motDePasse,
  }) async {
    await ref
        .read(comptesApiProvider)
        .connecter(email: email, motDePasse: motDePasse);

    state = const AsyncData(EtatSession.connecte);
  }

  /// Connexion par jeton d'identité Google (EF-AUTH-06).
  Future<void> connecterAvecGoogle(String jetonIdentite) async {
    await ref.read(comptesApiProvider).connecterAvecGoogle(jetonIdentite);

    state = const AsyncData(EtatSession.connecte);
  }

  Future<void> inscrire({
    required String email,
    required String motDePasse,
    required String nomAffiche,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(comptesApiProvider)
          .inscrire(
            email: email,
            motDePasse: motDePasse,
            nomAffiche: nomAffiche,
          );
      state = const AsyncData(EtatSession.connecte);
    } on Exception catch (erreur, pile) {
      state = AsyncError(erreur, pile);
      rethrow;
    }
  }

  Future<void> deconnecter() async {
    // Avant de purger la session : l'appel exige encore d'être authentifié. Un téléphone
    // rendu ou prêté ne doit plus recevoir les notifications de son ancien titulaire.
    await ref.read(serviceNotificationsProvider).retirerAppareilCourant();

    // Sans cela le sélecteur de compte Google ne réapparaîtrait pas, et un appareil
    // partagé reconnecterait le compte précédent d'un seul geste.
    await ref.read(serviceGoogleProvider).oublier();

    await ref.read(comptesApiProvider).deconnecter();

    // Le cache contient le contenu d'événements privés. Le laisser en place après une
    // déconnexion démentirait la promesse d'événement privé sur un appareil partagé.
    await ref.read(cacheLectureProvider).purger();

    // Ni le profil ni la liste des événements ne sont invalidés d'ici : tous deux
    // observent cet état de session, et un notifieur qui invalide ce qui dépend de lui
    // forme un cycle. Riverpod lève alors, la méthode s'arrête avant la ligne suivante,
    // et l'application se croit encore connectée alors que le serveur a révoqué la
    // session — il fallait recharger la page à la main pour pouvoir se reconnecter.
    // Changer l'état suffit : ils se rechargent d'eux-mêmes.

    // Sans cette remise à zéro, le compte suivant serait conduit vers un formulaire
    // de changement de mot de passe qui ne le concerne pas.
    ref.read(motDePasseAChangerProvider.notifier).satisfait();
    state = const AsyncData(EtatSession.anonyme);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionCourante, EtatSession>(
  SessionCourante.new,
);

/// Profil du compte connecté. Rechargé après toute modification.
final profilProvider = FutureProvider<Profil>((ref) async {
  // La dépendance à l'état de session est explicite : se déconnecter puis se
  // reconnecter doit recharger le profil, pas servir celui du compte précédent.
  //
  // Les deux dépendances sont lues avant la première attente : un `ref.watch` après un
  // `await` se réabonne à chaque reconstruction et fait boucler le provider.
  final api = ref.watch(comptesApiProvider);
  final session = ref.watch(sessionProvider.future);

  final etat = await session;

  if (etat != EtatSession.connecte) {
    throw StateError('Aucun compte connecté.');
  }

  return api.profil();
});

/// Fuseau et langue de l'application : `fr_FR` pour les dates en JJ/MM/AAAA.
const localeFr = 'fr_FR';

/// Moyens de connexion du compte : mot de passe et services tiers (EF-AUTH-08).
final moyensConnexionProvider = FutureProvider<MoyensConnexion>(
  (ref) => ref.watch(comptesApiProvider).moyensConnexion(),
);

/// Sessions actives du compte connecté.
final sessionsProvider = FutureProvider<List<SessionActive>>(
  (ref) => ref.watch(comptesApiProvider).sessions(),
);

// ---------------------------------------------------------------- événements ----

final evenementsApiProvider = Provider<EvenementsApi>(
  (ref) => EvenementsApi(ref.watch(apiClientProvider)),
);

/// Événements de la personne connectée, à venir puis passés (EF-EVT-05).
///
/// La dépendance à l'état de session est explicite, pour la même raison que
/// [profilProvider] : sans elle, la requête part pendant la frame qui précède la
/// redirection, échoue en 401, et l'erreur reste affichée après la connexion — l'écran
/// annonce « impossible de charger tes événements » alors que le serveur répond.
final mesEvenementsProvider = FutureProvider<List<EvenementDeLaListe>>((
  ref,
) async {
  // Toutes les dépendances sont lues **avant** la première attente. Un `ref.watch`
  // placé après un `await` se réabonne à chaque reconstruction : le provider se
  // réexécute en boucle, l'écran reste sur son indicateur de chargement et le serveur
  // reçoit une rafale de requêtes identiques.
  final api = ref.watch(evenementsApiProvider);
  final session = ref.watch(sessionProvider.future);

  final etat = await session;

  // Un anonyme n'a aucune liste privée à charger.
  if (etat != EtatSession.connecte) {
    return const [];
  }

  return api.lister();
});

final evenementProvider = FutureProvider.family<ResumeEvenement, String>(
  (ref, id) => ref.watch(evenementsApiProvider).lire(id),
);

final membresProvider = FutureProvider.family<List<Membre>, String>(
  (ref, id) => ref.watch(evenementsApiProvider).membres(id),
);

final invitationProvider = FutureProvider.family<Invitation, String>(
  (ref, id) => ref.watch(evenementsApiProvider).invitation(id),
);

/// Membre correspondant à l'appelant dans un événement.
///
/// Dérivé de la liste des membres plutôt que d'un appel dédié : l'API marque déjà la
/// ligne de l'appelant par `isMe`, et un second appel donnerait deux sources de vérité
/// sur le rôle.
final monMembreProvider = FutureProvider.family<Membre?, String>((
  ref,
  id,
) async {
  final membres = await ref.watch(membresProvider(id).future);

  for (final membre in membres) {
    if (membre.cestMoi) {
      return membre;
    }
  }

  return null;
});

// ------------------------------------------------------------------- courses ----

final coursesApiProvider = Provider<CoursesApi>(
  (ref) => CoursesApi(ref.watch(apiClientProvider)),
);

/// Liste de courses d'un événement, avec son avancement (EF-CRS-09).
final listeCoursesProvider = FutureProvider.family<ListeCourses, String>(
  (ref, evenementId) => ref.watch(coursesApiProvider).lister(evenementId),
);

// ------------------------------------------------------------------ dépenses ----

final depensesApiProvider = Provider<DepensesApi>(
  (ref) => DepensesApi(ref.watch(apiClientProvider)),
);

/// Dépenses d'un événement et leurs totaux (EF-DEP-04).
final depensesProvider = FutureProvider.family<PageDepenses, String>(
  (ref, evenementId) => ref.watch(depensesApiProvider).lister(evenementId),
);

/// Détail d'une dépense : payeur, participants, part de chacun (EF-DEP-05).
final detailDepenseProvider =
    FutureProvider.family<
      DetailDepense,
      ({String evenementId, String depenseId})
    >(
      (ref, cle) =>
          ref.watch(depensesApiProvider).detail(cle.evenementId, cle.depenseId),
    );

// --------------------------------------------------------------- règlements ----

final reglementsApiProvider = Provider<ReglementsApi>(
  (ref) => ReglementsApi(ref.watch(apiClientProvider)),
);

/// Soldes et remboursements proposés d'un événement (EF-RMB-01, EF-RMB-02).
///
/// Recalculé à chaque lecture : aucun solde n'est conservé, côté serveur comme côté
/// application (RG-RMB-02).
final reglementsProvider = FutureProvider.family<PageReglements, String>(
  (ref, evenementId) => ref.watch(reglementsApiProvider).lire(evenementId),
);

// ------------------------------------------------------------------- avis ----

final avisApiProvider = Provider<AvisApi>(
  (ref) => AvisApi(ref.watch(apiClientProvider)),
);

/// Première page des notifications reçues (`§5.12`).
final avisProvider = FutureProvider<PageAvis>(
  (ref) => ref.watch(avisApiProvider).lire(),
);

/// Nombre de non-lus, pour la pastille.
///
/// Dérivé de [avisProvider] plutôt que d'un appel dédié : la page porte déjà le
/// décompte, et un second appel doublerait les requêtes pour la même valeur.
final avisNonLusProvider = Provider<int>(
  (ref) => ref.watch(avisProvider).maybeWhen(
    data: (page) => page.nonLus,
    orElse: () => 0,
  ),
);

/// Préférences par catégorie (`EF-NOT-07`).
final preferencesAvisProvider = FutureProvider<List<PreferenceAvis>>(
  (ref) => ref.watch(avisApiProvider).preferences(),
);

/// Mise en sourdine d'un événement (`EF-NOT-08`).
final sourdineProvider = FutureProvider.family<bool, String>(
  (ref, evenementId) => ref.watch(avisApiProvider).sourdine(evenementId),
);

// ---------------------------------------------------------------- activité ----

final activiteApiProvider = Provider<ActiviteApi>(
  (ref) => ActiviteApi(ref.watch(apiClientProvider)),
);

/// Première page du fil d'activité d'un événement (`EF-FIL-01`).
///
/// Invalidé par `EcouteEvenement` à chaque message diffusé : `activity.appended` n'a
/// donc besoin d'aucun traitement particulier côté écran.
final filActiviteProvider = FutureProvider.family<PageActivite, String>(
  (ref, evenementId) => ref.watch(activiteApiProvider).lire(evenementId),
);

// -------------------------------------------------------------- discussion ----

final discussionApiProvider = Provider<DiscussionApi>(
  (ref) => DiscussionApi(ref.watch(apiClientProvider)),
);

/// Fil de discussion d'un événement.
/// Fil de discussion d'un événement, chargé par pages.
///
/// L'état accumule les pages au lieu de les remplacer : remonter le fil ne doit pas
/// faire disparaître ce qu'on vient de lire en dessous.
class FilDiscussionNotifier extends AsyncNotifier<FilDiscussion> {
  FilDiscussionNotifier(this.evenementId);

  final String evenementId;

  /// Messages demandés par page. Deux écrans de conversation : assez pour qu'un fil
  /// ordinaire ne pagine pas du tout.
  static const parPage = 50;

  bool _enCoursDeRemontee = false;

  @override
  Future<FilDiscussion> build() =>
      ref.watch(discussionApiProvider).lire(evenementId, limite: parPage);

  /// Ajoute la page précédente en tête du fil.
  ///
  /// Sans effet si le début du fil est atteint, ou si une remontée est déjà en cours :
  /// le défilement déclenche plusieurs fois de suite, et deux requêtes concurrentes
  /// rendraient la même page deux fois.
  Future<void> chargerPlusAncien() async {
    final actuel = state.value;

    if (actuel == null || !actuel.encorePlusHaut || _enCoursDeRemontee) {
      return;
    }

    _enCoursDeRemontee = true;

    try {
      final precedents = await ref
          .read(discussionApiProvider)
          .lire(evenementId, avant: actuel.plusAncienId, limite: parPage);

      // Les identifiants déjà connus sont écartés : un message envoyé pendant la
      // remontée peut se retrouver dans les deux pages, et une clé dupliquée fait
      // lever la liste.
      final connus = actuel.messages.map((m) => m.id).toSet();

      state = AsyncData(
        actuel.avec(
          messages: [
            ...precedents.messages.where((m) => !connus.contains(m.id)),
            ...actuel.messages,
          ],
          encorePlusHaut: precedents.encorePlusHaut,
        ),
      );
    } finally {
      _enCoursDeRemontee = false;
    }
  }

  /// Relit la page la plus récente et la fusionne avec ce qui est déjà chargé.
  ///
  /// Appelée à chaque changement diffusé par le temps réel. Un `invalidate` aurait été
  /// plus court, mais il aurait remis le fil à sa première page : les pages remontées et
  /// la position de lecture disparaîtraient à chaque message reçu, ce qui est
  /// exactement ce qu'il ne faut pas faire dans une conversation.
  ///
  /// La fusion se fait sur l'identifiant. Un message modifié, supprimé ou nouvellement
  /// réagi garde le sien : le remplacer plutôt que l'ajouter évite de le voir deux fois,
  /// une fois dans son ancienne version.
  Future<void> rafraichir() async {
    final actuel = state.value;

    if (actuel == null) {
      // Le fil n'a jamais été chargé : la construction ordinaire s'en charge, et la
      // forcer ici doublerait la requête.
      return;
    }

    final FilDiscussion recents;

    try {
      recents = await ref
          .read(discussionApiProvider)
          .lire(evenementId, limite: parPage);
    } catch (_) {
      // Un rafraîchissement raté ne doit rien casser. Il est déclenché par le temps
      // réel, donc sans que personne l'ait demandé : lever ici produirait une exception
      // asynchrone non capturée, et remplacer l'état par une erreur effacerait une
      // conversation parfaitement lisible pour un incident réseau passager. L'écran
      // garde ce qu'il a, et le prochain message ou une actualisation manuelle
      // rattrapera.
      return;
    }

    final frais = recents.messages.map((m) => m.id).toSet();

    state = AsyncData(
      recents.avec(
        // Les messages plus anciens que la page fraîche sont conservés tels quels : ce
        // sont les pages remontées, que le serveur ne renvoie pas ici.
        messages: [
          ...actuel.messages.where((m) => !frais.contains(m.id)),
          ...recents.messages,
        ],
        // Le haut du fil n'a pas bougé : c'est l'état courant qui dit s'il reste des
        // pages au-dessus, pas la page fraîche qui n'en sait rien.
        encorePlusHaut: actuel.encorePlusHaut,
      ),
    );
  }

  /// Nombre maximal de pages chargées pour rejoindre le premier message non lu.
  ///
  /// « Tout jusqu'au premier non lu » n'est pas tenable : après trois semaines
  /// d'absence, ce serait la conversation entière. Passé cette borne, le fil s'ouvre sur
  /// les derniers messages, comme une messagerie qui renonce à rattraper un très vieux
  /// retard.
  static const _pagesDeRattrapage = 4;

  /// Charge les pages nécessaires pour que le premier message non lu soit dans le fil.
  ///
  /// Sans cela, le repère de lecture désigne un message absent de l'écran : il n'y a
  /// rien à montrer, et le fil s'ouvre en bas comme si tout était lu.
  Future<void> rattraperLesNonLus() async {
    for (var page = 1; page < _pagesDeRattrapage; page++) {
      final actuel = state.value;

      if (actuel == null ||
          actuel.premierNonLuId == null ||
          !actuel.encorePlusHaut ||
          actuel.messages.any((m) => m.id == actuel.premierNonLuId)) {
        return;
      }

      await chargerPlusAncien();
    }
  }

  /// Avance le repère de lecture jusqu'au dernier message connu.
  Future<void> marquerLu() async {
    final actuel = state.value;

    if (actuel == null || actuel.messages.isEmpty) {
      return;
    }

    await ref
        .read(discussionApiProvider)
        .marquerLu(evenementId, actuel.messages.last.id);
  }
}

final filDiscussionProvider =
    AsyncNotifierProvider.family<FilDiscussionNotifier, FilDiscussion, String>(
      FilDiscussionNotifier.new,
    );

/// Messages épinglés et dossiers de rangement.
final epinglesProvider = FutureProvider.family<PageEpingles, String>(
  (ref, evenementId) =>
      ref.watch(discussionApiProvider).lireEpingles(evenementId),
);

// ---------------------------------------------------------------- sondages ----

final sondagesApiProvider = Provider<SondagesApi>(
  (ref) => SondagesApi(ref.watch(apiClientProvider)),
);

/// Sondages d'un événement, les ouverts d'abord.
final sondagesProvider = FutureProvider.family<PageSondages, String>(
  (ref, evenementId) => ref.watch(sondagesApiProvider).lister(evenementId),
);

/// Aperçu d'une invitation, par jeton de lien ou par code court.
///
/// Un seul provider pour les deux entrées : l'écran d'aperçu est le même, seule la
/// façon d'atteindre l'événement change.
final apercuInvitationProvider =
    FutureProvider.family<ApercuInvitation, ({String? jeton, String? code})>((
      ref,
      cle,
    ) {
      final api = ref.watch(evenementsApiProvider);

      if (cle.jeton != null) {
        return api.apercuParJeton(cle.jeton!);
      }

      return api.apercuParCode(cle.code!);
    });

// ------------------------------------------------------------- notifications ----

final appareilsApiProvider = Provider<AppareilsApi>(
  (ref) => AppareilsApi(ref.watch(apiClientProvider)),
);

final serviceNotificationsProvider = Provider<ServiceNotifications>(
  (ref) => ServiceNotificationsFirebase(ref.watch(appareilsApiProvider)),
);

// ------------------------------------------------------------ connexion Google ----

final serviceGoogleProvider = Provider<ServiceGoogle>(
  (ref) => ServiceGoogleClient(),
);

/// Fournisseurs tiers dont l'instance possède les clés.
///
/// Lu sans session : l'écran de connexion en a besoin avant qu'un compte existe. Un
/// échec réseau ne doit pas empêcher de se connecter par mot de passe, d'où l'ensemble
/// vide en cas d'erreur plutôt qu'une exception remontée à l'écran.
final fournisseursDisponiblesProvider = FutureProvider<Set<String>>((
  ref,
) async {
  try {
    return await ref.watch(comptesApiProvider).fournisseursDisponibles();
  } on Exception {
    return const <String>{};
  }
});

// ---------------------------------------------------------------- temps réel ----

/// Connexion temps réel. Une seule pour toute l'application : on ne consulte qu'une
/// soirée à la fois, et deux connexions simultanées doubleraient les messages.
final serviceTempsReelProvider = Provider<ServiceTempsReel>(
  (ref) => ServiceTempsReelSignalR(
    baseUrl: AppConfig.apiBaseUrl,
    sessions: ref.watch(sessionStoreProvider),
  ),
);
