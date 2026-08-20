import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/evenement.dart';
import 'models/invitation.dart';
import 'models/membre.dart';
import 'models/moyens_connexion.dart';
import 'models/profil.dart';
import 'network/api_client.dart';
import 'network/comptes_api.dart';
import 'network/evenements_api.dart';
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
final magasinLocalProvider = Provider<MagasinLocal>((ref) => MagasinPreferences());

final cacheLectureProvider = Provider<CacheLecture>(
  (ref) => CacheLecture(ref.watch(magasinLocalProvider)),
);

final fileEcrituresProvider = Provider<FileEcritures>(
  (ref) => FileEcritures(ref.watch(magasinLocalProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(sessionStoreProvider),
    cache: ref.watch(cacheLectureProvider),
    file: ref.watch(fileEcrituresProvider),
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

/// État d'authentification.
///
/// Trois cas distincts, et non un simple booléen : un invité sans compte est
/// authentifié pour un seul événement (EF-INV-04), ce qui n'ouvre ni profil ni
/// back-office.
enum EtatSession { inconnu, anonyme, invite, connecte }

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
    if (await store.lireJetonInvite() != null) {
      return EtatSession.invite;
    }
    return EtatSession.anonyme;
  }

  /// Connexion.
  ///
  /// Renvoie le jeton de défi lorsqu'un second facteur est exigé ; l'état reste alors
  /// « anonyme », car aucune session n'est ouverte à ce stade.
  Future<String?> connecter({
    required String email,
    required String motDePasse,
  }) async {
    final resultat = await ref
        .read(comptesApiProvider)
        .connecter(email: email, motDePasse: motDePasse);

    if (resultat.secondFacteurRequis) {
      return resultat.jetonDefi;
    }

    state = const AsyncData(EtatSession.connecte);

    return null;
  }

  /// Achève une connexion en attente de second facteur.
  Future<void> verifierSecondFacteur({
    required String jetonDefi,
    required String code,
  }) async {
    await ref
        .read(comptesApiProvider)
        .verifierSecondFacteur(jetonDefi: jetonDefi, code: code);

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
    await ref.read(comptesApiProvider).deconnecter();

    // Le cache contient le contenu d'événements privés. Le laisser en place après une
    // déconnexion démentirait la promesse d'événement privé sur un appareil partagé.
    await ref.read(cacheLectureProvider).purger();

    ref.invalidate(profilProvider);
    ref.invalidate(mesEvenementsProvider);
    state = const AsyncData(EtatSession.anonyme);
  }

  /// Bascule la session en mode invité après une adhésion sans compte.
  ///
  /// Sans cet appel, l'état resterait « anonyme » et le routeur renverrait aussitôt la
  /// personne vers l'écran de connexion — après lui avoir promis qu'aucun compte
  /// n'était nécessaire.
  Future<void> reprendreCommeInvite() async {
    state = const AsyncData(EtatSession.invite);
    ref.invalidate(mesEvenementsProvider);
  }

  /// Rattache au compte les participations rejointes sans compte (EF-AUTH-11).
  ///
  /// Appelée après toute ouverture de session. Un échec n'est pas propagé : perdre le
  /// rattachement est fâcheux, mais bloquer une connexion réussie pour cette raison le
  /// serait davantage.
  Future<void> reclamerParticipations() async {
    try {
      final rattachees = await ref
          .read(evenementsApiProvider)
          .reclamerParticipations();

      if (rattachees > 0) {
        ref.invalidate(mesEvenementsProvider);
      }
    } on Exception {
      // Silencieux à dessein : le jeton d'invité reste sur l'appareil et la prochaine
      // ouverture de session retentera.
    }
  }
}

final sessionProvider = AsyncNotifierProvider<SessionCourante, EtatSession>(
  SessionCourante.new,
);

/// Profil du compte connecté. Rechargé après toute modification.
final profilProvider = FutureProvider<Profil>((ref) async {
  // La dépendance à l'état de session est explicite : se déconnecter puis se
  // reconnecter doit recharger le profil, pas servir celui du compte précédent.
  final etat = await ref.watch(sessionProvider.future);

  if (etat != EtatSession.connecte) {
    throw StateError('Aucun compte connecté.');
  }

  return ref.watch(comptesApiProvider).profil();
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
  (ref) => EvenementsApi(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

/// Événements de la personne connectée, à venir puis passés (EF-EVT-05).
final mesEvenementsProvider = FutureProvider<List<EvenementDeLaListe>>(
  (ref) => ref.watch(evenementsApiProvider).lister(),
);

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
final monMembreProvider = FutureProvider.family<Membre?, String>((ref, id) async {
  final membres = await ref.watch(membresProvider(id).future);

  for (final membre in membres) {
    if (membre.cestMoi) {
      return membre;
    }
  }

  return null;
});

/// Aperçu d'une invitation, par jeton de lien ou par code court.
///
/// Un seul provider pour les deux entrées : l'écran d'aperçu est le même, seule la
/// façon d'atteindre l'événement change.
final apercuInvitationProvider =
    FutureProvider.family<ApercuInvitation, ({String? jeton, String? code})>(
  (ref, cle) {
    final api = ref.watch(evenementsApiProvider);

    if (cle.jeton != null) {
      return api.apercuParJeton(cle.jeton!);
    }

    return api.apercuParCode(cle.code!);
  },
);
