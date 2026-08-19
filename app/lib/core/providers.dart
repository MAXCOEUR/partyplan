import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/profil.dart';
import 'network/api_client.dart';
import 'network/comptes_api.dart';
import 'storage/session_store.dart';

/// Dépendances partagées de l'application.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(sessionStoreProvider)),
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
    ref.invalidate(profilProvider);
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
  final etat = await ref.watch(sessionProvider.future);

  if (etat != EtatSession.connecte) {
    throw StateError('Aucun compte connecté.');
  }

  return ref.watch(comptesApiProvider).profil();
});

/// Fuseau et langue de l'application : `fr_FR` pour les dates en JJ/MM/AAAA.
const localeFr = 'fr_FR';

/// Sessions actives du compte connecté.
final sessionsProvider = FutureProvider<List<SessionActive>>(
  (ref) => ref.watch(comptesApiProvider).sessions(),
);
